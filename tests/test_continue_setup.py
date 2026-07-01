#!/usr/bin/env python3
"""Tests for Continue and LM Studio autocomplete configuration."""

from __future__ import annotations

import json
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
                        "log() { :; }",
                        "run_as_target() { \"$@\"; }",
                        "source lib/continue_setup.sh",
                        "configure_continue",
                        'test -f "$TARGET_HOME/.continue/config.yaml"',
                        'test -f "$TARGET_HOME/.config/linux-programming-setup/lmstudio/autocomplete.env"',
                        "grep -F 'model: vibethinker-1.5b' \"$TARGET_HOME/.continue/config.yaml\"",
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
    components = (ROOT_DIR / "installer/components.sh").read_text(encoding="utf-8")

    assert 'source "$SCRIPT_DIR/lib/continue_setup.sh"' in source
    assert (
        "continue|Continue AI assistant config (default: continue/config.yaml)|on|"
        "configure_continue|detect_continue|uninstall_continue|Programming tools|cursor"
        in components
    )


def test_continue_config_name_is_resolved_inside_configs():
    """A custom config name should be optional, relative, and traversal-safe."""
    with tempfile.TemporaryDirectory() as td:
        config_dir = Path(td) / "configs"
        (config_dir / "continue").mkdir(parents=True)
        (config_dir / "continue/config.yaml").write_text("default\n", encoding="utf-8")
        (config_dir / "alternate.yaml").write_text("alternate\n", encoding="utf-8")
        script = "\n".join(
            [
                "set -euo pipefail",
                f"CONFIG_DIR={str(config_dir)!r}",
                "log() { :; }",
                "source lib/continue_setup.sh",
                "resolve_continue_config_file </dev/null",
            ]
        )
        default = subprocess.run(
            ["bash", "-c", script], cwd=ROOT_DIR, text=True, capture_output=True
        )
        assert default.returncode == 0, default.stderr
        assert default.stdout.strip() == str(config_dir / "continue/config.yaml")

        custom = subprocess.run(
            ["bash", "-c", script],
            cwd=ROOT_DIR,
            env={"PATH": "/usr/bin:/bin", "CONTINUE_CONFIG_NAME": "alternate.yaml"},
            text=True,
            capture_output=True,
        )
        assert custom.returncode == 0, custom.stderr
        assert custom.stdout.strip() == str(config_dir / "alternate.yaml")

        rejected = subprocess.run(
            ["bash", "-c", script],
            cwd=ROOT_DIR,
            env={"PATH": "/usr/bin:/bin", "CONTINUE_CONFIG_NAME": "../outside.yaml"},
            text=True,
            capture_output=True,
        )
        assert rejected.returncode != 0


def test_vibethinker_model_install_is_separate_optional_component():
    """The LM Studio vibethinker download should be selectable separately."""
    components = (ROOT_DIR / "installer" / "components.sh").read_text(encoding="utf-8")
    continue_source = (ROOT_DIR / "lib" / "continue_setup.sh").read_text(encoding="utf-8")

    assert "continue_vibethinker_model|Continue VibeThinker autocomplete model|on|" in components
    assert 'LMSTUDIO_ADD_MODELS="vibethinker"' in continue_source
    assert "--select lm_studio_app,serve,models" in continue_source
    configure_body = continue_source.split("configure_continue()", 1)[1].split("}", 1)[0]
    assert "ensure_lmstudio_vibethinker" not in configure_body


def test_vibethinker_detection_requires_selected_downloaded_weight():
    """A shipped catalog row alone must not make the model look installed."""
    with tempfile.TemporaryDirectory() as td:
        home = Path(td)
        catalog = (
            home
            / ".config/lmstudio-local-agents/configs/lmstudio/model-profiles.json"
        )
        catalog.parent.mkdir(parents=True)
        catalog.write_text(
            json.dumps({
                "profiles": [{
                    "id": "vibethinker",
                    "default_install": True,
                    "model_path": "owner/model.gguf",
                }]
            }),
            encoding="utf-8",
        )
        script = "\n".join(
            [
                f"TARGET_HOME={str(home)!r}",
                "source lib/continue_setup.sh",
                "detect_continue_vibethinker_model",
            ]
        )
        missing = subprocess.run(
            ["bash", "-c", script],
            cwd=ROOT_DIR,
            text=True,
            capture_output=True,
            check=False,
        )
        assert missing.returncode != 0

        weight = home / ".lmstudio/models/owner/model.gguf"
        weight.parent.mkdir(parents=True)
        weight.touch()
        present = subprocess.run(
            ["bash", "-c", script],
            cwd=ROOT_DIR,
            text=True,
            capture_output=True,
            check=False,
        )
        assert present.returncode == 0, present.stderr


def test_model_components_are_the_first_models_section():
    """Autocomplete model choices should be grouped before programming tools."""
    components = (ROOT_DIR / "installer" / "components.sh").read_text(encoding="utf-8")
    rows = [
        line.strip().strip('"')
        for line in components.splitlines()
        if line.strip().startswith('"')
    ]

    assert rows[0].startswith("continue_vibethinker_model|")
    assert rows[0].endswith("|Models")
    assert rows[1].startswith("continue_custom_model|")
    assert rows[1].split("|")[6] == "Models"
    assert all("|Models" not in row for row in rows[2:])


