#!/usr/bin/env bash
# Build hyprbars and require `hyprctl plugin list` to show it.
#
# hyprpm update keeps headers when the Hyprland git commit is unchanged, even
# if a dependency such as aquamarine moved. The plugin then aborts during
# PLUGIN_INIT while `hyprpm list` still says enabled. This script compares the
# header ABI with the running compositor, deletes a stale headersRoot, and
# treats a missing hyprctl entry as failure.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LIB_DIR="${HOME}/.local/lib/omawin"
if [[ -f "$SCRIPT_DIR/hyprbars_abi.py" ]]; then
  ABI_PY="$SCRIPT_DIR/hyprbars_abi.py"
else
  ABI_PY="$LIB_DIR/hyprbars_abi.py"
fi
if [[ -f "$SCRIPT_DIR/hyprpm_status.py" ]]; then
  STATUS_PY="$SCRIPT_DIR/hyprpm_status.py"
else
  STATUS_PY="$LIB_DIR/hyprpm_status.py"
fi

CHECK_ONLY=false
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=true
elif [[ $# -gt 0 ]]; then
  printf 'omawin: unknown option: %s\n' "$1" >&2
  printf 'usage: %s [--check]\n' "$0" >&2
  exit 2
fi

fail() {
  printf 'omawin: %s\n' "$1" >&2
  if [[ "$CHECK_ONLY" != true ]] && command -v omarchy-notification-send >/dev/null 2>&1; then
    omarchy-notification-send -u normal "omawin" "$1" || true
  fi
  exit 1
}

[[ -n "${USER:-}" ]] || fail "USER is not set, so the hyprpm cache path is unknown."
[[ -f "$ABI_PY" ]] || fail "missing $ABI_PY"
[[ -f "$STATUS_PY" ]] || fail "missing $STATUS_PY"
command -v hyprctl >/dev/null 2>&1 || fail "hyprctl is not installed."
command -v python3 >/dev/null 2>&1 || fail "python3 is not installed."
if [[ "$CHECK_ONLY" != true ]]; then
  command -v hyprpm >/dev/null 2>&1 || fail "hyprpm is not installed."
fi

HEADERS="/var/cache/hyprpm/${USER}/headersRoot"
HEADER_H="$HEADERS/include/hyprland/src/version.h"
case "$HEADERS" in
  /var/cache/hyprpm/*/headersRoot) ;;
  *) fail "refusing to touch unexpected header path: $HEADERS" ;;
esac

RUNNING_ABI=$(hyprctl version | python3 "$ABI_PY" running-abi) || fail "could not read the running Hyprland ABI."

headers_are_stale() {
  local header_abi
  if [[ ! -f "$HEADER_H" ]]; then
    printf 'omawin: hyprpm headers are missing (%s)\n' "$HEADER_H" >&2
    return 0
  fi
  if ! header_abi=$(python3 "$ABI_PY" header-abi "$HEADER_H"); then
    printf 'omawin: could not read an ABI from %s\n' "$HEADER_H" >&2
    return 0
  fi
  if [[ "$header_abi" != "$RUNNING_ABI" ]]; then
    printf 'omawin: header ABI %s does not match running Hyprland %s\n' "$header_abi" "$RUNNING_ABI" >&2
    return 0
  fi
  return 1
}

plugin_loaded() {
  hyprctl plugin list | python3 "$ABI_PY" plugin-loaded >/dev/null
}

if [[ "$CHECK_ONLY" == true ]]; then
  header_abi=""
  if [[ -f "$HEADER_H" ]]; then
    header_abi=$(python3 "$ABI_PY" header-abi "$HEADER_H" || true)
  fi
  printf 'running ABI: %s\n' "$RUNNING_ABI"
  if [[ -n "$header_abi" ]]; then
    printf 'header ABI:  %s\n' "$header_abi"
  else
    printf 'header ABI:  missing\n'
  fi
  if plugin_loaded; then
    printf 'hyprctl plugin list: hyprbars loaded\n'
  else
    printf 'hyprctl plugin list: hyprbars not loaded\n'
  fi
  if [[ "$header_abi" != "$RUNNING_ABI" ]] || ! plugin_loaded; then
    exit 1
  fi
  exit 0
fi

wipe_headers() {
  [[ -e "$HEADERS" ]] || return 0
  printf 'omawin: removing stale hyprpm headers at %s\n' "$HEADERS" >&2
  if [[ -w "$HEADERS" ]]; then
    rm -rf "$HEADERS"
  else
    sudo rm -rf "$HEADERS"
  fi
}

enable_if_needed() {
  local list enabled
  list=$(hyprpm list 2>/dev/null || true)
  enabled=$(printf '%s\n' "$list" | python3 "$STATUS_PY")
  if [[ "$enabled" != "true" ]]; then
    printf 'omawin: enabling hyprbars\n'
    hyprpm enable hyprbars
  fi
}

load_hyprbars() {
  local update_args=("$@")
  hyprpm update "${update_args[@]}"
  enable_if_needed
  # A failing reload still needs the plugin-list check below. hyprpm can
  # report success when the plugin aborts after dlopen.
  hyprpm reload -n || true
  hyprctl reload || true
}

if headers_are_stale; then
  wipe_headers
fi

load_hyprbars
if plugin_loaded; then
  printf 'omawin: hyprbars is loaded in this Hyprland session.\n'
  exit 0
fi

printf 'omawin: hyprbars is not in hyprctl plugin list. Rebuilding headers and trying once more.\n' >&2
wipe_headers
load_hyprbars -f
if plugin_loaded; then
  printf 'omawin: hyprbars is loaded in this Hyprland session.\n'
  exit 0
fi

fail "hyprbars did not load. hyprpm list can still say it is enabled. Run: hyprctl plugin list"
