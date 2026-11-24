//! Public regression checks for the native Cursor deployment command.

use std::fs;
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};

/// Create fresh skill sources, a target checkout and unrelated user content.
/// Parameters: label - independent fixture identifier.
/// Returns: isolated root, source prompts and projects parent.
fn fixture(label: &str) -> (PathBuf, PathBuf, PathBuf) {
    let root = std::env::temp_dir().join(format!(
        "cursor native-世界-{label}-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&root).unwrap();
    let prompts = root.join("programming_prompts");
    for relative in [
        "skills/general-programming-guidelines",
        "plugins/commit-guidelines/skills/commit",
    ] {
        let directory = prompts.join(relative);
        fs::create_dir_all(&directory).unwrap();
        fs::write(directory.join("SKILL.md"), "# Fixture instructions\n").unwrap();
    }
    let projects = root.join("projects");
    let project = projects.join("demo");
    fs::create_dir_all(project.join(".cursor/skills/my-own")).unwrap();
    fs::write(project.join(".cursor/skills/my-own/SKILL.md"), "keep me\n").unwrap();
    fs::write(project.join(".gitignore"), ".log/\n").unwrap();
    (root, prompts, projects)
}

/// Invoke the shipped command with complete project/source selectors.
/// Parameters: action - operation; projects - projects parent; prompts - skill source; repos - space/comma-separated names.
/// Returns: captured native output and status.
fn run(action: &str, projects: &Path, prompts: &Path, repos: &str) -> Output {
    Command::new(env!("CARGO_BIN_EXE_cursor-skills"))
        .args([
            action,
            "--projects-dir",
            projects.to_str().unwrap(),
            "--prompts-dir",
            prompts.to_str().unwrap(),
            "--repos",
            repos,
        ])
        .output()
        .unwrap()
}

/// Read deployed state using the public detect command.
/// Parameters: projects - projects parent; prompts - source; expected - independently required status text/code.
/// Returns: None.
fn observe(projects: &Path, prompts: &Path, expected: (&str, i32)) {
    let result = run("detect", projects, prompts, "demo");
    assert_eq!(String::from_utf8(result.stdout).unwrap(), expected.0);
    assert_eq!(result.status.code(), Some(expected.1));
}

#[test]
/// Install twice, assert original rule bytes and uninstall only managed assets.
/// Parameters: none.
/// Returns: None.
fn deployment_and_detection_round_trip_preserve_user_assets() {
    let (root, prompts, projects) = fixture("roundtrip");
    observe(&projects, &prompts, ("absent\n", 1));
    let project = projects.join("demo");
    let managed = project.join(".cursor/skills/programming-prompts");
    for _ in 0..2 {
        let installed = run("install", &projects, &prompts, "demo,missing");
        assert_eq!(installed.status.code(), Some(0), "{:?}", installed);
        assert!(installed.stdout.is_empty());
        observe(&projects, &prompts, ("installed\n", 0));
        for (name, relative) in [
            (
                "general-programming-guidelines",
                "skills/general-programming-guidelines",
            ),
            ("commit", "plugins/commit-guidelines/skills/commit"),
        ] {
            assert_eq!(
                fs::read_link(managed.join(name)).unwrap(),
                prompts.join(relative)
            );
        }
        assert_eq!(
            fs::read_to_string(project.join(".cursor/rules/programming-prompts-always-on.mdc"))
                .unwrap(),
            include_str!("fixtures/cursor-rule.mdc")
        );
        assert_eq!(
            fs::read_to_string(project.join(".cursor/skills/my-own/SKILL.md")).unwrap(),
            "keep me\n"
        );
        let ignore = fs::read_to_string(project.join(".gitignore")).unwrap();
        assert!(ignore.starts_with(".log/\n\n# BEGIN programming-prompts-cursor"));
        assert_eq!(
            ignore.matches("# BEGIN programming-prompts-cursor").count(),
            1
        );
        assert!(!ignore.lines().any(|line| line == ".cursor/skills/"));
    }
    for _ in 0..2 {
        let removed = run("uninstall", &projects, &prompts, "demo missing");
        assert_eq!(removed.status.code(), Some(0));
        assert!(removed.stdout.is_empty());
        observe(&projects, &prompts, ("absent\n", 1));
        assert!(!managed.exists());
        assert_eq!(
            fs::read_to_string(project.join(".cursor/skills/my-own/SKILL.md")).unwrap(),
            "keep me\n"
        );
        assert_eq!(
            fs::read_to_string(project.join(".gitignore")).unwrap(),
            ".log/\n"
        );
    }
    fs::remove_dir_all(root).unwrap();
}

#[test]
/// Detect a current prompt deployment without the retired guidelines link.
/// Parameters: none.
/// Returns: None.
fn detects_current_skill_layout_without_retired_guidelines() {
    eprintln!("parameters=none");
    let (root, prompts, projects) = fixture("current-skills");
    fs::rename(
        prompts.join("skills/general-programming-guidelines"),
        prompts.join("skills/workflow"),
    )
    .unwrap();
    assert!(run("install", &projects, &prompts, "demo").status.success());
    observe(&projects, &prompts, ("installed\n", 0));
    fs::remove_file(projects.join("demo/.cursor/rules/programming-prompts-always-on.mdc")).unwrap();
    observe(&projects, &prompts, ("absent\n", 1));
    fs::remove_dir_all(root).unwrap();
    eprintln!("()");
}

#[test]
/// Migrate a managed stale link and reject unrelated files without clobbering them.
/// Parameters: none.
/// Returns: None.
fn stale_links_migrate_and_unmanaged_collisions_are_preserved() {
    let (root, prompts, projects) = fixture("collision");
    assert!(run("install", &projects, &prompts, "demo").status.success());
    let link = projects.join("demo/.cursor/skills/programming-prompts/commit");
    fs::remove_file(&link).unwrap();
    symlink(root.join("old/programming_prompts/skills/commit"), &link).unwrap();
    assert!(run("install", &projects, &prompts, "demo").status.success());
    assert_eq!(
        fs::read_link(&link).unwrap(),
        prompts.join("plugins/commit-guidelines/skills/commit")
    );
    fs::remove_file(&link).unwrap();
    fs::create_dir(&link).unwrap();
    fs::write(link.join("SKILL.md"), "user owned").unwrap();
    let rejected = run("install", &projects, &prompts, "demo");
    assert_eq!(rejected.status.code(), Some(1));
    observe(&projects, &prompts, ("installed\n", 0));
    assert_eq!(
        fs::read_to_string(link.join("SKILL.md")).unwrap(),
        "user owned"
    );
    fs::remove_dir_all(&link).unwrap();
    let external = root.join("external");
    fs::create_dir(&external).unwrap();
    fs::write(external.join("SKILL.md"), "external owned").unwrap();
    symlink(&external, &link).unwrap();
    let rejected = run("install", &projects, &prompts, "demo");
    assert_eq!(rejected.status.code(), Some(1));
    observe(&projects, &prompts, ("installed\n", 0));
    assert_eq!(fs::read_link(&link).unwrap(), external);
    assert_eq!(
        fs::read_to_string(external.join("SKILL.md")).unwrap(),
        "external owned"
    );
    fs::remove_dir_all(root).unwrap();
}

#[test]
/// Reject invalid/duplicate/empty sources before modifying deployed assets.
/// Parameters: none.
/// Returns: None.
fn invalid_sources_preserve_deployed_state() {
    let (root, prompts, projects) = fixture("invalid");
    assert!(run("install", &projects, &prompts, "demo").status.success());
    let rule = projects.join("demo/.cursor/rules/programming-prompts-always-on.mdc");
    let before = fs::read(&rule).unwrap();
    for relative in ["skills/Bad_Name", "plugins/duplicate/skills/commit"] {
        let invalid = prompts.join(relative);
        fs::create_dir_all(&invalid).unwrap();
        fs::write(invalid.join("SKILL.md"), "bad").unwrap();
        let rejected = run("install", &projects, &prompts, "demo");
        assert_eq!(rejected.status.code(), Some(1));
        observe(&projects, &prompts, ("installed\n", 0));
        assert_eq!(fs::read(&rule).unwrap(), before);
        fs::remove_dir_all(invalid).unwrap();
    }
    let empty = root.join("empty-prompts");
    fs::create_dir(&empty).unwrap();
    let rejected = run("install", &projects, &empty, "demo");
    assert_eq!(rejected.status.code(), Some(1));
    observe(&projects, &prompts, ("installed\n", 0));
    assert_eq!(fs::read(&rule).unwrap(), before);
    fs::remove_dir_all(root).unwrap();
}

#[test]
/// Parse CLI flags once and reject missing/extra/unknown shapes without mutation.
/// Parameters: none.
/// Returns: None.
fn rejected_argument_shapes_leave_existing_assets_intact() {
    let (root, prompts, projects) = fixture("arguments");
    assert!(run("install", &projects, &prompts, "demo").status.success());
    let rule = projects.join("demo/.cursor/rules/programming-prompts-always-on.mdc");
    let before = fs::read(&rule).unwrap();
    let project_flag = format!("--projects-dir={}", projects.display());
    let prompt_flag = format!("--prompts-dir={}", prompts.display());
    for args in [
        vec![],
        vec!["unknown"],
        vec!["detect", "--repos", "demo"],
        vec!["detect", &project_flag],
        vec!["install", &project_flag, "--repos", "demo"],
        vec!["detect", &project_flag, "--repos", "demo", "extra"],
        vec!["detect", &project_flag, "--repos", "demo", "--unknown"],
    ] {
        let rejected = Command::new(env!("CARGO_BIN_EXE_cursor-skills"))
            .args(args)
            .output()
            .unwrap();
        assert_eq!(rejected.status.code(), Some(2));
        observe(&projects, &prompts, ("installed\n", 0));
        assert_eq!(fs::read(&rule).unwrap(), before);
    }
    let accepted = Command::new(env!("CARGO_BIN_EXE_cursor-skills"))
        .args(["install", &project_flag, &prompt_flag, "--repos=demo"])
        .output()
        .unwrap();
    assert_eq!(accepted.status.code(), Some(0));
    observe(&projects, &prompts, ("installed\n", 0));
    fs::remove_dir_all(root).unwrap();
}

#[test]
/// Report absence until an existing checkout contains a managed skill and rule.
/// Parameters: none.
/// Returns: None.
fn absent_projects_and_empty_skill_deployments_report_absent() {
    eprintln!("parameters=none");
    let (root, prompts, projects) = fixture("missing");
    assert_eq!(
        run("install", &projects, &prompts, "missing").status.code(),
        Some(1)
    );
    let absent = run("detect", &projects, &prompts, "missing");
    assert_eq!(absent.status.code(), Some(1));
    assert_eq!(absent.stdout, b"absent\n");
    fs::remove_dir_all(prompts.join("skills/general-programming-guidelines")).unwrap();
    assert_eq!(
        run("install", &projects, &prompts, "demo").status.code(),
        Some(0)
    );
    observe(&projects, &prompts, ("installed\n", 0));
    fs::remove_file(projects.join("demo/.cursor/skills/programming-prompts/commit")).unwrap();
    observe(&projects, &prompts, ("absent\n", 1));
    fs::remove_dir_all(root).unwrap();
    eprintln!("()");
}
