#!/usr/bin/env python3
"""Deploy programming_prompts skills into per-project Cursor skill directories.

Cursor discovers project skills from ``.cursor/skills/`` (and nested category
folders). This module places managed skills under a dedicated category folder
``.cursor/skills/programming-prompts/<skill>/`` so they can be gitignored as a
group without ignoring project-specific skills that developers add later under
``.cursor/skills/<other-name>/``.

Skills alone are relevance-based (the agent decides when to load them). For
deterministic always-on guidelines, this module also writes
``.cursor/rules/programming-prompts-always-on.mdc`` with ``alwaysApply: true``
and no ``description`` field (Cursor docs + forum guidance: alwaysApply rules
inject every chat; pairing ``description`` has been mapped to agent-requestable
in some versions).
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from logging_utils import get_logger, log_call

LOGGER = get_logger("cursor_skills", "cursor_skills.log")

SKILL_NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
MANAGED_SKILLS_DIRNAME = "programming-prompts"
ALWAYS_ON_RULE_NAME = "programming-prompts-always-on.mdc"
GITIGNORE_START = "# BEGIN programming-prompts-cursor (managed by linux_programming_setup)"
GITIGNORE_END = "# END programming-prompts-cursor"


@log_call(LOGGER)
def discover_skills(prompts_root: Path) -> list[tuple[str, Path]]:
    """Discover direct and plugin skills under a programming_prompts checkout.

    Args:
        prompts_root: Root of the programming_prompts repository.

    Returns:
        Sorted ``(skill_name, source_directory)`` pairs. Each source directory
        must contain ``SKILL.md``.

    Raises:
        ValueError: If no skills are found or a skill name is invalid/duplicated.
    """
    prompts_root = prompts_root.resolve()
    found: dict[str, Path] = {}

    for skill_md in sorted(prompts_root.glob("skills/*/SKILL.md")):
        name = skill_md.parent.name
        if not SKILL_NAME.fullmatch(name):
            raise ValueError(f"invalid direct skill name: {name!r}")
        found[name] = skill_md.parent

    for skill_md in sorted(prompts_root.glob("plugins/*/skills/*/SKILL.md")):
        name = skill_md.parent.name
        if not SKILL_NAME.fullmatch(name):
            raise ValueError(f"invalid plugin skill name: {name!r}")
        if name in found:
            raise ValueError(f"duplicate skill name across prompts: {name!r}")
        found[name] = skill_md.parent

    if not found:
        raise ValueError(f"no skills discovered under {prompts_root}")
    LOGGER.info("Discovered %d programming_prompts skills", len(found))
    return sorted(found.items(), key=lambda item: item[0])


def _managed_skills_root(project: Path) -> Path:
    return project / ".cursor" / "skills" / MANAGED_SKILLS_DIRNAME


def _always_on_rule_path(project: Path) -> Path:
    return project / ".cursor" / "rules" / ALWAYS_ON_RULE_NAME


def _is_programming_prompts_path(path: Path) -> bool:
    return any(part == "programming_prompts" for part in path.resolve().parts)


@log_call(LOGGER)
def link_managed_skill(project: Path, skill_name: str, source: Path) -> None:
    """Symlink one managed skill into the project's programming-prompts category.

    Args:
        project: Target repository root.
        skill_name: Skill folder name (must match ``SKILL.md`` frontmatter name).
        source: Authoritative skill directory under programming_prompts.

    Raises:
        ValueError: If the source is invalid or an unmanaged target collides.
    """
    if not SKILL_NAME.fullmatch(skill_name):
        raise ValueError(f"invalid skill name: {skill_name!r}")
    source = source.resolve()
    if not source.joinpath("SKILL.md").is_file():
        raise ValueError(f"missing skill source: {source}")

    target_root = _managed_skills_root(project)
    target_root.mkdir(parents=True, exist_ok=True)
    target = target_root / skill_name

    if target.is_symlink():
        current = (target.parent / os.readlink(target)).resolve()
        if current == source:
            LOGGER.info("Skill %s already linked in %s", skill_name, project)
            return
        if _is_programming_prompts_path(current):
            LOGGER.info(
                "Migrating managed skill %s in %s from %s to %s",
                skill_name,
                project,
                current,
                source,
            )
            target.unlink()
        else:
            raise ValueError(f"refusing to replace unmanaged skill link: {target}")
    elif target.exists():
        raise ValueError(f"refusing to replace unmanaged skill: {target}")

    os.symlink(source, target, target_is_directory=True)
    LOGGER.info("Linked skill %s -> %s", target, source)


@log_call(LOGGER)
def write_always_on_rule(project: Path, skill_names: list[str]) -> None:
    """Write the alwaysApply Cursor rule that forces guidelines on every prompt.

    Args:
        project: Target repository root.
        skill_names: Managed skill names deployed beside the rule (for the catalog).
    """
    others = [name for name in skill_names if name != "general-programming-guidelines"]
    other_lines = "\n".join(f"- `{name}`" for name in others) or "- (none)"
    body = f"""---