def test_continue_model_key_can_be_overridden_without_switch_environment_variable():
    """A custom autocomplete key should update both deployed Continue assets."""
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
                        "TARGET_USER=$USER",
                        'CONTINUE_AUTOCOMPLETE_MODEL_KEY="custom-autocomplete"',
                        "msg() { :; }",
                        "log() { :; }",
                        'run_as_target() { "$@"; }',
                        "source lib/continue_setup.sh",
                        "configure_continue",
                    ]
                ),
            ],
            cwd=ROOT_DIR,
            text=True,
            capture_output=True,
            check=False,
        )

        assert proc.returncode == 0, proc.stderr
        assert "model: custom-autocomplete" in (
            home / ".continue/config.yaml"
        ).read_text(encoding="utf-8")
        profile = (
            home / ".config/linux-programming-setup/lmstudio/autocomplete.env"
        ).read_text(encoding="utf-8")
        assert 'LMSTUDIO_AUTOCOMPLETE_LOAD_MODEL="custom-autocomplete"' in profile


def test_custom_autocomplete_component_delegates_url_without_switch_variable():
    """The custom row should persist the override and add a switch-free keep-on model."""
    with tempfile.TemporaryDirectory() as td:
        home = Path(td) / "home"
        repo = home / "projects/linux_lmstudio_local_agents"
        repo.mkdir(parents=True)
        installer = repo / "install.sh"
        installer.write_text(
            "#!/usr/bin/env bash\n"
            "printf '%s\\n' \"$LMSTUDIO_CUSTOM_MODEL_URL\" \"$LMSTUDIO_CUSTOM_MODEL_SWITCH_ENV_VAR\" \"$LMSTUDIO_CUSTOM_MODEL_ROLE\" > \"$TARGET_HOME/captured-model-env\"\n",
            encoding="utf-8",
        )
        installer.chmod(0o755)
        proc = subprocess.run(
            [
                "bash",
                "-c",
                "\n".join(
                    [
                        "set -euo pipefail",
                        f"TARGET_HOME={str(home)!r}",
                        f"CONFIG_DIR={str(ROOT_DIR / 'configs')!r}",
                        "TARGET_USER=$USER",
                        'CONTINUE_AUTOCOMPLETE_MODEL_NAME="Custom Complete"',
                        'CONTINUE_AUTOCOMPLETE_MODEL_KEY="custom-complete"',
                        'CONTINUE_AUTOCOMPLETE_MODEL_URL="https://example.com/custom.gguf"',
                        "msg() { :; }",
                        "log() { :; }",
                        'run_as_target() { "$@"; }',
                        "_isc_mark_installed() { :; }",
                        "source lib/continue_setup.sh",
                        "install_custom_continue_autocomplete_model",
                    ]
                ),
            ],
            cwd=ROOT_DIR,
            text=True,
            capture_output=True,
            check=False,
        )

        assert proc.returncode == 0, proc.stderr
        assert (home / "captured-model-env").read_text(encoding="utf-8").splitlines() == [
            "https://example.com/custom.gguf",
            "",
            "keep-on",
        ]
        assert (
            home / ".config/linux-programming-setup/continue-autocomplete-model"
        ).read_text(encoding="utf-8").strip() == "custom-complete"


def test_custom_autocomplete_rejects_invalid_model_key_without_terminal():
    """Unsafe YAML/model keys should fail before delegating any installation."""
    with tempfile.TemporaryDirectory() as td:
        proc = subprocess.run(
            [
                "bash",
                "-c",
                "\n".join(
                    [
                        "set -euo pipefail",
                        f"TARGET_HOME={str(Path(td))!r}",
                        f"CONFIG_DIR={str(ROOT_DIR / 'configs')!r}",
                        "TARGET_USER=$USER",
                        "CONTINUE_AUTOCOMPLETE_MODEL_KEY=$'bad\\nmodel'",
                        'CONTINUE_AUTOCOMPLETE_MODEL_URL="https://example.com/model.gguf"',
                        "msg() { :; }",
                        "log() { :; }",
                        'run_as_target() { "$@"; }',
                        "source lib/continue_setup.sh",
                        "install_custom_continue_autocomplete_model",
                    ]
                ),
            ],
            cwd=ROOT_DIR,
            stdin=subprocess.DEVNULL,
            text=True,
            capture_output=True,
            check=False,
        )

        assert proc.returncode != 0
        assert "valid model key" in proc.stderr


def test_continue_context_matches_lmstudio_profile():
    """Continue must not request more context than its loaded LM Studio model."""
    config = (ROOT_DIR / "configs/continue/config.yaml").read_text(encoding="utf-8")
    profile = (ROOT_DIR / "configs/lmstudio/autocomplete.env").read_text(encoding="utf-8")

    assert "contextLength: 8192" in config
    assert 'LMSTUDIO_AUTOCOMPLETE_CONTEXT="8192"' in profile


def test_custom_autocomplete_accepts_the_shared_single_source_field():
    """The custom row should use the LM owner parser and one source prompt."""
    source = (ROOT_DIR / "lib" / "continue_setup.sh").read_text(encoding="utf-8")
    assert "CONTINUE_AUTOCOMPLETE_MODEL_SOURCE" in source
    assert "profile-from-source" in source
    assert "LMSTUDIO_CUSTOM_MODEL_SOURCE" in source
    assert "Hugging Face URL or owner/model@quant" in source
    assert "INSTALLER_AUTH=1 ensure_linked_repository" in source
    listing = subprocess.run(
        ["bash", str(ROOT_DIR / "install.sh"), "--list-configurable-components"],
        capture_output=True, text=True, check=False,
    )
    assert listing.returncode == 0, listing.stderr
    assert listing.stdout.splitlines() == ["continue_custom_model"]
