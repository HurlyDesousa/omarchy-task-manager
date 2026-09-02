# Task Manager

Native GTK4 process and CPU monitor for Omarchy / Hyprland. Application id `art.sw.omarchy.TaskManager`.

## Install

```bash
git clone https://github.com/HurlyDesousa/omarchy-task-manager.git
cd omarchy-task-manager
./install.sh
```

That copies the launcher to `~/.local/bin/omarchy-task-manager` (full path in the desktop `Exec=` so Walker finds it with no PATH hacks) and installs a desktop entry. `install.sh` is safe to re-run.

### Package install

From the same clone:

```bash
makepkg -si
```

Installs system-wide to `/usr/bin/omarchy-task-manager`.

## Notes

- Needs **python-gobject** and **gtk4** (pulled by `install.sh` / the package).
- Fan RPM is optional via [`x1e-ec-tool`](https://github.com/icecream95/x1e-ec-tool) (`get-speed`). Missing or failing tool shows an em dash; never uses root/sudo.
- Optional Hyprland windowrule so the window floats (do **not** write this into `hyprland.conf` for you):

  `windowrulev2 = float, class:^(art.sw.omarchy.TaskManager)$`

Launch **Task Manager** from Walker, or run `omarchy-task-manager`.
