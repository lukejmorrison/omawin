#!/usr/bin/env python3
"""Read `hyprpm list` and report whether hyprbars itself is enabled."""

from __future__ import annotations

import re
import sys

ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def hyprbars_enabled(output: str) -> bool:
    lines = [ANSI.sub("", line).strip() for line in output.splitlines()]
    in_hyprbars = False

    for line in lines:
        if "Plugin hyprbars" in line:
            in_hyprbars = True
            continue
        if in_hyprbars and ("Plugin " in line or line.startswith("Repository ")):
            return False
        if in_hyprbars and "enabled:" in line:
            return line.endswith("enabled: true")

    return False


if __name__ == "__main__":
    print("true" if hyprbars_enabled(sys.stdin.read()) else "false")
