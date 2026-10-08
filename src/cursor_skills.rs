//! Cursor managed skill links, always-on rule and selective ignore deployment.

use std::collections::BTreeMap;
use std::fs;
use std::io;
use std::os::unix::fs::symlink;
use std::path::{Component, Path, PathBuf};

const START: &str = "# BEGIN programming-prompts-cursor (managed by linux_programming_setup)";
const END: &str = "# END programming-prompts-cursor";
const CATEGORY: &str = ".cursor/skills/programming-prompts";
const RULE: &str = ".cursor/rules/programming-prompts-always-on.mdc";
const USAGE: &str = "usage: cursor-skills {install|uninstall|detect} --projects-dir PATH --repos NAMES [--prompts-dir PATH]";

pub enum Operation {
    Install,
    Uninstall,
    Detect,
    Help,
}

pub struct Options {
    operation: Operation,
    projects: PathBuf,
    prompts: Option<PathBuf>,
    repos: Vec<String>,
}

/// Parse every raw command/flag and repository selector before dispatch.
/// Parameters: args - process tokens excluding executable name.
/// Returns: complete operation arguments, or usage error without filesystem effects.
pub fn parse(args: &[String]) -> Result<Options, String> {
    let mut projects = None;
    let mut prompts = None;
    let mut repos = None;
    let mut action = None;
    let mut index = 0;
    while index < args.len() {
        let token = &args[index];
        if token == "--help" || token == "-h" {
            return Ok(Options {
                operation: Operation::Help,
                projects: PathBuf::new(),
                prompts: None,
                repos: Vec::new(),
            });
        }
        if token.starts_with('-') {
            let (flag, inline) = match token.split_once('=') {
                Some((flag, value)) => (flag, Some(value)),
                None => (token.as_str(), None),
            };
            if !matches!(flag, "--projects-dir" | "--prompts-dir" | "--repos") {
                return Err(USAGE.into());
            }
            let value = if let Some(value) = inline {
                value.to_string()
            } else {
                index += 1;
                let value = args.get(index).ok_or(USAGE)?;
                if value.starts_with('-') {
                    return Err(USAGE.into());
                }
                value.clone()
            };
            match flag {
                "--projects-dir" => projects = Some(PathBuf::from(value)),
                "--prompts-dir" => prompts = Some(PathBuf::from(value)),
                _ => {
                    repos = Some(
                        value
                            .replace(',', " ")
                            .split_whitespace()
                            .map(str::to_string)
                            .collect(),
                    )
                }
            }
        } else if action.is_none() {
            action = Some(match token.as_str() {
                "install" => Operation::Install,
                "uninstall" => Operation::Uninstall,
                "detect" => Operation::Detect,
                _ => return Err(USAGE.into()),
            });
        } else {
            return Err(USAGE.into());
        }
        index += 1;
    }
    let operation = action.ok_or(USAGE)?;
    if matches!(operation, Operation::Install) && prompts.is_none() {
        return Err(USAGE.into());
    }
    Ok(Options {
        operation,
        projects: projects.ok_or(USAGE)?,
        prompts,
        repos: repos.ok_or(USAGE)?,
    })
}

/// Resolve existing ancestors and normalize absent suffixes for stale managed links.
/// Parameters: path - relative/absolute source or target path.
/// Returns: absolute normalized path, or directory lookup error.
fn resolve_path(path: &Path) -> Result<PathBuf, String> {
    let absolute = if path.is_absolute() {
        path.to_path_buf()
    } else {
        std::env::current_dir()
            .map_err(|e| e.to_string())?
            .join(path)
    };
    let mut normalized = PathBuf::new();
    for component in absolute.components() {
        match component {
            Component::ParentDir => {
                normalized.pop();
            }
            Component::CurDir => {}
            other => normalized.push(other.as_os_str()),
        }
    }
    let mut prefix = normalized.clone();
    let mut suffix = Vec::new();
    loop {
        if let Ok(mut resolved) = fs::canonicalize(&prefix) {
            for part in suffix.into_iter().rev() {
                resolved.push(part);
            }
            return Ok(resolved);
        }
        match prefix.file_name() {
            Some(name) => suffix.push(name.to_os_string()),
            None => return Ok(normalized),
        }
        prefix.pop();
    }
}

/// List sorted existing child directories for one bounded source-layout level.
/// Parameters: path - directory to scan.
/// Returns: sorted directories, an empty absent directory, or a read error.
fn child_directories(path: &Path) -> Result<Vec<PathBuf>, String> {
    let entries = match fs::read_dir(path) {
        Ok(entries) => entries,
        Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(Vec::new()),
        Err(error) => return Err(error.to_string()),
    };
    let mut directories = Vec::new();
    for entry in entries {
        let path = entry.map_err(|error| error.to_string())?.path();
        if path.is_dir() {
            directories.push(path);
        }
    }
    directories.sort();
    Ok(directories)
}

