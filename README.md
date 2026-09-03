# omarchy-task-manager

Native GTK4 task manager v3 for Omarchy: CPU/GPU stats, thermals, fan profiles, compact mode, settings, and a searchable process table.

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

- **CPU** % from `/proc/stat` (core count not hardcoded), per-core bars
- **CPU temp**: max of `cpu0-0-top-thermal` / `cpu1-0-top-thermal` / `cpu2-0-top-thermal`, else hottest `cpu*` thermal zone
- **GPU** % from `/sys/class/devfreq/3d00000.gpu` `cur_freq / max_freq` (Snapdragon X Elite, `simple_ondemand` governor). Em-dash if absent.
- **GPU temp**: max of `gpuss_0_thermal … gpuss_7_thermal` hwmon sensors (`temp1_input / 1000 °C`), shown in the GPU row. Em-dash if absent.
- **Fan L / Fan R** RPM via `x1e-ec-tool get-speed` (or `sudo -n`, or hwmon `fan*_input`)
- **Fan profiles** — four one-click buttons (see below)
- **Process table**: name, PID, CPU %, RSS — sortable, searchable; End process is SIGTERM then SIGKILL
- **Colors** from `~/.local/state/omarchy/current/theme/colors.toml` (live-reload via Gio directory monitor), JetBrainsMono Nerd Font, GTK/dark fallback

## Fan profiles

Four buttons sit below the thermal/fan readout. They call `x1e-ec-tool` directly using `mode` + `set-speed` — never `profile`/`profile get`/`get-profile`. Does not stop `x1e-ec-tool.service`.

| Label | Commands |
|---|---|
| Battery saver | `mode manual` → `set-speed 1800` |
| Balance | `mode auto` (ec-service temp-loop owns RPM) |
| Performance | `mode manual` → `set-speed 4500` |
| Full speed | `mode manual` → `set-speed 8000` |

After applying, `get-speed` is called; actual RPM appears in a 5 s auto-clearing status line. Errors surface in red. `hurly` needs to be in the `i2c` group (or `sudo -n` must work). Last-used profile saved to `~/.local/state/omarchy/task-manager/fan-profile`.

## Compact / expand

Click **Processes ▾** to show the process table (expand). Click **Processes ▴** to hide it (collapse). Window geometry is applied via the Hyprland 0.56.1 Lua eval API:

```
hyprctl eval 'hl.dsp.window.resize({ x = W, y = H })'
hyprctl eval 'hl.dsp.window.move({ x = X, y = Y })'
```

Compact: 50 % × 25 % of monitor (bottom-right quarter).  
Expanded: 50 % × 50 % of monitor (bottom-right half).

## Settings (⚙)

The gear button to the right of the Processes toggle opens a popover:

| Option | Effect |
|---|---|
| Start compact | Always open collapsed |
| Remember last state | Restore compact/expanded across sessions |
| Refresh interval | 500 ms / 1 s / 2 s / 5 s — updates the live timer |
| Show GPU row | Hides/shows the GPU % + temp row |
| Pin to bottom-right | Move to bottom-right on expand |

Settings saved to `~/.local/state/omarchy/task-manager/prefs.json`.

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
