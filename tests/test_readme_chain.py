#!/usr/bin/env python3
"""README must not claim the obsolete 7-repo setup chain."""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]


def test_readme_does_not_claim_obsolete_chain() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    assert "7-Repo Desktop Setup Chain" not in readme
    assert re.search(r"Phase \d+", readme) is None


if __name__ == "__main__":
    tests = [t for name, t in sorted(globals().items()) if name.startswith("test_") and callable(t)]
    failed = 0
    for test_fn in tests:
        try:
            test_fn()
            print(f"  PASS: {test_fn.__name__}")
        except Exception as exc:
            failed += 1
            print(f"  FAIL: {test_fn.__name__} — {exc}")
    raise SystemExit(failed)