/// Validate the same lowercase/digit/hyphen skill-name grammar as the original.
/// Parameters: name - skill directory identifier.
/// Returns: whether each hyphen-separated segment is nonempty ASCII lowercase/digits.
fn valid_name(name: &str) -> bool {
    name.split('-').all(|part| {
        !part.is_empty()
            && part
                .bytes()
                .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit())
    })
}

/// Discover only direct and plugin skills, validating duplicates before deployment.
/// Parameters: prompts - authoritative prompts checkout.
/// Returns: ordered identifiers and source directories, or source validation error.
fn discover_skills(prompts: &Path) -> Result<BTreeMap<String, PathBuf>, String> {
    let prompts = resolve_path(prompts)?;
    let mut found = BTreeMap::new();
    let mut candidates = child_directories(&prompts.join("skills"))?;
    for plugin in child_directories(&prompts.join("plugins"))? {
        candidates.extend(child_directories(&plugin.join("skills"))?);
    }
    for source in candidates {
        if !source.join("SKILL.md").is_file() {
            continue;
        }
        let name = source.file_name().unwrap().to_string_lossy().to_string();
        if !valid_name(&name) {
            return Err(format!("invalid skill name: {name}"));
        }
        if found.insert(name.clone(), source).is_some() {
            return Err(format!("duplicate skill name across prompts: {name}"));
        }
    }
    if found.is_empty() {
        return Err(format!("no skills discovered under {}", prompts.display()));
    }
    Ok(found)
}

/// Link one managed skill without replacing unrelated directories or symlinks.
/// Parameters: project - existing checkout; name - validated skill identifier; source - skill directory.
/// Returns: None on successful link/reuse/migration, or a collision/filesystem error.
fn link_skill(project: &Path, name: &str, source: &Path) -> Result<(), String> {
    let source = resolve_path(source)?;
    let root = project.join(CATEGORY);
    fs::create_dir_all(&root).map_err(|error| error.to_string())?;
    let target = root.join(name);
    match fs::symlink_metadata(&target) {
        Ok(metadata) if metadata.file_type().is_symlink() => {
            let old = fs::read_link(&target).map_err(|error| error.to_string())?;
            let current = resolve_path(&root.join(old))?;
            if current == source {
                return Ok(());
            }
            if !current
                .components()
                .any(|part| part.as_os_str() == "programming_prompts")
            {
                return Err(format!(
                    "refusing to replace unmanaged skill link: {}",
                    target.display()
                ));
            }
            fs::remove_file(&target).map_err(|error| error.to_string())?;
        }
        Ok(_) => {
            return Err(format!(
                "refusing to replace unmanaged skill: {}",
                target.display()
            ))
        }
        Err(error) if error.kind() == io::ErrorKind::NotFound => {}
        Err(error) => return Err(error.to_string()),
    }
    symlink(source, target).map_err(|error| error.to_string())
}

/// Write the original always-on rule with its deterministic managed skill catalog.
/// Parameters: project - checkout; skills - sorted discovered identifiers/sources.
/// Returns: None after rule write, or a filesystem error.
fn write_rule(project: &Path, skills: &BTreeMap<String, PathBuf>) -> Result<(), String> {
    let names = skills
        .keys()
        .filter(|name| name.as_str() != "general-programming-guidelines")
        .map(|name| format!("- `{name}`"))
        .collect::<Vec<_>>();
    let catalog = if names.is_empty() {
        "- (none)".to_string()
    } else {
        names.join("\n")
    };
    let body = include_str!("cursor_rule.mdc.in").replace("{{SKILL_CATALOG}}", &catalog);
    let path = project.join(RULE);
    fs::create_dir_all(path.parent().unwrap()).map_err(|error| error.to_string())?;
    fs::write(path, body).map_err(|error| error.to_string())
}

/// Update only the managed ignore block while retaining exact outside text.
/// Parameters: project - existing checkout.
/// Returns: None after idempotent update, or a read/write error.
fn ensure_gitignore(project: &Path) -> Result<(), String> {
    let path = project.join(".gitignore");
    let current = if path.is_file() {
        fs::read_to_string(&path).map_err(|error| error.to_string())?
    } else {
        String::new()
    };
    let block = format!("{START}\n# Managed copies from programming_prompts — do not ignore other .cursor/skills/*\n{CATEGORY}/\n{RULE}\n{END}");
    let updated = if let Some((prefix, rest)) = current.split_once(START) {
        if let Some((_, suffix)) = rest.split_once(END) {
            format!("{prefix}{block}{suffix}")
        } else if current.trim().is_empty() {
            format!("{block}\n")
        } else {
            format!("{}\n\n{block}\n", current.trim_end())
        }
    } else if current.trim().is_empty() {
        format!("{block}\n")
    } else {
        format!("{}\n\n{block}\n", current.trim_end())
    };
    fs::write(path, updated).map_err(|error| error.to_string())
}

