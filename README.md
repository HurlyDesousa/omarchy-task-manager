# omarchy-task-manager

Native GTK4 task manager for Omarchy: compact CPU/thermal/fan strip by default, optional expandable process list, fan profile control on ASUS Vivobook S 15, and live Omarchy theme colors.

Application id: `art.sw.omarchy.TaskManager`

## Install

```bash
git clone https://github.com/HurlyDesousa/omarchy-task-manager.git
cd omarchy-task-manager
./install.sh
```

That installs `python`, `python-gobject`, and `gtk4` if needed (never blocks on a sudo password), copies the app to `~/.local/bin/omarchy-task-manager`, installs a desktop entry with a full `Exec=` path so Walker finds it with no PATH hacks, and merges a marked block into `~/.config/hypr/autostart.lua` so the app starts with the Hyprland session and floats in a bottom-right strip. Safe to re-run.

Then open Walker and search for **Task Manager**, or `hyprctl reload` and log in again for autostart.

### Or as a package

From the same clone:

```bash
makepkg -si
```

Works on aarch64 and x86_64 (`arch=('any')`). No venv. No pip. `makepkg` installs the binary only; run `./install.sh` as well if you want the Hyprland autostart + window rules.

## Compact layout

By default the window shows CPU (overall + per-core), temperature, fan RPM (Fan L / Fan R), and four fan profile buttons. The process table is hidden until you click **Processes ▾**; click **Processes ▴** to collapse back to the compact strip. Compact mode keeps the process tree out of the GTK widget tree so the window can fit a 25%-height Hyprland strip; expanding grows the window for a usable list.

## Fans (Vivobook S 15)

Uses `/usr/local/bin/x1e-ec-tool` (or `x1e-ec-tool` on PATH).

**RPM:** `get-speed` as the user, then `sudo -n get-speed` if i2c access fails, then hwmon `fan*_input` fallback. Parses `Left Fan: N RPM` / `Right Fan: N RPM` from stdout and stderr.

**Profiles** (EC register `0x24`; does not stop `x1e-ec-tool.service`):

| Button | `x1e-ec-tool profile N` | EC mode |
|--------|-------------------------|---------|
| Battery saver | 0 | Whisper |
| Balance | 1 | Standard |
| Performance | 2 | Performance |
| Full speed | 3 | Full speed |

Runs `x1e-ec-tool profile N` as the user first, then `sudo -n` with the same command if needed. The active profile is highlighted. Missing tool or permission errors show in the UI flow without crashing the app.

## Hyprland

`install.sh` idempotently merges this marked block into `~/.config/hypr/autostart.lua` (`BIN` is the full `~/.local/bin/omarchy-task-manager` path):

```lua
-- omarchy-task-manager begin
-- Bottom-right quarter + start with the Hyprland session.
o.launch_on_start("BIN")
o.window("art.sw.omarchy.TaskManager", {
  float = true,
  size = { "monitor_w * 0.5", "monitor_h * 0.25" },
  move = { "monitor_w * 0.5", "monitor_h * 0.75" },
})
-- omarchy-task-manager end
```

Re-running `install.sh` updates size/move in the marked block. Unlabeled `o.launch_on_start` / `o.window` entries for this app are removed first so you never get a duplicate launch. Other autostart lines are untouched.

Omarchy already `require("hypr.autostart")` from `hyprland.lua`; `install.sh` only appends that require if missing.

## Theme

Live Omarchy theme files live under `~/.local/state/omarchy/current/theme/` (symlink; `btop.theme`, `colors.toml`, `waybar.css`). The app watches that directory with Gio and reapplies CSS on theme switches without restart. Colors come from loaded `colors.toml` / `waybar.css` plus GTK named colors, with Adwaita-dark fallbacks when files are absent.

## Process list (expanded)

When expanded: name, PID, CPU %, RSS — sort and search; **End process** sends SIGTERM, then SIGKILL if still alive.
