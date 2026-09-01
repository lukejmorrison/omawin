#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
HYPRLAND_CONFIG="$HYPR_DIR/hyprland.lua"
AUTOSTART_CONFIG="$HYPR_DIR/autostart.lua"
OVERLAY="$HYPR_DIR/titlebar.lua"
COLORS="$HYPR_DIR/titlebar-colors.lua"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omawin"
PACKAGED_OVERLAY="$PROJECT_DIR/config/titlebar.lua"
EDITOR="$PROJECT_DIR/lib/edit_config.py"
LOADER_BEGIN="-- BEGIN omawin-titlebar"
LOADER_END="-- END omawin-titlebar"
AUTOSTART_BEGIN="-- BEGIN omawin-titlebar plugin reload"
AUTOSTART_END="-- END omawin-titlebar plugin reload"
LOCAL_BIN="${HOME}/.local/bin"
HOOKS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/hooks"
ASSUME_YES=false

if [[ "${1:-}" == "--yes" ]]; then
  ASSUME_YES=true
elif [[ $# -gt 0 ]]; then
  printf 'Unknown option: %s\n' "$1" >&2
  printf 'Run %s with no options, or use --yes.\n' "$0" >&2
  exit 2
fi

if [[ "$ASSUME_YES" != true ]]; then
  printf '%s\n' 'This removes omawin titlebar files and restores marked Hyprland blocks.'
  printf 'Remove omawin titlebar now? [y/N] '
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || { printf 'Cancelled.\n'; exit 0; }
fi

timestamp() {
  date +%s
}

backup_file() {
  local path=$1
  [[ -f "$path" ]] || return 0
  cp -p "$path" "${path}.bak.$(timestamp)"
}

KNOWN_STATE_FILES=(
  loader.added
  autostart.added
  overlay.backup
  overlay.created
  hyprbars.enabled
  repository.added
  scratchpad.plugin.added
)
INSTALL_STATE_FOUND=false
for state_file in "${KNOWN_STATE_FILES[@]}"; do
  if [[ -e "$STATE_DIR/$state_file" ]]; then
    INSTALL_STATE_FOUND=true
    break
  fi
done

if [[ "$INSTALL_STATE_FOUND" != true && ! -f "$OVERLAY" ]]; then
  rmdir "$STATE_DIR" >/dev/null 2>&1 || true
  printf '\n%s\n' 'omawin titlebar is not installed; nothing was changed.'
  exit 0
fi

if [[ -f "$HYPRLAND_CONFIG" ]]; then
  backup_file "$HYPRLAND_CONFIG"
  python3 "$EDITOR" remove "$HYPRLAND_CONFIG" "$LOADER_BEGIN" "$LOADER_END"
fi

if [[ -f "$AUTOSTART_CONFIG" ]]; then
  backup_file "$AUTOSTART_CONFIG"
  python3 "$EDITOR" remove "$AUTOSTART_CONFIG" "$AUTOSTART_BEGIN" "$AUTOSTART_END"
fi

if [[ -f "$STATE_DIR/overlay.backup" ]]; then
  backup_file "$OVERLAY"
  cp -p "$STATE_DIR/overlay.backup" "$OVERLAY"
elif [[ -e "$STATE_DIR/overlay.created" && -f "$OVERLAY" ]]; then
  backup_file "$OVERLAY"
  if cmp -s "$OVERLAY" "$PACKAGED_OVERLAY"; then
    rm -f "$OVERLAY"
  else
    printf '%s\n' "Kept $OVERLAY because it was changed after installation."
  fi
elif [[ -f "$OVERLAY" ]]; then
  backup_file "$OVERLAY"
  rm -f "$OVERLAY"
fi

rm -f "$COLORS"
rm -f "$LOCAL_BIN/omawin-minimize" "$LOCAL_BIN/omawin-theme-colors"
rm -f "$HOOKS_DIR/theme-set.d/omawin-titlebar"
rm -f "$HOOKS_DIR/post-update.d/omawin-hyprbars-update"

if [[ -e "$STATE_DIR/hyprbars.enabled" ]] && command -v hyprpm >/dev/null 2>&1; then
  hyprpm disable hyprbars >/dev/null 2>&1 || true
fi

if [[ -e "$STATE_DIR/scratchpad.plugin.added" ]] && command -v omarchy >/dev/null 2>&1; then
  omarchy plugin remove rob.scratchpad --yes >/dev/null 2>&1 || true
fi

for state_file in "${KNOWN_STATE_FILES[@]}"; do
  rm -f "$STATE_DIR/$state_file"
done
rm -f "$STATE_DIR/minimized.stack"
if ! rmdir "$STATE_DIR" >/dev/null 2>&1; then
  printf '%s\n' "Kept $STATE_DIR because it contains files not created by this installer."
fi

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi

printf '\n%s\n' '✓ omawin titlebar has been removed.'
printf '%s\n' 'Super+Shift+M returns to Omarchy Music after reload.'
printf '%s\n' 'The shared hyprland-plugins repository was left installed.'
