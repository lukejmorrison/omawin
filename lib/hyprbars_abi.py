#!/usr/bin/env python3
"""Compare hyprpm header ABIs with the running Hyprland and detect a loaded plugin.

hyprbars aborts in PLUGIN_INIT when the ABI string compiled into the plugin
differs from the running compositor. hyprpm can still report the plugin as
enabled. The string is the same one PluginAPI.hpp builds in
__hyprland_api_get_client_hash: the Hyprland commit plus stripPatch() of
aquamarine, hyprutils, hyprgraphics, hyprcursor, and hyprlang.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")

HEADER_KEYS = (
    "GIT_COMMIT_HASH",
    "AQUAMARINE_VERSION",
    "HYPRUTILS_VERSION",
    "HYPRGRAPHICS_VERSION",
    "HYPRCURSOR_VERSION",
    "HYPRLANG_VERSION",
)

DEFINE = re.compile(r'^\s*#define\s+([A-Z0-9_]+)\s+"([^"]*)"')


def strip_patch(version: str) -> str:
    """Drop the patch component, matching Hyprland's stripPatch lambda."""
    if "." not in version:
        return version
    return version.rsplit(".", 1)[0]


def abi_from_versions(
    commit: str,
    aquamarine: str,
    hyprutils: str,
    hyprgraphics: str,
    hyprcursor: str,
    hyprlang: str,
) -> str:
    return (
        f"{commit}"
        f"_aq_{strip_patch(aquamarine)}"
        f"_hu_{strip_patch(hyprutils)}"
        f"_hg_{strip_patch(hyprgraphics)}"
        f"_hc_{strip_patch(hyprcursor)}"
        f"_hlg_{strip_patch(hyprlang)}"
    )


def parse_header_defines(text: str) -> dict[str, str]:
    found: dict[str, str] = {}
    for line in text.splitlines():
        match = DEFINE.match(line)
        if match:
            found[match.group(1)] = match.group(2)
    return found


def header_abi(text: str) -> str | None:
    defines = parse_header_defines(text)
    if any(key not in defines for key in HEADER_KEYS):
        return None
    return abi_from_versions(*(defines[key] for key in HEADER_KEYS))


def running_abi(version_text: str) -> str | None:
    prefix = "Version ABI string:"
    for raw in version_text.splitlines():
        line = ANSI.sub("", raw).strip()
        if line.startswith(prefix):
            value = line[len(prefix) :].strip()
            return value or None
    return None


def plugin_loaded(plugin_list: str) -> bool:
    """True when `hyprctl plugin list` shows hyprbars, not merely hyprpm."""
    for raw in plugin_list.splitlines():
        line = ANSI.sub("", raw).strip()
        if re.match(r"Plugin hyprbars\b", line):
            return True
    return False


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(
            "usage: hyprbars_abi.py {plugin-loaded|running-abi|header-abi FILE}",
            file=sys.stderr,
        )
        return 2

    command = argv[1]
    if command == "plugin-loaded":
        loaded = plugin_loaded(sys.stdin.read())
        print("true" if loaded else "false")
        return 0 if loaded else 1

    if command == "running-abi":
        abi = running_abi(sys.stdin.read())
        if abi is None:
            print("omawin: hyprctl version did not include an ABI string", file=sys.stderr)
            return 1
        print(abi)
        return 0

    if command == "header-abi":
        if len(argv) != 3:
            print("usage: hyprbars_abi.py header-abi FILE", file=sys.stderr)
            return 2
        abi = header_abi(Path(argv[2]).read_text(errors="replace"))
        if abi is None:
            print(f"omawin: {argv[2]} is missing ABI version defines", file=sys.stderr)
            return 1
        print(abi)
        return 0

    print(f"unknown command: {command}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
