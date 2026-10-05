#!/usr/bin/env bash
# Run in a real terminal. hyprpm and pacman need sudo.
set -u
echo "omawin: install official hyprbars"
echo "sudo will prompt for meson/ninja (if missing) and hyprpm's /var/cache/hyprpm."
echo

status=0
if ! command -v meson >/dev/null 2>&1 || ! command -v ninja >/dev/null 2>&1; then
  omarchy pkg add meson ninja || status=1
fi

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if (( status == 0 )); then
  if ! hyprpm list 2>/dev/null | grep -q "Repository hyprland-plugins"; then
    echo "Adding hyprwm/hyprland-plugins (first build can take several minutes)…"
    hyprpm add https://github.com/hyprwm/hyprland-plugins || status=1
  fi
fi

if (( status == 0 )); then
  "$ROOT/lib/ensure-hyprbars.sh" || status=1
fi

echo
echo "=== hyprctl plugin list ==="
hyprctl plugin list || true
echo
echo "=== hyprctl configerrors ==="
hyprctl configerrors || true
echo
if (( status == 0 )); then
  echo "hyprbars is loaded. Super+T floats a window and shows the title bar."
else
  echo "hyprbars did not finish installing. Fix the error above and re-run:"
  echo "  $0"
fi
echo "Press Enter to close."
read -r
exit "$status"
