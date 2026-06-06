#!/usr/bin/env python3
"""Tests for Continue and LM Studio autocomplete configuration."""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent.parent


def test_configure_continue_installs_editor_config_and_model_profile():
    """Programming setup should own both Continue config and its model profile."""
    with tempfile.TemporaryDirectory() as td:
        home = Path(td) / "home"
        home.mkdir()
        proc = subprocess.run(
            [
                "bash",
                "-c",
                "\n".join(
                    [
                        "set -euo pipefail",
                        f"TARGET_HOME={str(home)!r}",
                        f"CONFIG_DIR={str(ROOT_DIR / 'configs')!r}",
                        "msg() { :; }",
                        "run_as_target() { \"$@\"; }",
                        "source lib/continue_setup.sh",
                        "configure_continue",
                        'test -f "$TARGET_HOME/.continue/config.yaml"',
                        'test -f "$TARGET_HOME/.config/linux-programming-setup/lmstudio/autocomplete.env"',
                        "grep -F 'model: qwen2.5-coder-1.5b-instruct' \"$TARGET_HOME/.continue/config.yaml\"",
                        "grep -F 'LMSTUDIO_AUTOCOMPLETE_CONTEXT=\"8192\"' "
                        '"$TARGET_HOME/.config/linux-programming-setup/lmstudio/autocomplete.env"',
                    ]
                ),
            ],
            cwd=ROOT_DIR,
            text=True,
            capture_output=True,
            check=False,
        )
        assert proc.returncode == 0, proc.stderr


def test_installer_runs_continue_configuration():
    """The main installer should deploy Continue and autocomplete settings."""
    source = (ROOT_DIR / "install.sh").read_text(encoding="utf-8")

    assert 'source "$SCRIPT_DIR/lib/continue_setup.sh"' in source
    assert "configure_continue" in source


def test_continue_context_matches_lmstudio_profile():
    """Continue must not request more context than its loaded LM Studio model."""
    config = (ROOT_DIR / "configs/continue/config.yaml").read_text(encoding="utf-8")
    profile = (ROOT_DIR / "configs/lmstudio/autocomplete.env").read_text(encoding="utf-8")

    assert "contextLength: 8192" in config
    assert 'LMSTUDIO_AUTOCOMPLETE_CONTEXT="8192"' in profile
