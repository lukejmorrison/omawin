#!/usr/bin/env python3
"""Checks for the hyprbars ABI and plugin-list parsers."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from hyprbars_abi import (  # noqa: E402
    abi_from_versions,
    header_abi,
    plugin_loaded,
    running_abi,
    strip_patch,
)

HEADER = """\
#define GIT_COMMIT_HASH    "efb50993780079460b0cbed1363e2166a2de1d9f"
#define AQUAMARINE_VERSION "0.15.0"
#define HYPRLANG_VERSION     "0.6.8"
#define HYPRUTILS_VERSION    "0.14.2"
#define HYPRCURSOR_VERSION   "0.1.13"
#define HYPRGRAPHICS_VERSION "0.5.1"
"""

RUNNING = """\
Hyprland 0.56.2
Version ABI string: efb50993780079460b0cbed1363e2166a2de1d9f_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6
no flags were set
"""

LOADED = """\
Plugin hyprbars by Vaxry:
\tHandle: 562cd9aa9220
\tVersion: 1.0
\tDescription: A plugin to add title bars to windows.
"""


class HyprbarsAbiTest(unittest.TestCase):
    def test_strip_patch_matches_hyprland(self) -> None:
        self.assertEqual(strip_patch("0.15.0"), "0.15")
        self.assertEqual(strip_patch("0.1.13"), "0.1")
        self.assertEqual(strip_patch("1"), "1")

    def test_header_matches_running_abi(self) -> None:
        self.assertEqual(header_abi(HEADER), running_abi(RUNNING))

    def test_old_aquamarine_headers_differ(self) -> None:
        stale = HEADER.replace('"0.15.0"', '"0.14.0"')
        self.assertEqual(
            header_abi(stale),
            abi_from_versions(
                "efb50993780079460b0cbed1363e2166a2de1d9f",
                "0.14.0",
                "0.14.2",
                "0.5.1",
                "0.1.13",
                "0.6.8",
            ),
        )
        self.assertNotEqual(header_abi(stale), running_abi(RUNNING))

    def test_incomplete_header(self) -> None:
        self.assertIsNone(header_abi("#define GIT_COMMIT_HASH \"abc\"\n"))

    def test_running_abi_ignores_ansi(self) -> None:
        colored = "\x1b[32mVersion ABI string: abc_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6\x1b[0m\n"
        self.assertEqual(
            running_abi(colored),
            "abc_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6",
        )

    def test_plugin_list_requires_hyprctl_shape(self) -> None:
        self.assertTrue(plugin_loaded(LOADED))
        self.assertFalse(plugin_loaded(""))
        self.assertFalse(plugin_loaded("Plugin hyprfocus by Someone:\n"))
        # hyprpm list uses a tree row. That is not a loaded plugin.
        self.assertFalse(plugin_loaded("  │ Plugin hyprbars\n  └─ enabled: true\n"))

    def test_description_mention_is_not_enough(self) -> None:
        text = "Plugin hyprfocus by Someone:\n\tDescription: does not include hyprbars\n"
        self.assertFalse(plugin_loaded(text))


if __name__ == "__main__":
    unittest.main()
