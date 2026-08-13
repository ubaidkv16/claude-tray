# Self-check: dedupe by message id, date filter, per-model split, Fmt.
$src = Get-Content "$PSScriptRoot\claude-tray.ps1" -Raw
# Grab just the two pure functions, skip the WinForms UI.
$funcs = [regex]::Match($src, '(?s)function Get-Usage.*?\n\}\n\nfunction Fmt.*?\n\}\n').Value
Add-Type -AssemblyName System.Windows.Forms  # Get-Usage body has no UI, but keep parity
Invoke-Expression $funcs

$Root = Join-Path $env:TEMP ('usage-test-' + [guid]::NewGuid())
New-Item -ItemType Directory $Root | Out-Null
$now = (Get-Date).ToString('o')
$old = (Get-Date).AddDays(-30).ToString('o')
$mk = { param($id, $model, $ts, $out)
    (@{ timestamp = $ts; message = @{ id = $id; model = $model
        usage = @{ input_tokens = 10; output_tokens = $out
                   cache_read_input_tokens = 100; cache_creation_input_tokens = 5 } } } | ConvertTo-Json -Depth 9 -Compress) }
@(
  (& $mk 'a' 'claude-opus-5' $now 200)
  (& $mk 'a' 'claude-opus-5' $now 200)   # duplicate, must not double count
  (& $mk 'b' 'claude-opus-5' $now 50)
  (& $mk 'c' 'claude-haiku-4-5' $now 7)
  (& $mk 'd' 'claude-opus-5' $old 9999)  # too old, must be excluded
  '{"not":"usage"}'
) | Set-Content (Join-Path $Root 't.jsonl')

$r = Get-Usage (Get-Date).Date
if ($r.Count -ne 2) { throw "expected 2 models, got $($r.Count)" }
$o = $r['claude-opus-5']
if ($o.Msgs -ne 2)  { throw "dedupe failed: Msgs=$($o.Msgs)" }
if ($o.Out -ne 250) { throw "Out=$($o.Out)" }
if ($o.In -ne 20)   { throw "In=$($o.In)" }
if ($o.Cache -ne 210) { throw "Cache=$($o.Cache)" }
if ($r['claude-haiku-4-5'].Out -ne 7) { throw 'haiku split wrong' }

if ((Fmt 999) -ne '999')    { throw (Fmt 999) }
if ((Fmt 1500) -ne '1.5k')  { throw (Fmt 1500) }
if ((Fmt 2500000) -ne '2.5M') { throw (Fmt 2500000) }

Remove-Item $Root -Recurse -Force
'OK'
