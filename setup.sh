#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
HYPRLAND_CONFIG="$HYPR_DIR/hyprland.lua"
AUTOSTART_CONFIG="$HYPR_DIR/autostart.lua"
OVERLAY="$HYPR_DIR/titlebar.lua"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omawin"
PACKAGED_OVERLAY="$PROJECT_DIR/config/titlebar.lua"
EDITOR="$PROJECT_DIR/lib/edit_config.py"
HYPRPM_STATUS="$PROJECT_DIR/lib/hyprpm_status.py"
PLUGIN_REPO="https://github.com/hyprwm/hyprland-plugins"
LOADER_BEGIN="-- BEGIN omawin-titlebar"
LOADER_END="-- END omawin-titlebar"
AUTOSTART_BEGIN="-- BEGIN omawin-titlebar plugin reload"
AUTOSTART_END="-- END omawin-titlebar plugin reload"
LOADER='require("hypr.titlebar")'
RELOAD='o.exec_on_start("hyprpm reload -n && hyprctl reload")'
LOCAL_BIN="${HOME}/.local/bin"
ASSUME_YES=false
HYPRBARS_READY=false

if [[ "${1:-}" == "--yes" ]]; then
  ASSUME_YES=true
elif [[ $# -gt 0 ]]; then
  printf 'Unknown option: %s\n' "$1" >&2
  printf 'Run %s with no options, or use --yes.\n' "$0" >&2
  exit 2
fi

fail() {
  printf '\nSetup stopped: %s\n' "$1" >&2
  exit 1
}

timestamp() {
  date +%s
}

backup_file() {
  local path=$1
  [[ -f "$path" ]] || return 0
  cp -p "$path" "${path}.bak.$(timestamp)"
}

has_exact_line() {
  local path=$1
  local expected=$2
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$expected" ]] && return 0
  done < "$path"
  return 1
}

for command_name in python3 hyprpm hyprctl omarchy; do
  command -v "$command_name" >/dev/null 2>&1 || fail "the '$command_name' command is missing."
done

[[ -f "$HYPRLAND_CONFIG" ]] || fail "could not find $HYPRLAND_CONFIG."
[[ -f "$AUTOSTART_CONFIG" ]] || fail "could not find $AUTOSTART_CONFIG."
[[ -f "$PACKAGED_OVERLAY" ]] || fail "the package is incomplete: config/titlebar.lua is missing."
[[ -f "$PROJECT_DIR/config/scratchpad/Scratchpad.qml" ]] || fail "the package is incomplete: config/scratchpad/Scratchpad.qml is missing."

printf '%s\n' 'omawin titlebar will:'
printf '%s\n' '  • install the official Hyprland hyprbars plugin (hyprpm)'
printf '%s\n' '  • add a Windows-style min / max / close title bar on floating windows'
printf '%s\n' '  • leave tiled windows without title bars'
printf '%s\n' '  • keep Super+T as Omarchy float/tile'
printf '%s\n' '  • send the title-bar – / Super+M to the Omarchy scratchpad'
printf '%s\n' '  • put an S on the bar (click = Super+S) when the scratchpad has windows'
printf '%s\n' '  • bind Super+Shift+M to restore the last scratchpad window'
printf '%s\n' '  • follow Omarchy theme colors via a theme-set hook'
printf '\n%s\n' 'Note: Super+Shift+M is currently Music (Spotify). It will be unbound.'
printf '%s\n' 'hyprpm needs sudo once to create /var/cache/hyprpm/$USER.'
printf '%s\n' 'meson and ninja are required to build hyprbars if they are not already installed.'

if [[ "$ASSUME_YES" != true ]]; then
  printf '\nInstall omawin titlebar now? [y/N] '
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || { printf 'Cancelled.\n'; exit 0; }
fi

mkdir -p "$HYPR_DIR" "$STATE_DIR" "$LOCAL_BIN"

install_build_deps() {
  local missing=()
  command -v meson >/dev/null 2>&1 || missing+=(meson)
  command -v ninja >/dev/null 2>&1 || missing+=(ninja)
  ((${#missing[@]})) || return 0
  printf '\nInstalling build dependencies: %s\n' "${missing[*]}"
  if omarchy pkg add "${missing[@]}"; then
    return 0
  fi
  printf '%s\n' "Could not install ${missing[*]} (sudo password required in a terminal)."
  printf '%s\n' "Run: omarchy pkg add ${missing[*]}"
  return 1
}

hyprpm_can_run() {
  if hyprpm list >/dev/null 2>&1; then
    return 0
  fi
  if sudo -n true >/dev/null 2>&1; then
    return 0
  fi
  # Interactive terminals can prompt for sudo; --yes/non-TTY agent runs cannot.
  if [[ "$ASSUME_YES" != true && -t 0 && -t 2 ]]; then
    return 0
  fi
  return 1
}

install_hyprbars() {
  if ! hyprpm_can_run; then
    printf '\n%s\n' 'hyprpm needs sudo once to create /var/cache/hyprpm. Skipping plugin build in this non-interactive session.'
    return 1
  fi

  install_build_deps || return 1

  local list
  list=$(hyprpm list 2>/dev/null || true)
  if [[ "$list" != *"Repository hyprland-plugins"* ]]; then
    printf '\nInstalling the official Hyprland plugin collection…\n'
    if ! hyprpm add "$PLUGIN_REPO"; then
      printf '%s\n' 'hyprpm add failed. Run this installer in a terminal so sudo can prompt.'
      return 1
    fi
    : > "$STATE_DIR/repository.added"
    list=$(hyprpm list 2>/dev/null || true)
  fi

  # Record ownership before ensure enables the plugin, so uninstall does not
  # disable a hyprbars the user had already turned on.
  local enabled
  enabled=$(printf '%s\n' "$list" | python3 "$HYPRPM_STATUS")
  if [[ "$enabled" != "true" ]]; then
    : > "$STATE_DIR/hyprbars.enabled"
  fi

  printf '\nLoading hyprbars and checking that Hyprland attached it…\n'
  if ! "$PROJECT_DIR/lib/ensure-hyprbars.sh"; then
    return 1
  fi
  HYPRBARS_READY=true
}

install_scratchpad_indicator() {
  local plugins_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins"
  local shell_json="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
  local overlay="$PROJECT_DIR/config/scratchpad/Scratchpad.qml"
  local id="rob.scratchpad"
  local url="https://github.com/nlboris/omarchy-scratchpad"
  local after="omarchy.workspaces"
  local attempt

  command -v omarchy >/dev/null 2>&1 || return 1
  [[ -f "$overlay" ]] || return 1

  if [[ ! -e "$plugins_dir/$id" ]]; then
    printf '\nInstalling the Omarchy scratchpad bar indicator…\n'
    if omarchy plugin add "$url" --yes; then
      : > "$STATE_DIR/scratchpad.plugin.added"
    else
      printf '%s\n' "Could not add $url"
      printf '%s\n' "Run: omarchy plugin add $url --enable"
      return 1
    fi
  fi

  # Upstream calls hyprctl dispatch_lua_expression, which this Hyprland does not
  # have. Overlay the toggle so a click is Super+S (hyprctl dispatch).
  install -m 644 "$overlay" "$plugins_dir/$id/Scratchpad.qml"
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || omarchy restart shell >/dev/null 2>&1 || true

  if [[ -f "$shell_json" ]] && grep -q '"luke.workspaces"' "$shell_json"; then
    after="luke.workspaces"
  fi

  for ((attempt = 0; attempt < 40; attempt++)); do
    if omarchy plugin list --json 2>/dev/null | python3 -c 'import json, sys; ids=[x.get("id") for x in json.load(sys.stdin)]; sys.exit(0 if sys.argv[1] in ids else 1)' "$id"; then
      break
    fi
    sleep 0.05
  done

  if omarchy plugin enable "$id" --section left --after "$after"; then
    return 0
  fi
  omarchy restart shell >/dev/null 2>&1 || true
  sleep 1
  if omarchy plugin enable "$id" --section left --after "$after"; then
    return 0
  fi
  omarchy plugin enable "$id" --section left
}

install_hyprbars || printf '%s\n' 'Continuing with user config; hyprbars can be enabled later.'
install_scratchpad_indicator || printf '%s\n' 'Continuing without the scratchpad bar S; add it later with: omarchy plugin add https://github.com/nlboris/omarchy-scratchpad --enable'

if [[ ! -e "$STATE_DIR/overlay.backup" && ! -e "$STATE_DIR/overlay.created" ]]; then
  if [[ -e "$OVERLAY" ]]; then
    cp -p "$OVERLAY" "$STATE_DIR/overlay.backup"
  else
    : > "$STATE_DIR/overlay.created"
  fi
fi

backup_file "$HYPRLAND_CONFIG"
backup_file "$AUTOSTART_CONFIG"
if [[ -f "$OVERLAY" ]]; then
  backup_file "$OVERLAY"
fi

cp "$PACKAGED_OVERLAY" "$OVERLAY"

install -m 755 "$PROJECT_DIR/lib/omawin-minimize" "$LOCAL_BIN/omawin-minimize"
install -m 755 "$PROJECT_DIR/lib/omawin-theme-colors" "$LOCAL_BIN/omawin-theme-colors"
install -m 755 "$PROJECT_DIR/lib/ensure-hyprbars.sh" "$LOCAL_BIN/omawin-ensure-hyprbars"
mkdir -p "${HOME}/.local/lib/omawin"
install -m 644 "$PROJECT_DIR/lib/hyprbars_abi.py" "${HOME}/.local/lib/omawin/hyprbars_abi.py"
install -m 644 "$PROJECT_DIR/lib/hyprpm_status.py" "${HOME}/.local/lib/omawin/hyprpm_status.py"
"$LOCAL_BIN/omawin-theme-colors"

if ! has_exact_line "$HYPRLAND_CONFIG" "$LOADER"; then
  python3 "$EDITOR" add "$HYPRLAND_CONFIG" "$LOADER_BEGIN" "$LOADER_END" "$LOADER"
  : > "$STATE_DIR/loader.added"
fi

if ! has_exact_line "$AUTOSTART_CONFIG" "$RELOAD"; then
  python3 "$EDITOR" add "$AUTOSTART_CONFIG" "$AUTOSTART_BEGIN" "$AUTOSTART_END" "$RELOAD"
  : > "$STATE_DIR/autostart.added"
fi

omarchy hook install theme-set "$PROJECT_DIR/hooks/omawin-titlebar"
omarchy hook install post-update "$PROJECT_DIR/hooks/omawin-hyprbars-update"

hyprctl reload >/dev/null 2>&1 || true

printf '\n%s\n' '✓ omawin titlebar files are installed.'
printf '%s\n' '  Super+T still toggles float/tile (unchanged).'
printf '%s\n' '  Title-bar – / Super+M send the active window to special:scratchpad.'
printf '%s\n' '  Bar S (or Super+S) toggles the scratchpad back into view.'
printf '%s\n' '  Super+Shift+M restores the last scratchpad window to its workspace.'
printf '%s\n' '  Note: Super+Shift+M was previously bound to Music (Spotify).'

if [[ "$HYPRBARS_READY" != true ]]; then
  printf '\n%s\n' 'hyprbars is not loaded yet. In a terminal, run:'
  printf '%s\n' '  omarchy pkg add meson ninja'
  printf '%s\n' '  hyprpm add https://github.com/hyprwm/hyprland-plugins'
  printf '%s\n' '  hyprpm enable hyprbars'
  printf '%s\n' '  hyprpm reload -n'
  printf '%s\n' 'Or run: ~/.local/bin/omawin-ensure-hyprbars'
  printf '%s\n' 'That checks hyprctl plugin list and rebuilds stale plugin headers.'
else
  printf '\n%s\n' 'hyprbars is loaded in this session. Super+T floats a window and shows the title bar.'
fi

printf '\n%s\n' 'hyprctl configerrors:'
hyprctl configerrors || true