alwaysApply: true
---

# Programming prompts (managed)

These instructions apply to **every** Agent chat in this repository. They are
installed from `programming_prompts` by `linux_programming_setup` and must not
be edited by hand.

## Mandatory on every prompt

Before any software edit, load and follow the complete skill:

`.cursor/skills/programming-prompts/general-programming-guidelines/SKILL.md`

Use `/general-programming-guidelines` when you need to re-invoke it. Do not skip
it for "small" changes.

## Other skills (auto when relevant)

Cursor discovers the remaining managed skills under
`.cursor/skills/programming-prompts/`. They have **no**
`disable-model-invocation` flag, so the agent auto-applies them when the task
matches their descriptions. Invoke with `/skill-name` to force them.

{other_lines}

Project-specific skills may live beside the managed category as
`.cursor/skills/<your-skill>/` — those are never managed or gitignored by this
installer.
"""
    path = _always_on_rule_path(project)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf-8")
    LOGGER.info("Wrote always-on Cursor rule at %s", path)


@log_call(LOGGER)
def ensure_gitignore(project: Path) -> None:
    """Ensure a managed gitignore block covers only programming-prompts Cursor assets.

    Args:
        project: Target repository root. Creates ``.gitignore`` when missing.
    """
    block = "\n".join(
        [
            GITIGNORE_START,
            "# Managed copies from programming_prompts — do not ignore other .cursor/skills/*",
            f".cursor/skills/{MANAGED_SKILLS_DIRNAME}/",
            f".cursor/rules/{ALWAYS_ON_RULE_NAME}",
            GITIGNORE_END,
        ]
    )
    gitignore = project / ".gitignore"
    current = gitignore.read_text(encoding="utf-8") if gitignore.is_file() else ""
    if GITIGNORE_START in current and GITIGNORE_END in current:
        prefix, remainder = current.split(GITIGNORE_START, 1)
        _old, suffix = remainder.split(GITIGNORE_END, 1)
        updated = f"{prefix}{block}{suffix}"
    else:
        updated = (
            f"{current.rstrip()}\n\n{block}\n" if current.strip() else f"{block}\n"
        )
    gitignore.write_text(updated, encoding="utf-8")
    LOGGER.info("Ensured managed Cursor gitignore block in %s", gitignore)


@log_call(LOGGER)
def remove_gitignore_block(project: Path) -> None:
    """Remove the managed gitignore block if present.

    Args:
        project: Target repository root.
    """
    gitignore = project / ".gitignore"
    if not gitignore.is_file():
        return
    current = gitignore.read_text(encoding="utf-8")
    if GITIGNORE_START not in current or GITIGNORE_END not in current:
        return
    prefix, remainder = current.split(GITIGNORE_START, 1)
    _old, suffix = remainder.split(GITIGNORE_END, 1)
    updated = f"{prefix.rstrip()}\n{suffix.lstrip()}" if prefix.strip() or suffix.strip() else ""
    if updated.strip():
        gitignore.write_text(updated if updated.endswith("\n") else updated + "\n", encoding="utf-8")
    else:
        gitignore.write_text("", encoding="utf-8")
    LOGGER.info("Removed managed Cursor gitignore block from %s", gitignore)


@log_call(LOGGER)
def deploy_to_project(project: Path, prompts_root: Path) -> None:
    """Deploy all discovered skills, the always-on rule, and the gitignore block.

    Args:
        project: Target repository root that must already exist.
        prompts_root: programming_prompts checkout root.
    """
    project = project.resolve()
    if not project.is_dir():
        raise ValueError(f"project directory missing: {project}")
    skills = discover_skills(prompts_root)
    for name, source in skills:
        link_managed_skill(project, name, source)
    write_always_on_rule(project, [name for name, _ in skills])
    ensure_gitignore(project)
    LOGGER.info("Deployed programming_prompts Cursor skills into %s", project)


@log_call(LOGGER)
def uninstall_from_project(project: Path) -> None:
    """Remove managed Cursor skills, always-on rule, and gitignore block.

    Args:
        project: Target repository root. Missing projects are skipped.
    """
    project = project.resolve()
    if not project.is_dir():
        LOGGER.info("Skipping missing project %s", project)
        return

    managed = _managed_skills_root(project)
    if managed.is_dir():
        # Only remove managed symlinks / empty managed tree; never walk siblings.
        for child in list(managed.iterdir()):
            if child.is_symlink() or child.is_file():
                child.unlink()
            elif child.is_dir():
                shutil.rmtree(child)
        try:
            managed.rmdir()
        except OSError:
            LOGGER.warning("Managed skills dir not empty after uninstall: %s", managed)

    rule = _always_on_rule_path(project)
    if rule.is_file() or rule.is_symlink():
        rule.unlink()

    remove_gitignore_block(project)
    LOGGER.info("Uninstalled managed Cursor skills from %s", project)


@log_call(LOGGER)
def deploy_to_projects(
    projects_dir: Path,
    prompts_root: Path,
    repo_names: list[str],
) -> int:
    """Deploy into each named repository under projects_dir.

    Args:
        projects_dir: Parent directory holding sibling checkouts.
        prompts_root: programming_prompts checkout root.
        repo_names: Repository directory names to update.

    Returns:
        Number of projects successfully deployed.
    """
    count = 0
    for name in repo_names:
        project = projects_dir / name
        if not project.is_dir():
            LOGGER.warning("Skipping missing checkout %s", project)
            continue
        deploy_to_project(project, prompts_root)
        count += 1
    LOGGER.info("Deployed Cursor skills into %d projects", count)
    return count


@log_call(LOGGER)
def uninstall_from_projects(projects_dir: Path, repo_names: list[str]) -> int:
    """Uninstall managed Cursor assets from each named repository.

    Args:
        projects_dir: Parent directory holding sibling checkouts.
        repo_names: Repository directory names to clean.

    Returns:
        Number of projects processed.
    """
    count = 0
    for name in repo_names:
        project = projects_dir / name
        uninstall_from_project(project)
        count += 1
    return count


@log_call(LOGGER)
def detect_deployed(projects_dir: Path, repo_names: list[str]) -> bool:
    """Return True when every existing checkout has the guidelines skill linked.

    Args:
        projects_dir: Parent directory holding sibling checkouts.
        repo_names: Repository directory names to inspect.

    Returns:
        True when at least one named checkout exists and every existing one has
        the managed general-programming-guidelines skill and always-on rule.
    """
    seen = False
    for name in repo_names:
        project = projects_dir / name
        if not project.is_dir():
            continue
        seen = True
        skill = (
            _managed_skills_root(project) / "general-programming-guidelines"
        )
        rule = _always_on_rule_path(project)
        if not skill.exists() or not rule.is_file():
            return False
    return seen


def _parse_repos(raw: str) -> list[str]:
    return [part for part in raw.replace(",", " ").split() if part]


def main(argv: list[str] | None = None) -> int:
    """CLI entry for install/uninstall/detect of project Cursor skills."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action",
        choices=("install", "uninstall", "detect"),
        help="install, uninstall, or detect managed Cursor skills",
    )
    parser.add_argument(
        "--projects-dir",
        type=Path,
        required=True,
        help="Directory containing sibling repository checkouts",
    )
    parser.add_argument(
        "--prompts-dir",
        type=Path,
        help="programming_prompts checkout (required for install)",
    )
    parser.add_argument(
        "--repos",
        required=True,
        help="Space- or comma-separated repository directory names",
    )
    args = parser.parse_args(argv)
    repos = _parse_repos(args.repos)
    if args.action == "install":
        if args.prompts_dir is None:
            parser.error("--prompts-dir is required for install")
        deployed = deploy_to_projects(args.projects_dir, args.prompts_dir, repos)
        return 0 if deployed else 1
    if args.action == "uninstall":
        uninstall_from_projects(args.projects_dir, repos)
        return 0
    ok = detect_deployed(args.projects_dir, repos)
    print("installed" if ok else "absent")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
