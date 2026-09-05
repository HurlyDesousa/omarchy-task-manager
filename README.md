# omarchy-task-manager

Native GTK4 task manager v5 for Omarchy: CPU/GPU/RAM stats, thermals, temp-driven fan curves, compact mode, settings, and a searchable process table.

Application id: `art.sw.omarchy.TaskManager`

## Install

```bash
git clone https://github.com/HurlyDesousa/omarchy-task-manager.git
cd omarchy-task-manager
./install.sh
```

Installs `python`, `python-gobject`, and `gtk4` if needed, copies the app to `~/.local/bin/omarchy-task-manager`, installs a desktop entry, writes a marked block into `~/.config/hypr/autostart.lua`, installs the Quickshell bar-widget plugin, and patches `~/.config/omarchy/shell.json` to add the icon next to `omarchy.weather`. Safe to re-run.

After install, restart the Omarchy shell:

```bash
omarchy-restart-shell
```

Or manually: `omarchy-shell shell rescanPlugins && omarchy plugin enable sw.art.task-manager`

Open Walker and search for **Task Manager**, or `hyprctl reload` and log in again for autostart.

### Or as a package

```bash
makepkg -si
```

Works on aarch64 and x86_64 (`arch=('any')`). No venv. No pip.

## Quickshell bar widget

The `sw.art.task-manager` plugin ships in `shell/sw.art.task-manager/` and is installed to `~/.config/omarchy/plugins/sw.art.task-manager/`. `install.sh` places `{ "id": "sw.art.task-manager" }` into `~/.config/omarchy/shell.json` `bar.layout.center` directly after `omarchy.weather` (idempotent; never clobbers other entries).

The `󰓅` icon appears in the Quickshell bar next to the weather widget. Click it to show or hide the Task Manager.

**Click behavior** (via `omarchy-task-manager-toggle`):

| App state | Action |
|---|---|
| Not running | Launch `omarchy-task-manager` (single instance via GTK app id) |
| On regular workspace | Move to `special:taskmanager` — hidden |
| On `special:taskmanager` | `toggle_special` — bring back into view |

The toggle uses the Hyprland Lua eval API (compatible with Lua-based Hyprland sessions):

```bash
# Hide: move to special workspace
hyprctl eval 'hl.dsp.window.move({ workspace = "special:taskmanager", follow = false, window = "address:…" })'

# Show: toggle special workspace visibility
hyprctl eval 'hl.dsp.workspace.toggle_special("taskmanager")'
```

## What it shows

- **CPU** % from `/proc/stat` (core count not hardcoded), per-core bars; **CPU temp** shown on the right of the CPU row (mirrors GPU layout)
- **GPU** % from `/sys/class/devfreq/3d00000.gpu` `cur_freq / max_freq` (Snapdragon X Elite, `simple_ondemand` governor). Em-dash if absent.
- **GPU temp**: max of `gpuss_0_thermal … gpuss_7_thermal` hwmon sensors (`temp1_input / 1000 °C`), shown on the right of the GPU row. Em-dash if absent.
- **RAM** used/total from `/proc/meminfo` (`MemTotal`, `MemAvailable` → used = total − available): **%** and progress bar on the left, `used / total GiB` on the right (same row layout as CPU/GPU). Visible in compact mode.
- **Fan L / Fan R** RPM via `x1e-ec-tool get-speed` (or `sudo -n`, or hwmon `fan*_input`)
- **Fan profiles** — four one-click buttons with optional temp-driven curves (see below)
- **Process table**: name, PID, CPU %, RSS — sortable, searchable; End process is SIGTERM then SIGKILL
- **Colors** from `~/.local/state/omarchy/current/theme/colors.toml` (live-reload via Gio directory monitor), JetBrainsMono Nerd Font, GTK/dark fallback

## Fan profiles

Four buttons sit below the fan readout. They call `x1e-ec-tool` directly using `mode` + `set-speed` — never `profile`/`profile get`/`get-profile`. Does not stop `x1e-ec-tool.service`.

