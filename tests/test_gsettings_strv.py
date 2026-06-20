"""Tests for gsettings string-array helpers used by programming setup."""

from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "lib" / "gsettings_strv.py"


def load_module():
    spec = importlib.util.spec_from_file_location("programming_gsettings_strv", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_append_strv_handles_gsettings_prefix_and_deduplicates():
    mod = load_module()

    assert mod.append_strv("@as ['cursor.desktop']", "cursor.desktop") == ["cursor.desktop"]
    assert mod.append_strv("@as ['cursor.desktop']", "code.desktop") == ["cursor.desktop", "code.desktop"]


def test_append_strv_handles_invalid_existing_values():
    mod = load_module()

    assert mod.append_strv("not an array", "cursor.desktop") == ["cursor.desktop"]


def test_cli_formats_updated_array_from_current_environment(monkeypatch):
    monkeypatch.setenv("CURRENT", "@as ['one']")

    completed = subprocess.run(
        [sys.executable, str(MODULE_PATH), "two"],
        check=True,
        text=True,
        capture_output=True,
    )

    assert completed.stdout.strip() == "['one', 'two']"


def test_shell_helper_uses_extracted_parser():
    helpers = (ROOT / "lib" / "gsettings_helpers.sh").read_text(encoding="utf-8")

    assert "gsettings_strv.py" in helpers
    assert "python3 - <<'PY'" not in helpers
