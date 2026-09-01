# omawin titlebar

Windows-style caption buttons on **floating** Omarchy / Hyprland windows, using the official **hyprbars** compositor plugin.

This is not an Omarchy Quickshell plugin. Shell widgets cannot attach decorations to other applications. Title bars are drawn by Hyprland via `hyprpm` + `hyprland-plugins` / `hyprbars`.

## What you get

- Title bar with the window title (drag to move).
- Buttons on the right, Windows order: **minimize –**, **maximize □**, **close ×**.
- Double-click the title bar to maximize/restore (not true fullscreen).
- Title bars on **floating** windows only. Tiled windows keep Omarchy’s border-only look.
- Super+T stays the Omarchy float/tile toggle.
- Minimize sends the window to Omarchy’s scratchpad (`special:scratchpad`). The bar **S** lights up when something is on it; click **S** (or Super+S) to bring the scratchpad back.
- Colors follow the active Omarchy theme.

## Before you install

Tested on Omarchy Quattro (4.x) with Hyprland 0.56 Lua config (`hyprland.lua` / `looknfeel.lua`). The leftover `~/.config/hypr/*.conf` files are not used.

The installer:

- uses `hyprpm` to build and enable official hyprbars
- writes `~/.config/hypr/titlebar.lua` and a generated `titlebar-colors.lua`
- adds clearly marked blocks to `hyprland.lua` and `autostart.lua`
- timestamp-backs up every file it edits
- installs helpers in `~/.local/bin/`
- installs Omarchy hooks under `~/.config/omarchy/hooks/`
- adds the [omarchy-scratchpad](https://github.com/nlboris/omarchy-scratchpad) bar widget (`rob.scratchpad`) and places **S** after the workspaces (the click action is patched to `hyprctl dispatch`, which is Super+S on Hyprland 0.56)
- does **not** edit `/usr/share/omarchy/` or `~/.local/share/omarchy/`

**sudo** is only needed for:

1. `omarchy pkg add meson ninja` if those build tools are missing
2. `hyprpm` creating `/var/cache/hyprpm/$USER` and installing plugin headers

Run setup in a real terminal so the password prompt works.

## Install

```bash
cd ~/dev/omawin
./setup.sh
```

Use `./setup.sh --yes` to skip the confirmation prompt.

Building hyprbars can take a few minutes the first time. When it finishes, **log out of Omarchy and sign in once** so hyprbars is loaded from the start of the session.

If setup skipped the plugin because sudo could not prompt (for example a non-interactive agent run), finish it in a terminal:

```bash
~/dev/omawin/lib/install-hyprbars.sh
```

That script now runs `hyprpm update` first so plugin headers match this Hyprland build, then adds and enables hyprbars. If you see `Headers outdated, please run hyprpm update`, re-run the script (or `hyprpm update` then the script).

## Everyday controls

| What you want | Control |
|---|---|
| Float / tile the active window | **Super+T** (Omarchy default, unchanged) |
| Minimize (send to scratchpad) | Title-bar **–**, or **Super+M** |
| Show / hide the scratchpad | Bar **S**, or **Super+S** |
| Restore last scratchpad window to its workspace | **Super+Shift+M** |
| List scratchpad windows | `omawin-minimize list` |
| Restore a specific window | `omawin-minimize restore 0xADDRESS` |
| Maximize / restore (not fullscreen) | Title-bar **□**, or double-click the bar |
| Close | Title-bar **×** |
| Move | Drag the title bar |

On most keyboards Super is the Windows-logo key.

**Note:** Super+Shift+M was Omarchy **Music** (Spotify). The installer unbinds that default. Super+Shift+Alt+M remains Music TUI.

Minimize uses the same workspace as Omarchy’s scratchpad (`special:scratchpad`). Super+Alt+S still moves a window there without the omawin restore stack. The bar **S** is the [omarchy-scratchpad](https://github.com/nlboris/omarchy-scratchpad) widget: full opacity when the scratchpad has windows, dimmed when empty; a click is Super+S.

## Theme colors

Bar background comes from the theme `background`. Title text comes from `foreground`. The close × uses the theme accent / Hyprland active border.

`omarchy theme set` already reloads Hyprland. The `theme-set` hook then rewrites `~/.config/hypr/titlebar-colors.lua` from `~/.local/state/omarchy/current/theme/` and reloads again so hyprbars picks up the new colors.

## Client-side decorations

Apps that draw their own header (Chromium/Brave, Nautilus, some GTK/Qt apps) may still show that header **in addition to** hyprbars. The compositor cannot remove CSD. Prefer Super+T float on terminals and other SSD apps if a double header bothers you.

## Update

```bash
cd ~/dev/omawin
git pull --ff-only   # if this directory is a git checkout
./setup.sh
```

A `post-update` hook runs `hyprpm update` after `omarchy update` so hyprbars is rebuilt for a new Hyprland. If a plugin fails to load after an update, run that in a terminal (sudo may be required):

```bash
hyprpm update
hyprpm reload -n
```

Then log out and back in.

## Remove

```bash
cd ~/dev/omawin
./uninstall.sh
```

This removes only omawin files and marked config blocks. It disables hyprbars if this installer enabled it. The hyprland-plugins repository is left in place in case another plugin uses it.

## Test

1. Open a terminal.
2. Press **Super+T**. The window floats and shows a ~24px themed title bar with **– □ ×**.
3. Drag the title bar to move.
4. Double-click the title bar to maximize (not fullscreen); double-click again to restore.
5. Click **□** for the same maximize/restore.
6. Click **–** (or press Super+M). The window disappears to the scratchpad and the bar **S** lights up.
7. Click **S** (or press Super+S) to show the scratchpad; click **S** again to hide it. **Super+Shift+M** restores the last window to its original workspace. `omawin-minimize list` shows anything still on the scratchpad.
8. Click **×** to close.
9. Super+T again: tiled, no title bar.
10. Super+T still floats/tiles. Super+Ctrl+T is still Activity.
11. `omarchy theme set` another theme: bar and × colors update.

## Files

| Path | Role |
|---|---|
| `~/.config/hypr/titlebar.lua` | hyprbars config, buttons, floating-only rule, keybinds |
| `~/.config/hypr/titlebar-colors.lua` | generated theme colors |
| `~/.config/hypr/hyprland.lua` | marked `require("hypr.titlebar")` |
| `~/.config/hypr/autostart.lua` | marked `hyprpm reload -n` |
| `~/.local/bin/omawin-minimize` | hide / restore / list / toggle |
| `~/.config/omarchy/plugins/rob.scratchpad/` | bar **S** occupancy indicator |
| `~/.local/bin/omawin-theme-colors` | rewrite titlebar colors from the current theme |
| `~/.config/omarchy/hooks/theme-set.d/omawin-titlebar` | theme-set rewrite + reload |
| `~/.config/omarchy/hooks/post-update.d/omawin-hyprbars-update` | rebuild plugin after Omarchy updates |