/// Deploy skill links, the original rule and its narrowly scoped ignore entries.
/// Parameters: project - target checkout; prompts - authoritative source checkout.
/// Returns: None on complete deployment, or validation/collision/filesystem error.
fn deploy_project(project: &Path, prompts: &Path) -> Result<(), String> {
    let project = resolve_path(project)?;
    let skills = discover_skills(prompts)?;
    for (name, source) in &skills {
        link_skill(&project, name, source)?;
    }
    write_rule(&project, &skills)?;
    ensure_gitignore(&project)
}

/// Remove one managed path while preserving directory symlink destinations.
/// Parameters: path - explicitly managed asset path.
/// Returns: None after removal or if absent, or a filesystem error.
fn remove_managed(path: &Path) -> Result<(), String> {
    match fs::symlink_metadata(path) {
        Ok(metadata) if metadata.is_dir() => {
            fs::remove_dir_all(path).map_err(|error| error.to_string())
        }
        Ok(_) => fs::remove_file(path).map_err(|error| error.to_string()),
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error.to_string()),
    }
}

/// Remove only the managed ignore block and preserve surrounding patterns.
/// Parameters: project - target checkout.
/// Returns: None after removal/no-op, or a filesystem error.
fn remove_gitignore(project: &Path) -> Result<(), String> {
    let path = project.join(".gitignore");
    if !path.is_file() {
        return Ok(());
    }
    let current = fs::read_to_string(&path).map_err(|error| error.to_string())?;
    let Some((prefix, rest)) = current.split_once(START) else {
        return Ok(());
    };
    let Some((_, suffix)) = rest.split_once(END) else {
        return Ok(());
    };
    let mut updated = if !prefix.trim().is_empty() || !suffix.trim().is_empty() {
        format!("{}\n{}", prefix.trim_end(), suffix.trim_start())
    } else {
        String::new()
    };
    if !updated.trim().is_empty() && !updated.ends_with('\n') {
        updated.push('\n');
    }
    fs::write(path, updated).map_err(|error| error.to_string())
}

/// Remove this component's assets without changing sibling user skills.
/// Parameters: project - checkout, possibly absent.
/// Returns: None on removal/no-op, or a filesystem error.
fn uninstall_project(project: &Path) -> Result<(), String> {
    let project = resolve_path(project)?;
    if !project.is_dir() {
        return Ok(());
    }
    remove_managed(&project.join(CATEGORY))?;
    let rule = project.join(RULE);
    if rule.is_file() || rule.is_symlink() {
        remove_managed(&rule)?;
    }
    remove_gitignore(&project)
}

/// Detect the original guidelines link/rule requirements across existing checkouts.
/// Parameters: projects - parent directory; repos - target repository names.
/// Returns: true only if at least one checkout exists and every existing one matches.
fn detect(projects: &Path, repos: &[String]) -> bool {
    let mut seen = false;
    for name in repos {
        let project = projects.join(name);
        if !project.is_dir() {
            continue;
        }
        seen = true;
        if !project
            .join(CATEGORY)
            .join("general-programming-guidelines")
            .exists()
            || !project.join(RULE).is_file()
        {
            return false;
        }
    }
    seen
}

/// Install skills into existing named checkouts and preserve the original empty result.
/// Parameters: projects - parent; prompts - source; repos - parsed repository selectors.
/// Returns: zero for any deployment, one if no checkout exists, or an operation error.
fn install(projects: &Path, prompts: &Path, repos: &[String]) -> Result<i32, String> {
    let mut count = 0;
    for name in repos {
        let project = projects.join(name);
        if !project.is_dir() {
            continue;
        }
        deploy_project(&project, prompts)?;
        count += 1;
    }
    Ok(if count > 0 { 0 } else { 1 })
}

/// Remove managed assets from every named checkout through the uninstall owner.
/// Parameters: projects - checkout parent; repos - parsed repository selectors.
/// Returns: zero after removal, or the first filesystem error.
fn uninstall(projects: &Path, repos: &[String]) -> Result<i32, String> {
    for name in repos {
        uninstall_project(&projects.join(name))?;
    }
    Ok(0)
}

/// Report the original detection label and process status.
/// Parameters: projects - checkout parent; repos - parsed repository selectors.
/// Returns: zero for installed, one for absent.
fn detect_command(projects: &Path, repos: &[String]) -> i32 {
    if detect(projects, repos) {
        println!("installed");
        0
    } else {
        println!("absent");
        1
    }
}

/// Dispatch already-parsed commands without inspecting raw CLI tokens.
/// Parameters: options - complete operation/path/repository arguments.
/// Returns: original process status or an operation error.
pub fn execute(options: Options) -> Result<i32, String> {
    match options.operation {
        Operation::Help => {
            println!("{USAGE}");
            Ok(0)
        }
        Operation::Install => install(
            &options.projects,
            options.prompts.as_deref().unwrap(),
            &options.repos,
        ),
        Operation::Uninstall => uninstall(&options.projects, &options.repos),
        Operation::Detect => Ok(detect_command(&options.projects, &options.repos)),
    }
}
