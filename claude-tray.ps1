#requires -version 5
# Claude Code usage in the system tray. No deps: WinForms NotifyIcon + the JSONL
# transcripts under ~/.claude/projects.
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# One instance only. Launching again (double-click, login, Start menu) otherwise
# stacks up duplicate tray icons all showing the same numbers.
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\claude-tray-single-instance', [ref]$createdNew)
if (-not $createdNew) { exit }

$Root = Join-Path $env:USERPROFILE '.claude\projects'

function Get-Usage {
    # Returns per-model token totals for messages seen since $Since.
    param([datetime]$Since)
    $seen = @{}   # message id -> $true, transcripts repeat entries on resume
    $models = @{}
    foreach ($f in Get-ChildItem $Root -Recurse -Filter *.jsonl -ErrorAction SilentlyContinue) {
        if ($f.LastWriteTime -lt $Since) { continue }
        foreach ($line in Get-Content $f.FullName -ErrorAction SilentlyContinue) {
            if ($line -notmatch '"usage"') { continue }
            try { $e = $line | ConvertFrom-Json } catch { continue }
            $u = $e.message.usage
            if (-not $u -or -not $e.timestamp) { continue }
            if ([datetime]$e.timestamp -lt $Since) { continue }
            $id = $e.message.id
            if ($id) { if ($seen[$id]) { continue }; $seen[$id] = $true }
            $m = if ($e.message.model) { $e.message.model } else { 'unknown' }
            if (-not $models[$m]) { $models[$m] = [pscustomobject]@{ In = 0L; Out = 0L; Cache = 0L; Msgs = 0 } }
            $t = $models[$m]
            $t.In    += [long]$u.input_tokens
            $t.Out   += [long]$u.output_tokens
            $t.Cache += [long]$u.cache_read_input_tokens + [long]$u.cache_creation_input_tokens
            $t.Msgs  += 1
        }
    }
    $models
}

function Fmt([long]$n) {
    if ($n -ge 1e9) { '{0:N1}B' -f ($n / 1e9) }
    elseif ($n -ge 1e6) { '{0:N1}M' -f ($n / 1e6) }
    elseif ($n -ge 1000) { '{0:N1}k' -f ($n / 1000) }
    else { "$n" }
}

$icon = New-Object System.Windows.Forms.NotifyIcon
$icon.Icon = [System.Drawing.SystemIcons]::Information
$icon.Text = 'Claude usage: loading...'
$icon.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$icon.ContextMenuStrip = $menu

# Windows 11 puts the tray on the primary display's taskbar only, so offer a
# draggable topmost readout for whichever monitor you actually want it on.
$hud = New-Object System.Windows.Forms.Form
$hud.FormBorderStyle = 'None'
$hud.TopMost = $true
$hud.ShowInTaskbar = $false
$hud.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$hud.ForeColor = [System.Drawing.Color]::Gainsboro
$hud.StartPosition = 'Manual'
$hud.Opacity = 0.9
# Grow to fit the text instead of a fixed size, so nothing gets clipped when the
# numbers get longer (1.2M vs 41.2k) or Windows is on a non-100% display scale.
$hud.AutoSize = $true
$hud.AutoSizeMode = 'GrowAndShrink'
$hudLabel = New-Object System.Windows.Forms.Label
$hudLabel.AutoSize = $true
$hudLabel.Padding = New-Object System.Windows.Forms.Padding 10
$hudLabel.Font = New-Object System.Drawing.Font 'Consolas', 9
$hud.Controls.Add($hudLabel)

# Borderless form has no title bar to grab, so drag from anywhere on it.
$drag = @{ on = $false; x = 0; y = 0 }
$down = { $drag.on = $true; $drag.x = [System.Windows.Forms.Cursor]::Position.X - $hud.Left
                            $drag.y = [System.Windows.Forms.Cursor]::Position.Y - $hud.Top }
$move = { if ($drag.on) {
            $p = [System.Windows.Forms.Cursor]::Position
            $hud.Left = $p.X - $drag.x; $hud.Top = $p.Y - $drag.y } }
$up   = { $drag.on = $false
          Set-Content $script:PosFile "$($hud.Left),$($hud.Top)" -ErrorAction SilentlyContinue }
foreach ($c in @($hud, $hudLabel)) {
    $c.Add_MouseDown($down); $c.Add_MouseMove($move); $c.Add_MouseUp($up)
}
$PosFile = Join-Path $PSScriptRoot 'hud-pos.txt'
$SetFile = Join-Path $PSScriptRoot 'settings.json'
$LnkPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\claude-tray.lnk'

function Save-Settings {
    @{ ShowHud = $hud.Visible; IntervalMs = $script:timer.Interval } |
        ConvertTo-Json | Set-Content $script:SetFile -Encoding utf8
}

function Show-Hud {
    $hud.Show()   # show first so AutoSize has laid the label out and Width/Height are real

    $pos = if (Test-Path $script:PosFile) { (Get-Content $script:PosFile) -split ',' } else { $null }
    if ($pos.Count -eq 2) {
        $hud.Location = New-Object System.Drawing.Point ([int]$pos[0]), ([int]$pos[1])
    } else {
        $s = [System.Windows.Forms.Screen]::PrimaryScreen
        $hud.Location = New-Object System.Drawing.Point ($s.WorkingArea.Right - $hud.Width - 20), ($s.WorkingArea.Top + 20)
    }

    # Clamp fully on-screen: a saved position can be off the edge, or on a monitor
    # that's since been unplugged or resized.
    $wa = [System.Windows.Forms.Screen]::FromPoint($hud.Location).WorkingArea
    $x = [Math]::Min([Math]::Max($hud.Left, $wa.Left), $wa.Right - $hud.Width)
    $y = [Math]::Min([Math]::Max($hud.Top, $wa.Top), $wa.Bottom - $hud.Height)
    $hud.Location = New-Object System.Drawing.Point $x, $y

    $hud.BringToFront()
}

