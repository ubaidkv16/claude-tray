# claude-tray

A Windows system-tray readout of your Claude Code token usage. One PowerShell
script, no dependencies, no build step, no install of anything.

It reads the JSONL transcripts Claude Code already writes to
`%USERPROFILE%\.claude\projects\` and totals the token counts.

- **Tray icon** — hover for today's totals; right-click for the full breakdown.
- **Floating window** — a small always-on-top box you can drag to any monitor,
  because Windows 11 only puts the tray on the primary display's taskbar.
- Refreshes every 60 seconds.

## Requirements

- Windows (10 or 11)
- Windows PowerShell 5.1 — preinstalled on every Windows box; nothing to install
- Claude Code, having run at least once (so there are transcripts to read)

No Python, no Node, no winget, no admin rights.

## Install

### Get the files

Either clone it:

```powershell
git clone <your-repo-url> claude-tray
cd claude-tray
```

…or just copy the folder over. It's four files and none of them are compiled.
`claude-tray.ps1` alone is enough to run — the rest is the installer, the test,
and this README.

### Run the installer

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

That creates a shortcut in your Startup folder so it launches hidden on every
login, then starts it immediately. It uses whatever folder you put the repo in,
so there are no paths to edit.

### Or run it once, without installing

```powershell
powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File claude-tray.ps1
```

### Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

Removes the startup shortcut and stops the running copy. Nothing else is left
behind except `hud-pos.txt` in the repo folder.

## Usage

| Action | What it does |
|---|---|
| Hover the tray icon | Today's in / out / cache tokens |
| Right-click the tray icon | Today per-model with message counts, last-7-days totals |
| Double-click the tray icon | Refresh now |
| Menu → Show floating window | Toggle the always-on-top box |
| Drag the floating box | Move it anywhere, any monitor — position is remembered |
| Menu → Exit | Quit (won't come back until next login, or relaunch by hand) |

The floating box is borderless, so there's no title bar — drag it from anywhere
on its body. Its position saves to `hud-pos.txt` next to the script and is
restored on the next launch. Delete that file to reset it to the primary
screen's top-right corner.

## Which monitor things appear on

The **tray icon** can only ever live on your primary display. Windows 11 gives
the notification area to the primary taskbar only; secondary taskbars get app
buttons and a clock but no tray. No application can change this. If you want the
icon on a different screen, make that screen primary in
Settings → System → Display → *Make this my main display*.

The **floating window** has no such limit — that's what it's for. It opens on the
primary screen by default; drag it wherever you like and it stays there.

## What it counts

For each assistant message in the transcripts it sums:

- `input_tokens`
- `output_tokens`
- `cache_read_input_tokens` + `cache_creation_input_tokens`, shown together as
  "cache"

Two details that matter for accuracy:

- **Deduplication.** Transcripts replay earlier entries when you resume a
  session, so the same message can appear several times. Entries are deduped by
  `message.id`.
- **Date filtering.** Both the file's modified time and each entry's own
  `timestamp` are checked, so a long-running project file doesn't drag old usage
  into today's number.

Totals are grouped per model, so Opus and Haiku usage are listed separately.

## Not included

- **Dollar costs.** That needs a hardcoded price table, which goes stale the
  moment pricing changes. Deliberately left out.
- **Rate-limit / quota status.** Not present in the transcripts; it would need
  an API call.

## Files

| File | Purpose |
|---|---|
| `claude-tray.ps1` | The whole app |
| `install.ps1` | Startup-shortcut installer / uninstaller |
| `test-usage.ps1` | Self-check for the parsing logic |
| `hud-pos.txt` | Generated — saved window position |

## Tests

```powershell
powershell -NoProfile -File test-usage.ps1
```

Builds throwaway JSONL fixtures and asserts the parsing: dedupe by `message.id`,
the date cutoff, per-model splitting, and number formatting. Prints `OK`, or
throws on the first failure. It doesn't touch your real transcripts.

## Troubleshooting

**Nothing in the tray.** Windows may have hidden it in the overflow area — click
the `^` chevron on the taskbar, or check Settings → Personalization → Taskbar →
*Other system tray icons*. Confirm it's actually running with:

```powershell
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '*-File *claude-tray.ps1*' } |
  Select-Object ProcessId, CreationDate
```

Note the `$PID` exclusion — without it the query matches its own command line and
reports a process that isn't the app.

**To see startup errors,** run it in a visible window and drop `-WindowStyle
Hidden`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File claude-tray.ps1
```

**All zeros.** Check that `%USERPROFILE%\.claude\projects` exists and holds
`.jsonl` files. If Claude Code stores its data elsewhere on that machine, edit
the `$Root` line at the top of `claude-tray.ps1`.

**"Running scripts is disabled on this system."** That's PowerShell's execution
policy. The `-ExecutionPolicy Bypass` flag in the commands above handles it per
run without changing any machine-wide setting.

**The floating window is in the way.** Drag it, or toggle it off from the tray
menu — the tray icon keeps working without it.
