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

$SetFile = Join-Path $PSScriptRoot 'settings.json'
$LnkPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\claude-tray.lnk'

function Save-Settings {
    @{ IntervalMs = $script:timer.Interval } |
        ConvertTo-Json | Set-Content $script:SetFile -Encoding utf8
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

    $r = $menu.Items.Add('Refresh now'); $r.Add_Click({ Refresh })

    # Settings submenu: everything configurable lives here rather than loose in
    # the main menu.
    $set = New-Object System.Windows.Forms.ToolStripMenuItem 'Settings'
    $menu.Items.Add($set) | Out-Null

    $mi = { param($text, $checked, $onClick)
            $i = New-Object System.Windows.Forms.ToolStripMenuItem $text
            $i.Checked = $checked; $i.CheckOnClick = $false
            $i.Add_Click($onClick); $set.DropDownItems.Add($i) | Out-Null; $i }

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

    $q = $menu.Items.Add('Exit'); $q.Add_Click({
        $script:timer.Stop(); $icon.Visible = $false; $icon.Dispose()
        [System.Windows.Forms.Application]::Exit()
    })
}

$cfg = if (Test-Path $SetFile) { try { Get-Content $SetFile -Raw | ConvertFrom-Json } catch { $null } } else { $null }

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = if ($cfg.IntervalMs) { [int]$cfg.IntervalMs } else { 60000 }
$timer.Add_Tick({ Refresh })
$timer.Start()

$icon.Add_MouseDoubleClick({ Refresh })
Refresh
[System.Windows.Forms.Application]::Run()