function Refresh {
    $today = (Get-Date).Date
    $week = $today.AddDays(-7)
    $t = Get-Usage $today
    $w = Get-Usage $week

    $sum = { param($h) $i=0L;$o=0L;$c=0L;$m=0
             foreach ($v in $h.Values) { $i+=$v.In;$o+=$v.Out;$c+=$v.Cache;$m+=$v.Msgs }
             [pscustomobject]@{ In=$i;Out=$o;Cache=$c;Msgs=$m } }
    $ts = & $sum $t
    $ws = & $sum $w

    # NotifyIcon tooltip caps at 63 chars, so keep it to the headline numbers.
    $icon.Text = "Claude today: {0} in / {1} out / {2} cache" -f (Fmt $ts.In), (Fmt $ts.Out), (Fmt $ts.Cache)

    $menu.Items.Clear()
    $add = { param($text, $enabled = $false)
             $it = $menu.Items.Add($text); $it.Enabled = $enabled; $it }
    & $add ("TODAY  {0} msgs" -f $ts.Msgs)
    & $add ("  in {0}   out {1}   cache {2}" -f (Fmt $ts.In), (Fmt $ts.Out), (Fmt $ts.Cache))
    foreach ($k in ($t.Keys | Sort-Object)) {
        $v = $t[$k]
        & $add ("  {0}: {1} msgs, {2} out" -f $k, $v.Msgs, (Fmt $v.Out))
    }
    $menu.Items.Add('-') | Out-Null
    & $add ("LAST 7 DAYS  {0} msgs" -f $ws.Msgs)
    & $add ("  in {0}   out {1}   cache {2}" -f (Fmt $ws.In), (Fmt $ws.Out), (Fmt $ws.Cache))
    $menu.Items.Add('-') | Out-Null
    & $add ("Updated {0}" -f (Get-Date -f 'HH:mm:ss'))

    $hudLabel.Text = "Claude Code usage`n`nTODAY  {0} msgs`n in {1}  out {2}`n cache {3}`n7d  {4} msgs, {5} out" -f `
        $ts.Msgs, (Fmt $ts.In), (Fmt $ts.Out), (Fmt $ts.Cache), $ws.Msgs, (Fmt $ws.Out)

    $r = $menu.Items.Add('Refresh now'); $r.Add_Click({ Refresh })

    # Settings submenu: everything configurable lives here rather than loose in
    # the main menu.
    $set = New-Object System.Windows.Forms.ToolStripMenuItem 'Settings'
    $menu.Items.Add($set) | Out-Null

    $mi = { param($text, $checked, $onClick)
            $i = New-Object System.Windows.Forms.ToolStripMenuItem $text
            $i.Checked = $checked; $i.CheckOnClick = $false
            $i.Add_Click($onClick); $set.DropDownItems.Add($i) | Out-Null; $i }

    & $mi 'Show floating window' $hud.Visible {
        if ($hud.Visible) { $hud.Hide() } else { Show-Hud }
        Save-Settings
    }
    & $mi 'Start with Windows' (Test-Path $script:LnkPath) {
        if (Test-Path $script:LnkPath) { Remove-Item $script:LnkPath -Force }
        else {
            $s = (New-Object -ComObject WScript.Shell).CreateShortcut($script:LnkPath)
            $s.TargetPath = 'powershell.exe'
            $s.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            $s.WorkingDirectory = $PSScriptRoot; $s.WindowStyle = 7; $s.Save()
        }
    }

    $set.DropDownItems.Add('-') | Out-Null
    $iv = New-Object System.Windows.Forms.ToolStripMenuItem 'Refresh every'
    $set.DropDownItems.Add($iv) | Out-Null
    foreach ($opt in @(@{n='30 seconds';ms=30000}, @{n='1 minute';ms=60000},
                       @{n='5 minutes';ms=300000}, @{n='15 minutes';ms=900000})) {
        $it = New-Object System.Windows.Forms.ToolStripMenuItem $opt.n
        $it.Checked = ($script:timer.Interval -eq $opt.ms)
        $it.Tag = $opt.ms
        $it.Add_Click({ $script:timer.Interval = [int]$this.Tag; Save-Settings; Refresh })
        $iv.DropDownItems.Add($it) | Out-Null
    }

    $set.DropDownItems.Add('-') | Out-Null
    $rp = $set.DropDownItems.Add('Reset window position')
    $rp.Add_Click({
        Remove-Item $script:PosFile -ErrorAction SilentlyContinue
        $hud.Hide(); Show-Hud
    })

    $q = $menu.Items.Add('Exit'); $q.Add_Click({
        $script:timer.Stop(); $hud.Close(); $icon.Visible = $false; $icon.Dispose()
        [System.Windows.Forms.Application]::Exit()
    })
}

$cfg = if (Test-Path $SetFile) { try { Get-Content $SetFile -Raw | ConvertFrom-Json } catch { $null } } else { $null }

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = if ($cfg.IntervalMs) { [int]$cfg.IntervalMs } else { 60000 }
$timer.Add_Tick({ Refresh })
$timer.Start()

# Double-click toggles the floating window: the one icon controls everything.
$icon.Add_MouseDoubleClick({
    if ($hud.Visible) { $hud.Hide() } else { Show-Hud }
    Save-Settings
})
Refresh
# Respect the saved choice; first run (no settings file) shows it.
if ($null -eq $cfg -or $cfg.ShowHud) { Show-Hud }
[System.Windows.Forms.Application]::Run()
