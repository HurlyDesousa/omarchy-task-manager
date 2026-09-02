# omarchy-task-manager

Native GTK4 task manager for Omarchy: overall and per-core CPU, CPU temperature, optional fan RPM, and a searchable process table.

Application id: `art.sw.omarchy.TaskManager`

## Install

```bash
git clone https://github.com/HurlyDesousa/omarchy-task-manager.git
cd omarchy-task-manager
./install.sh
```

That installs `python`, `python-gobject`, and `gtk4` if needed, copies the app to `~/.local/bin/omarchy-task-manager`, installs a desktop entry with a full `Exec=` path so Walker finds it with no PATH hacks, and writes a marked block into `~/.config/hypr/autostart.lua` so the app starts with the Hyprland session and floats in the bottom-right quarter. Safe to re-run. Does not overwrite `hyprland.lua` (it only adds `require("hypr.autostart")` if that file exists and the require is missing).

Then open Walker and search for **Task Manager**, or `hyprctl reload` and log in again for autostart.

### Or as a package

From the same clone:

```bash
makepkg -si
```

Works on aarch64 and x86_64 (`arch=('any')`). No venv. No pip. No Origin. `makepkg` installs the binary only; run `./install.sh` as well if you want the Hyprland autostart + window rules.

## Fans

Optional. Reads `/usr/local/bin/x1e-ec-tool get-speed` (or `x1e-ec-tool` on PATH). Parses `Left Fan: N RPM` / `Right Fan: N RPM` from stdout and stderr even if the exit code is non-zero. If the user cannot open `/dev/i2c-*`, it tries `sudo -n x1e-ec-tool get-speed` (never a password prompt). Last fallback is hwmon `fan*_input` nodes. Missing tool, PermissionError, or timeout shows — and the app keeps running. Does not start or stop `x1e-ec-tool.service`. On the Vivobook S15, hurly also needs i2c access (udev + `i2c` group) so get-speed works without sudo.

## Hyprland

`install.sh` inserts this marked block into `~/.config/hypr/autostart.lua` (`BIN` is the full `~/.local/bin/omarchy-task-manager` path):

```lua
-- omarchy-task-manager begin
o.launch_on_start("BIN")
o.window("art.sw.omarchy.TaskManager", {
  float = true,
  size = { "monitor_w * 0.5", "monitor_h * 0.5" },
  move = { "monitor_w * 0.5", "monitor_h * 0.5" },
})
-- omarchy-task-manager end
```

Re-running `install.sh` replaces that marked block in place. If the laptop already has an unlabeled `o.launch_on_start` / `o.window` for this app, those copies are removed first so you never get a second launch. Other entries in `autostart.lua` are left alone.

Omarchy already `require("hypr.autostart")` from `hyprland.lua`. Size and move are 50% of the monitor, so the window sits in the bottom-right quarter. The GTK window also defaults to about half the primary monitor before those rules apply.

## What it shows

- CPU % from `/proc/stat` (core count is not hardcoded)
- CPU temp: max of `cpu0-0-top-thermal`, `cpu1-0-top-thermal`, `cpu2-0-top-thermal`, else hottest `cpu*` thermal zone
- Process name, PID, CPU %, RSS — sort and search; End process is SIGTERM, then SIGKILL if it is still alive
- Colors from `~/.config/omarchy/current/theme/` (`waybar.css` / `colors.toml`), JetBrainsMono Nerd Font, dark fallback
