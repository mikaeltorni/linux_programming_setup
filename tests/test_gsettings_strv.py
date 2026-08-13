"""Installer contract: gsettings updates go through the Rust helper."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_shell_helper_uses_rust_parser():
    helpers = (ROOT / "lib" / "gsettings_helpers.sh").read_text(encoding="utf-8")
    assert "lps_bin" in helpers
    assert "gsettings_strv.py" not in helpers
    assert "python3" not in helpers
    assert (ROOT / "src" / "gsettings_strv.rs").is_file()
    assert (ROOT / "scripts" / "build_lps_tools.sh").is_file()
