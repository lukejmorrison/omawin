#!/usr/bin/env python3
"""Add and remove clearly marked blocks without rewriting unrelated config."""

from __future__ import annotations

import argparse
from pathlib import Path


def strip_block(text: str, begin: str, end: str) -> str:
    lines = text.splitlines(keepends=True)
    result: list[str] = []
    inside = False
    for line in lines:
        marker = line.rstrip("\r\n")
        if marker == begin:
            if inside:
                raise ValueError(f"nested marker: {begin}")
            inside = True
            continue
        if marker == end:
            if not inside:
                raise ValueError(f"end marker without begin marker: {end}")
            inside = False
            continue
        if not inside:
            result.append(line)

    if inside:
        raise ValueError(f"begin marker without end marker: {begin}")

    return "".join(result)


def replace_line(text: str, old: str, new: str) -> str:
    lines = text.splitlines(keepends=True)
    replacements = 0
    updated: list[str] = []
    for line in lines:
        body = line.rstrip("\r\n")
        ending = line[len(body) :]
        if body == old:
            updated.append(new + ending)
            replacements += 1
        else:
            updated.append(line)

    if replacements != 1:
        raise ValueError(f"expected exactly one line to replace, found {replacements}")
    return "".join(updated)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("add", "remove", "replace-line"))
    parser.add_argument("path", type=Path)
    parser.add_argument("begin")
    parser.add_argument("end")
    parser.add_argument("content", nargs="?", default="")
    args = parser.parse_args()

    text = args.path.read_text()
    if args.action == "replace-line":
        args.path.write_text(replace_line(text, args.begin, args.end))
        return 0

    cleaned = strip_block(text, args.begin, args.end)

    if args.action == "add":
        block = f"{args.begin}\n{args.content.rstrip()}\n{args.end}\n"
        separator = "" if cleaned.endswith(("\n", "\r")) else "\n"
        updated = cleaned + separator + block
    else:
        updated = cleaned

    args.path.write_text(updated)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
