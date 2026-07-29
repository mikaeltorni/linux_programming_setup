#!/usr/bin/env python3
"""Tests for deploying programming_prompts skills into project .cursor trees."""

from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent.parent


def _write_skill(path: Path, name: str, body: str = "instructions") -> None:
    path.mkdir(parents=True, exist_ok=True)
    path.joinpath("SKILL.md").write_text(
        f"---\nname: {name}\ndescription: test {name}\n---\n\n# {name}\n\n{body}\n",
        encoding="utf-8",
    )


def _make_prompts(root: Path) -> Path:
    prompts = root / "programming_prompts"
    _write_skill(prompts / "skills" / "general-programming-guidelines", "general-programming-guidelines")
    _write_skill(prompts / "skills" / "init-project", "init-project")
    _write_skill(prompts / "skills" / "refactoring", "refactoring")
    _write_skill(prompts / "skills" / "setup-repository-guidelines", "setup-repository-guidelines")
    _write_skill(
        prompts / "plugins" / "commit-guidelines" / "skills" / "commit",
        "commit",
    )
    _write_skill(
        prompts / "plugins" / "linux-desktop-configuration" / "skills" / "linux-configuration",
        "linux-configuration",
    )
    return prompts


def test_discover_skills_finds_direct_and_plugin_skills() -> None:
    """Discovery must include top-level skills and one skill per plugin."""
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "cursor_skills", ROOT_DIR / "lib" / "cursor_skills.py"
    )
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    with tempfile.TemporaryDirectory() as td:
        prompts = _make_prompts(Path(td))
        found = {name: str(path) for name, path in mod.discover_skills(prompts)}
        assert set(found) == {
            "general-programming-guidelines",
            "init-project",
            "refactoring",
            "setup-repository-guidelines",
            "commit",
            "linux-configuration",
        }
        assert found["commit"].endswith("plugins/commit-guidelines/skills/commit")
        assert found["general-programming-guidelines"].endswith(
            "skills/general-programming-guidelines"
        )


def test_deploy_links_skills_writes_rule_and_selective_gitignore() -> None:
    """Deploy must symlink managed skills, write always-on rule, and gitignore only managed paths."""
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "cursor_skills", ROOT_DIR / "lib" / "cursor_skills.py"
    )
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        prompts = _make_prompts(root)
        project = root / "projects" / "demo_repo"
        project.mkdir(parents=True)
        # Project-specific skill that must remain unignored and untouched.
        custom = project / ".cursor" / "skills" / "my-local-skill"
        _write_skill(custom, "my-local-skill", "keep me")
        (project / ".gitignore").write_text(".log/\n", encoding="utf-8")

        mod.deploy_to_project(project, prompts)

        managed = project / ".cursor" / "skills" / "programming-prompts"
        link = managed / "general-programming-guidelines"
        assert link.is_symlink()
        assert link.resolve() == (
            prompts / "skills" / "general-programming-guidelines"
        ).resolve()
        assert (managed / "commit").is_symlink()
        assert custom.joinpath("SKILL.md").is_file()

        rule = project / ".cursor" / "rules" / "programming-prompts-always-on.mdc"
        assert rule.is_file()
        text = rule.read_text(encoding="utf-8")
        assert "alwaysApply: true" in text
        assert "general-programming-guidelines" in text
        assert "`disable-model-invocation`" in text or "disable-model-invocation" in text
        assert "/skill-name" in text or "`/skill-name`" in text

        ignore = (project / ".gitignore").read_text(encoding="utf-8")
        assert ".cursor/skills/programming-prompts/" in ignore
        assert ".cursor/rules/programming-prompts-always-on.mdc" in ignore
        # Must not blanket-ignore all skills.
        assert ".cursor/skills/\n" not in ignore
        assert ".cursor/\n" not in ignore

        # Re-run is idempotent.
        mod.deploy_to_project(project, prompts)
        assert link.is_symlink()


def test_deploy_refuses_unmanaged_skill_collision() -> None:
    """An existing non-managed skill directory with the managed name must not be clobbered."""
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "cursor_skills", ROOT_DIR / "lib" / "cursor_skills.py"
    )
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        prompts = _make_prompts(root)
        project = root / "projects" / "demo_repo"
        collision = (
            project / ".cursor" / "skills" / "programming-prompts" / "commit"
        )
        _write_skill(collision, "commit", "user owned")
        try:
            mod.deploy_to_project(project, prompts)
            raise AssertionError("expected ValueError for unmanaged collision")
        except ValueError as exc:
            assert "refusing" in str(exc).lower()