| Label | Curves OFF (one-shot) | Curves ON |
|---|---|---|
| **Power Saver** | `mode manual` → `set-speed 1800` | `mode manual` + continuous curve: 40 °C→1500, 55 °C→1800, 70 °C→2500, 85 °C→3500 RPM |
| **Balanced** | `mode auto` (EC temp-loop owns RPM) | `mode manual` + continuous curve: 40 °C→1800, 55 °C→2800, 70 °C→4500, 85 °C→6000 RPM |
| **Performance** | `mode manual` → `set-speed 4500` | `mode manual` + continuous curve: 40 °C→2500, 55 °C→4000, 70 °C→6000, 85 °C→8000 RPM |
| **Full Send** | `mode manual` → `set-speed 8000` | Same — always full speed, no curve |

When **Temp-driven fan curves** is on (default), Power Saver / Balanced / Performance map CPU temperature to RPM linearly between the anchors above, updating every 2 s and sending `set-speed` only when the target shifts by > 200 RPM or 5 s have elapsed (to avoid EC spam). Full Send always applies once at 8000 RPM regardless of the curves setting.

After applying in one-shot mode, `get-speed` is called; actual RPM appears in a 5 s auto-clearing status line. Errors surface in red. `hurly` needs to be in the `i2c` group (or `sudo -n` must work). Last-used profile saved to `~/.local/state/omarchy/task-manager/fan-profile`.

## Compact / expand

Click **Processes ▾** to show the process table (expand). Click **Processes ▴** to hide it (collapse). Window geometry is applied via the Hyprland 0.56.1 Lua eval API:

```
hyprctl eval 'hl.dsp.window.resize({ x = W, y = H })'
hyprctl eval 'hl.dsp.window.move({ x = X, y = Y })'
```

Compact: 50 % × 25 % of monitor (bottom-right quarter).  
Expanded: 50 % × 50 % of monitor (bottom-right half).

## Settings (⚙)

The header strip always shows **Processes ▾ | Filter by name or PID | ⚙**. Typing in the search field filters the process list whether the panel is expanded or collapsed; the filtered view is ready on first expand.

The ⚙ gear icon is CSS-colored from the live Omarchy theme (same `fg` color as the rest of the UI; re-applied on theme hot-swap).

The gear button opens a settings popover:

| Option | Effect |
|---|---|
| Start compact | Always open collapsed |
| Remember last state | Restore compact/expanded across sessions |
| Refresh interval | 500 ms / 1 s / 2 s / 5 s — updates the live timer |
| Show GPU row | Hides/shows the GPU % + temp row |
| Temp-driven fan curves | Power Saver / Balanced / Performance continuously track CPU temp → RPM; Full Send unaffected |
| Pin to bottom-right | Move to bottom-right on expand |
| Start with Hyprland session | Adds/removes `o.launch_on_start` in `~/.config/hypr/autostart.lua`; the float+move window rule is preserved when disabled |

Settings saved to `~/.local/state/omarchy/task-manager/prefs.json`. The Autostart toggle writes directly to `autostart.lua` (no prefs.json entry).

## Hyprland

`install.sh` inserts this block into `~/.config/hypr/autostart.lua`:

```lua
-- omarchy-task-manager begin
o.launch_on_start("~/.local/bin/omarchy-task-manager")
o.window("art.sw.omarchy.TaskManager", { float = true })
-- omarchy-task-manager end
```

Float-only window rule — no size or move pin. The app manages its own dimensions. Re-running `install.sh` replaces the marked block in-place.

## Waybar (optional)

Waybar is **not required**. The primary toggle path is the Quickshell bar widget above.

If Waybar is present (`~/.config/waybar/config.jsonc` exists), `install.sh` also adds a `󰓅` icon to `modules-center` next to `custom/weather`. Clicking it calls the same `omarchy-task-manager-toggle` script.

Two scripts are installed to `~/.local/bin`:

| Script | Purpose |
|---|---|
| `omarchy-task-manager-toggle` | Click handler — launch / show / hide via Lua hyprctl eval |
| `omarchy-task-manager-waybar` | Waybar `exec` — outputs JSON icon + running state |

Waybar module definition added to `config.jsonc`:

```jsonc
"custom/omarchy-task-manager": {
    "exec": "omarchy-task-manager-waybar",
    "return-type": "json",
    "interval": 5,
    "on-click": "omarchy-task-manager-toggle",
    "tooltip": true
}
```

CSS added to `style.css`:

```css
#custom-omarchy-task-manager {
  margin-right: 8px;
}
```
