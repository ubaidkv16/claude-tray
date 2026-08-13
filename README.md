# claude-tray

A Windows system-tray readout of your [Claude Code](https://claude.com/claude-code)
token usage.

One PowerShell script. No dependencies, no build step, no runtime to install, no
admin rights, no network access. It reads the JSONL transcripts Claude Code
already writes to disk and totals the tokens.

```
┌─ tray tooltip ─────────────────────────────────┐
│ Claude today: 41.2k in / 18.9k out / 2.1M cache│
└────────────────────────────────────────────────┘

┌─ right-click menu ──────────────┐   ┌─ floating window ─────┐
│ TODAY  147 msgs                 │   │ Claude Code usage     │
│   in 41.2k  out 18.9k  cache 2.1M│  │                       │
│   claude-opus-5: 131 msgs, 17.4k │  │ TODAY  147 msgs       │
│   claude-haiku-4-5: 16 msgs, 1.5k│  │  in 41.2k  out 18.9k  │
│ ───────────────────────────────  │  │  cache 2.1M           │
│ LAST 7 DAYS  1,204 msgs          │  │ 7d  1204 msgs, 210k   │
│   in 380k  out 210k  cache 24.8M │  └───────────────────────┘
│ ───────────────────────────────  │
│ Updated 14:32:08                 │
│ Refresh now                      │
│ Settings                       ▸ │
│ Exit                             │
└──────────────────────────────────┘
```

## Features

- **Tray icon** — hover for today's totals, right-click for the full breakdown.
- **Per-model split** — Opus, Sonnet and Haiku counted separately.
- **Today and last-7-days** views, with message counts.
- **Floating window** — a small always-on-top box you can drag to any monitor,
  since Windows 11 confines the tray to the primary display.
- **Auto-refresh** every 60 seconds, plus manual refresh.
- **Accurate counting** — deduplicates the repeated entries transcripts contain
  after a session resume (see [What it counts](#what-it-counts)).

## Requirements

| | |
|---|---|
| OS | Windows 10 or 11 |
| Shell | Windows PowerShell 5.1 — **preinstalled on every Windows machine** |
| Other | Claude Code, having run at least once |

Explicitly **not** required: Python, Node.js, winget, Visual C++ redistributables,
admin rights, or an internet connection. If you have Windows, you can already run
this.

## Install

### 1. Get the files

```powershell
git clone https://github.com/ubaidkv16/claude-tray.git
cd claude-tray
```

No git? Download the ZIP from the repo's green **Code** button and extract it.
There is nothing compiled — copying the folder by hand works just as well.

### 2. Install

**Just double-click `Install - Start With Windows.cmd`.**

That's the whole install. It registers the app to launch hidden on every login
and starts it immediately.

Prefer a terminal? Same thing:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

> **Why the `.cmd` files?** Windows opens `.ps1` files in Notepad when you
> double-click them instead of running them. The `.cmd` wrappers are just
> double-clickable entry points to the same scripts — you never need to touch a
> terminal to use this app.

Everything resolves its own location, so the repo can live anywhere and there are
no paths to edit. You should see the tray icon appear, plus a readout box at the
top-right of your primary screen.

### Run once, without installing

Double-click **`Start Claude Tray.cmd`**. It runs the app without registering
anything for startup. Or from a terminal:

```powershell
powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File claude-tray.ps1
```

### Uninstall

Double-click **`Uninstall.cmd`**, or:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

Removes the startup shortcut and stops the running copy. The only leftover is
`hud-pos.txt` in the repo folder; delete the folder and it's gone without trace.
Nothing is written to the registry, and nothing is installed system-wide.

> **About `-ExecutionPolicy Bypass`:** by default Windows blocks unsigned
> scripts. This flag applies to that single invocation only — it does not change
> any machine-wide setting or weaken your system's policy.

## Usage

| Action | Result |
|---|---|
| Hover tray icon | Today's in / out / cache tokens |
| Right-click tray icon | Full menu: per-model today, 7-day totals, actions |
| Double-click tray icon | Refresh immediately |
| Menu → **Refresh now** | Same, from the menu |
| Menu → **Settings** | Options submenu — see below |
| Drag the floating box | Move to any monitor; position is remembered |
| Menu → **Exit** | Quit. Returns at next login, or relaunch by hand |

### Settings

Right-click the tray icon → **Settings**:

| Setting | Does |
|---|---|
| **Show floating window** | Toggles the always-on-top box. Ticked when visible |
| **Start with Windows** | Adds/removes the startup shortcut. Ticked when enabled |
| **Refresh every** | 30 seconds, 1 minute, 5 minutes, or 15 minutes |
| **Reset window position** | Puts the floating box back at the primary screen's top-right, for when it's ended up somewhere awkward |

Your choices are saved to `settings.json` beside the script and restored on the
next launch — including whether the floating window should appear at all, so if
you turn it off it stays off.

The floating box is borderless — there's no title bar, so drag it from anywhere
on its body. Its position is saved to `hud-pos.txt` next to the script and
restored on the next launch. Delete that file to reset it to the primary screen's
top-right corner.

## Reopening it after you close it

Depends on which thing you closed.

**You closed the floating box, but the tray icon is still there.**
Right-click the tray icon → **Show floating window**. It's a toggle.

**You chose Exit, or killed the process.** Any of these bring it back:

- **Double-click `Start Claude Tray.cmd`** in the folder — the easy one.
- **Start menu** — press <kbd>Win</kbd>, type `claude tray`, press Enter.
  (Right-click it there to pin it to Start or the taskbar.)
- **Startup folder** — press <kbd>Win</kbd>+<kbd>R</kbd>, enter `shell:startup`,
  and double-click **claude-tray**.
- **Command line:**

  ```powershell
  powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File claude-tray.ps1
  ```

- **Do nothing** — it starts again by itself at your next login, which is what
  the startup shortcut installed by `install.ps1` is for.

Note that `install.ps1` creates the Startup entry. If you want the Start-menu
entry as well:

```powershell
$s = (New-Object -ComObject WScript.Shell).CreateShortcut(
       "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Claude Tray.lnk")
$s.TargetPath = 'powershell.exe'
$s.Arguments  = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PWD\claude-tray.ps1`""
$s.WorkingDirectory = "$PWD"
$s.WindowStyle = 7
$s.Save()
```

Nothing prevents launching it twice, which gives you two identical tray icons.
Harmless — just pick one and hit **Exit**.

## Which monitor things appear on

The **tray icon can only ever live on your primary display.** Windows 11 gives
the notification area to the primary taskbar only — secondary taskbars get app
buttons and a clock, but no tray. No application can change this. To move it,
change which display is primary: Settings → System → Display →
*Make this my main display*.

The **floating window has no such limit**, which is precisely why it exists. It
opens on the primary screen and remembers wherever you drag it.

## How it works

Claude Code writes a JSONL transcript per session under
`%USERPROFILE%\.claude\projects\`. Every assistant message carries a `usage`
object with its token counts. The script walks those files, sums the numbers, and
renders them into a WinForms `NotifyIcon` — the same tray API any native Windows
app uses, available from PowerShell because .NET ships with Windows.

That's the entire design. There's no service, no database, no polling of any API,
and no configuration file.

### What it counts

Per assistant message:

- `input_tokens`
- `output_tokens`
- `cache_read_input_tokens` + `cache_creation_input_tokens`, displayed together
  as **cache**

Two details that matter for correctness:

- **Deduplication.** Transcripts replay earlier entries when a session resumes,
  so one message can appear several times across files. Entries are deduped by
  `message.id`, otherwise resumed sessions inflate every total.
- **Two-stage date filtering.** Both the file's `LastWriteTime` *and* each
  entry's own `timestamp` are checked. Filtering only by file time would drag
  months of old usage into "today" for any long-lived project.

Totals are grouped by model, so a cheap Haiku call isn't averaged in with Opus.

### Privacy

Everything is local. The script makes no network calls of any kind — it only
reads files already on your disk, and only the `usage` and `timestamp` fields.
Your prompts and Claude's replies are never read, parsed, logged, or transmitted.

## Configuration

Most things you'd want to change are in the [Settings menu](#settings). For the
rest, edit `claude-tray.ps1` directly — it's a short script:

| What | Where | Default |
|---|---|---|
| Transcript location | `$Root` | `%USERPROFILE%\.claude\projects` |
| Window transparency | `$hud.Opacity` | `0.9` |
| Window colours | `$hud.BackColor` / `.ForeColor` | dark grey / light grey |
| Window font | `$hudLabel.Font` | Consolas 9 |

The floating window sizes itself to its contents, so there's no width or height
to set — change the font and it adjusts.

## Not included, on purpose

- **Dollar cost estimates.** These need a hardcoded price table that goes stale
  the moment pricing changes, and silently-wrong money figures are worse than
  none. Token counts are exact; costs would be a guess.
- **Rate-limit / quota status.** Not present in the transcripts. It would require
  an authenticated API call, which would mean handling credentials — a large
  jump in scope for a tray widget.

## Files

| File | Purpose |
|---|---|
| **`Start Claude Tray.cmd`** | **Double-click to run it** |
| **`Install - Start With Windows.cmd`** | **Double-click to install for every login** |
| **`Uninstall.cmd`** | **Double-click to remove it** |
| `claude-tray.ps1` | The entire application |
| `install.ps1` | The installer the `.cmd` wrappers call |
| `test-usage.ps1` | Self-check for the parsing logic |
| `hud-pos.txt` | *Generated* — saved window position (gitignored) |
| `settings.json` | *Generated* — your Settings choices (gitignored) |

## Tests

```powershell
powershell -NoProfile -File test-usage.ps1
```

Builds throwaway JSONL fixtures in `%TEMP%` and asserts the parsing behaviour:
dedupe by `message.id`, the date cutoff, per-model splitting, and number
formatting. Prints `OK`, or throws on the first failed assertion. It never reads
or modifies your real transcripts.

No test framework — it's plain `throw` on a bad value, so it runs anywhere
PowerShell does.

## Troubleshooting

<details>
<summary><b>No icon in the tray</b></summary>

Windows often hides new tray icons in the overflow area. Click the `^` chevron on
the taskbar, or pin it permanently via Settings → Personalization → Taskbar →
*Other system tray icons*.

To confirm it's actually running:

```powershell
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '*-File *claude-tray.ps1*' } |
  Select-Object ProcessId, CreationDate
```

The `$PID` exclusion matters: without it, the query matches *its own* command
line and cheerfully reports a running app that doesn't exist.
</details>

<details>
<summary><b>It won't start, and I can't see why</b></summary>

Run it in a visible window so errors are readable — drop `-WindowStyle Hidden`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File claude-tray.ps1
```
</details>

<details>
<summary><b>All the numbers are zero</b></summary>

Check that `%USERPROFILE%\.claude\projects` exists and contains `.jsonl` files:

```powershell
Get-ChildItem "$env:USERPROFILE\.claude\projects" -Recurse -Filter *.jsonl | Measure-Object
```

If it's empty, Claude Code hasn't run on this machine yet. If your transcripts
live somewhere else, edit `$Root` at the top of `claude-tray.ps1`.
</details>

<details>
<summary><b>"Running scripts is disabled on this system"</b></summary>

PowerShell's execution policy. Use the `-ExecutionPolicy Bypass` flag shown in
every command above; it's per-invocation and changes nothing permanently.
</details>

<details>
<summary><b>The floating window is in the way</b></summary>

Drag it elsewhere, or toggle it off from the tray menu — the tray icon works
perfectly well without it. To stop it appearing at startup, remove the
`Show-Hud` line near the bottom of `claude-tray.ps1`.
</details>

<details>
<summary><b>It's slow with a lot of history</b></summary>

Every refresh rescans the transcripts, filtered by file modification time first.
With a very large `~/.claude/projects` the 7-day query can take a moment. Raise
`$timer.Interval` if you notice it.
</details>

## License

MIT — see [LICENSE](LICENSE).
