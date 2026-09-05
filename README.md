# omarchy-task-manager

Native Task Manager for Omarchy: CPU/GPU/RAM stats, thermals, fan monitoring (read-only), compact/expand process table, settings, and live Omarchy theme — all in a **Weather-style KeyboardPanel** popout from the bar icon.

Application id (legacy): `art.sw.omarchy.TaskManager`

## Install

```bash
git clone https://github.com/HurlyDesousa/omarchy-task-manager.git
cd omarchy-task-manager
./install.sh
```

Installs `python` if needed, copies the stats backend and toggle scripts to `~/.local/bin/`, installs the Quickshell bar-widget plugin (`BarWidget.qml` + `Panel.qml`), and patches `~/.config/omarchy/shell.json` to add the icon next to `omarchy.weather`. Safe to re-run.

After install, restart the Omarchy shell:

```bash
omarchy-restart-shell
```

Or manually: `omarchy-shell shell rescanPlugins && omarchy plugin enable sw.art.task-manager`

Open Walker and search for **Task Manager**, or click the `󰓅` bar icon.

### Or as a package

```bash
makepkg -si
```

Works on aarch64 and x86_64 (`arch=('any')`). No venv. No pip. No GTK dependency.

## Quickshell bar widget (KeyboardPanel)

The `sw.art.task-manager` plugin ships in `shell/sw.art.task-manager/` and installs to `~/.config/omarchy/plugins/sw.art.task-manager/`. `install.sh` places `{ "id": "sw.art.task-manager" }` into `~/.config/omarchy/shell.json` `bar.layout.center` directly after `omarchy.weather` (idempotent).

**Architecture (matches Omarchy Weather):**

- `BarWidget.qml` — Loader → `Panel.qml`, `injectPanel`, `togglePanel`, `open`/`close`/`opened`/`closeForPopoutSwitch`
- `Panel.qml` — `qs.Ui.Panel` + `KeyboardPanel` anchored to the bar button
- Border via `KeyboardPanel` defaults → `Color.popups.border` (not menu scrim)
- Full-screen transparent dismiss layer only — **no dimmed scrim**
- Icon hit area constrained to the icon slot (no `anchors.fill` on `BarIconButton`)

Click the `󰓅` icon to open/close the panel. External toggles (Waybar, desktop entry) use shell IPC:

```bash
omarchy-shell shell toggle sw.art.task-manager '{}'
# or
omarchy-task-manager-toggle
```

Stats/process data comes from the Python backend:

```bash
omarchy-task-manager snapshot   # JSON to stdout
omarchy-task-manager kill PID
```

## What it shows

- **CPU** % from `/proc/stat` (core count not hardcoded), per-core bars; **CPU temp** on the right of the CPU row
- **GPU** % from `/sys/class/devfreq/3d00000.gpu` (`cur_freq / max_freq`, Snapdragon X Elite). Em-dash if absent.
- **GPU temp**: max of `gpuss_0_thermal … gpuss_7_thermal` hwmon sensors. Em-dash if absent.
- **RAM** used/total from `/proc/meminfo`: **%** and progress bar on the left, `used / total GiB` on the right
- **Up** system uptime from `/proc/uptime` (compact `Xd Xh Xm` style) in the meta row
- **Fan L / Fan R** dual meters: compact progress bars with RPM and % of max (8000 RPM ceiling). Read-only via `x1e-ec-tool get-speed` (or `sudo -n`, or hwmon `fan*_input`). Never writes to the EC.
- **Process table**: name, PID, CPU %, RSS — searchable; End process sends SIGTERM then SIGKILL
- **Colors** from live Omarchy shell theme (`Color.popups.*`, `Style.*`)

## Compact / expand

Click **Processes ▾** to show the process table (expand). Click **Processes ▴** to hide it (collapse). Panel height adjusts via `KeyboardPanel.fittedContentHeight`.

## Settings (⚙)

The header strip shows **Processes ▾ | Filter by name or PID | ⚙**. Typing in the search field filters the process list whether expanded or collapsed.

| Option | Effect |
|---|---|
| Start compact | Always open collapsed |
| Remember last state | Restore compact/expanded across panel opens |
| Refresh interval | 500 ms / 1 s / 2 s / 5 s |

Settings saved to `~/.local/state/omarchy/task-manager/prefs.json`.

## Waybar (optional)

Waybar is **not required**. The primary path is the Quickshell bar widget.

If Waybar is present, `install.sh` adds a `󰓅` icon to `modules-center` next to `custom/weather`. Clicking it calls `omarchy-task-manager-toggle` (shell IPC). The icon shows a `running` CSS class while the panel is open.

## Version

**0.5.5-20** — Show CPU/GPU/RAM and process CPU percentages as whole numbers (no decimals).

**0.5.5-18** — Align CPU/GPU/RAM percent column: shared 44px right-aligned value width on StatRow and RamStatRow.

**0.5.5-16** — Settings view: right-align Start compact / Remember last state switches (labels left, toggles in a column on the right).

**0.5.5-15** — Fix settings toggles for real: `prefs-get` now emits single-line JSON (Panel SplitParser was failing on pretty-printed output). Restore CPU/GPU StatRow layout; keep RAM-only overlap fix via `RamStatRow`.

**0.5.5-14** — Fix settings toggles (`toggleHandler` vs reserved `onToggle`), StatRow RAM/detail bar overlap, uptime label "Uptime".

**0.5.5-13** — Fix process-table header Repeater `index` ReferenceError in Panel.qml.

**0.5.5-12** — Weather-style KeyboardPanel popout; drops GTK window and `special:taskmanager` hide/show.