def test_uninstall_removes_managed_paths_only() -> None:
    """Uninstall removes managed skills/rule/gitignore block but keeps local skills."""
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "cursor_skills", ROOT_DIR / "lib" / "cursor_skills.py"
    )
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        prompts = _make_prompts(root)
        project = root / "projects" / "demo_repo"
        project.mkdir(parents=True)
        custom = project / ".cursor" / "skills" / "my-local-skill"
        _write_skill(custom, "my-local-skill")
        mod.deploy_to_project(project, prompts)
        mod.uninstall_from_project(project)

        assert not (project / ".cursor" / "skills" / "programming-prompts").exists()
        assert not (
            project / ".cursor" / "rules" / "programming-prompts-always-on.mdc"
        ).exists()
        assert custom.joinpath("SKILL.md").is_file()
        ignore = (project / ".gitignore").read_text(encoding="utf-8")
        assert "programming-prompts-cursor" not in ignore


def test_bash_component_deploys_across_listed_repos() -> None:
    """install_cursor_skills must deploy into every repo name under PROJECTS_DIR."""
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        prompts = _make_prompts(root)
        projects = root / "projects"
        for name in ("repo_a", "repo_b", "installation_scripts"):
            (projects / name).mkdir(parents=True)
            (projects / name / ".gitignore").write_text("", encoding="utf-8")

        # Point PROGRAMMING_PROMPTS_DIR at the fake prompts; PROJECTS_DIR at projects.
        # INSTALLATION_SCRIPTS_DIR unused because CURSOR_SKILLS_REPOS is set.
        env = os.environ.copy()
        env["TARGET_HOME"] = str(root / "home")
        (root / "home").mkdir()
        proc = subprocess.run(
            [
                "bash",
                "-c",
                "\n".join(
                    [
                        "set -euo pipefail",
                        f"SCRIPT_DIR={str(ROOT_DIR)!r}",
                        f"TARGET_HOME={str(root / 'home')!r}",
                        f"PROGRAMMING_PROMPTS_DIR={str(prompts)!r}",
                        f"PROJECTS_DIR={str(projects)!r}",
                        "CURSOR_SKILLS_REPOS='repo_a repo_b installation_scripts'",
                        "msg() { :; }",
                        "log() { :; }",
                        "run_as_target() { \"$@\"; }",
                        "ensure_linked_repository() { return 0; }",
                        "source \"$SCRIPT_DIR/lib/cursor_skills.sh\"",
                        "install_cursor_skills",
                        'test -L "$PROJECTS_DIR/repo_a/.cursor/skills/programming-prompts/general-programming-guidelines"',
                        'test -L "$PROJECTS_DIR/repo_b/.cursor/skills/programming-prompts/commit"',
                        'test -f "$PROJECTS_DIR/installation_scripts/.cursor/rules/programming-prompts-always-on.mdc"',
                        "detect_cursor_skills",
                    ]
                ),
            ],
            cwd=ROOT_DIR,
            text=True,
            capture_output=True,
            check=False,
            env=env,
        )
        assert proc.returncode == 0, proc.stderr + proc.stdout


def test_components_manifest_lists_cursor_skills() -> None:
    """The component menu must expose cursor_skills as a selectable row."""
    components = (ROOT_DIR / "installer" / "components.sh").read_text(encoding="utf-8")
    assert "cursor_skills|" in components
    assert "install_cursor_skills" in components
    assert "detect_cursor_skills" in components
    assert "uninstall_cursor_skills" in components
    installer = (ROOT_DIR / "install.sh").read_text(encoding="utf-8")
    assert 'source "$SCRIPT_DIR/lib/cursor_skills.sh"' in installer


def test_always_on_rule_omits_description_for_reliable_injection() -> None:
    """alwaysApply rules should avoid description so Cursor injects them every chat."""
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "cursor_skills", ROOT_DIR / "lib" / "cursor_skills.py"
    )
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        prompts = _make_prompts(root)
        project = root / "projects" / "demo"
        project.mkdir(parents=True)
        mod.deploy_to_project(project, prompts)
        front = (
            project / ".cursor" / "rules" / "programming-prompts-always-on.mdc"
        ).read_text(encoding="utf-8").split("---", 2)[1]
        data_lines = [
            line for line in front.splitlines() if line.strip() and not line.strip().startswith("#")
        ]
        # Frontmatter must set alwaysApply and must not set description
        # (Cursor has mapped alwaysApply+description to agent-requestable).
        assert any("alwaysApply: true" in line for line in data_lines)
        assert not any(line.startswith("description:") for line in data_lines)
