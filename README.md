# omarchy-task-manager

Native GTK4 task manager for Omarchy: overall and per-core CPU, CPU temperature, optional fan RPM, and a searchable process table.

Application id: `art.sw.omarchy.TaskManager`

## Install

```bash
git clone https://github.com/HurlyDesousa/omarchy-task-manager.git
cd omarchy-task-manager
./install.sh
```

That installs `python`, `python-gobject`, and `gtk4` if needed, copies the app to `~/.local/bin/omarchy-task-manager`, and installs a desktop entry with a full `Exec=` path so Walker finds it with no PATH hacks. Safe to re-run.

Then open Walker and search for **Task Manager**.

### Or as a package

From the same clone:

```bash
makepkg -si
```

Works on aarch64 and x86_64 (`arch=('any')`). No venv. No pip. No Origin.

## Fans

Optional. Uses `/usr/local/bin/x1e-ec-tool get-speed` when that binary exists. If it is missing or fails, RPM shows — and the app keeps running. Never requires root.

## Hyprland (optional)

Do not overwrite `hyprland.conf`. To float it:

```
windowrulev2 = float, class:^(art.sw.omarchy.TaskManager)$
```

## What it shows

- CPU % from `/proc/stat` (core count is not hardcoded)
- CPU temp: max of `cpu0-0-top-thermal`, `cpu1-0-top-thermal`, `cpu2-0-top-thermal`, else hottest `cpu*` thermal zone
- Process name, PID, CPU %, RSS — sort and search; End process is SIGTERM, then SIGKILL if it is still alive
- Colors from `~/.config/omarchy/current/theme/` (`waybar.css` / `colors.toml`), JetBrainsMono Nerd Font, dark fallback
