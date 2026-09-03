# omarchy-task-manager

Native GTK4 task manager v5 for Omarchy: CPU/GPU stats, thermals, temp-driven fan curves, compact mode, settings, and a searchable process table.

Application id: `art.sw.omarchy.TaskManager`

## Install

```bash
git clone https://github.com/HurlyDesousa/omarchy-task-manager.git
cd omarchy-task-manager
./install.sh
```

Installs `python`, `python-gobject`, and `gtk4` if needed, copies the app to `~/.local/bin/omarchy-task-manager`, installs a desktop entry, and writes a marked block into `~/.config/hypr/autostart.lua` so the app starts with the Hyprland session and floats in the bottom-right corner. Safe to re-run.

Open Walker and search for **Task Manager**, or `hyprctl reload` and log in again for autostart.

### Or as a package

```bash
makepkg -si
```

Works on aarch64 and x86_64 (`arch=('any')`). No venv. No pip.

## What it shows

- **CPU** % from `/proc/stat` (core count not hardcoded), per-core bars; **CPU temp** shown on the right of the CPU row (mirrors GPU layout)
- **GPU** % from `/sys/class/devfreq/3d00000.gpu` `cur_freq / max_freq` (Snapdragon X Elite, `simple_ondemand` governor). Em-dash if absent.
- **GPU temp**: max of `gpuss_0_thermal … gpuss_7_thermal` hwmon sensors (`temp1_input / 1000 °C`), shown on the right of the GPU row. Em-dash if absent.
- **Fan L / Fan R** RPM via `x1e-ec-tool get-speed` (or `sudo -n`, or hwmon `fan*_input`)
- **Fan profiles** — four one-click buttons with optional temp-driven curves (see below)
- **Process table**: name, PID, CPU %, RSS — sortable, searchable; End process is SIGTERM then SIGKILL
- **Colors** from `~/.local/state/omarchy/current/theme/colors.toml` (live-reload via Gio directory monitor), JetBrainsMono Nerd Font, GTK/dark fallback

## Fan profiles

Four buttons sit below the fan readout. They call `x1e-ec-tool` directly using `mode` + `set-speed` — never `profile`/`profile get`/`get-profile`. Does not stop `x1e-ec-tool.service`.

| Label | Curves OFF (one-shot) | Curves ON |
|---|---|---|
| **Saver** | `mode manual` → `set-speed 1800` | `mode manual` + continuous curve: 40 °C→1500, 55 °C→1800, 70 °C→2500, 85 °C→3500 RPM |
| **Balanced** | `mode auto` (EC temp-loop owns RPM) | `mode manual` + continuous curve: 40 °C→1800, 55 °C→2800, 70 °C→4500, 85 °C→6000 RPM |
| **Performance** | `mode manual` → `set-speed 4500` | `mode manual` + continuous curve: 40 °C→2500, 55 °C→4000, 70 °C→6000, 85 °C→8000 RPM |
| **Full Send** | `mode manual` → `set-speed 8000` | Same — always full speed, no curve |

When **Temp-driven fan curves** is on (default), Saver / Balanced / Performance map CPU temperature to RPM linearly between the anchors above, updating every 2 s and sending `set-speed` only when the target shifts by > 200 RPM or 5 s have elapsed (to avoid EC spam). Full Send always applies once at 8000 RPM regardless of the curves setting.

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
| Temp-driven fan curves | Saver / Balanced / Performance continuously track CPU temp → RPM; Full Send unaffected |
| Pin to bottom-right | Move to bottom-right on expand |
| Start with Hyprland session | Adds/removes `o.launch_on_start` in `~/.config/hypr/autostart.lua`; the float+move window rule is preserved when disabled |

Settings saved to `~/.local/state/omarchy/task-manager/prefs.json`. The Autostart toggle writes directly to `autostart.lua` (no prefs.json entry).

## Hyprland

`install.sh` inserts this block into `~/.config/hypr/autostart.lua`:

```lua
-- omarchy-task-manager begin
-- Float bottom-right; no size rule so expand can grow freely.
o.launch_on_start("BIN")
o.window("art.sw.omarchy.TaskManager", {
  float = true,
  move = { "monitor_w * 0.5", "monitor_h * 0.75" },
})
-- omarchy-task-manager end
```

No `size` rule — the app manages its own dimensions. Re-running `install.sh` replaces the marked block in-place.
