"""Tests for the centralized Python logging helper."""

from __future__ import annotations

import importlib.util
import logging
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "lib" / "logging_utils.py"


def load_module():
    spec = importlib.util.spec_from_file_location(
        "programming_logging_utils", MODULE_PATH
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_get_logger_creates_repo_log_sink_and_is_idempotent():
    mod = load_module()
    logger_name = "linux_programming_setup.test_logger"
    logger = logging.getLogger(logger_name)
    logger.handlers.clear()

    first = mod.get_logger(logger_name, "test-python.log")
    second = mod.get_logger(logger_name, "test-python.log")

    assert first is second
    assert len(first.handlers) == 1
    assert (ROOT / ".log").is_dir()


def test_log_call_records_bound_arguments_and_return_value(tmp_path):
    mod = load_module()
    logger_name = "linux_programming_setup.test_trace"
    logger = logging.getLogger(logger_name)
    logger.handlers.clear()
    log_path = tmp_path / "trace.log"
    handler = logging.FileHandler(log_path, encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)
    logger.setLevel(logging.DEBUG)
    logger.propagate = False

    @mod.log_call(logger)
    def sample(value: str, suffix: str = "!") -> str:
        return f"{value}{suffix}"

    assert sample("ok", suffix=".") == "ok."

    for active_handler in logger.handlers:
        active_handler.flush()
    output = log_path.read_text(encoding="utf-8")
    assert "ENTER test_logging_utils.py:" in output
    assert "value='ok'" in output
    assert "suffix='.'" in output
    assert "EXIT test_logging_utils.py:" in output
    assert "-> 'ok.'" in output
