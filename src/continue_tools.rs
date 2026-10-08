//! Replacement of the Continue installer's inline Python text/JSON helpers.

use serde_json::Value;
use std::fs;
use std::io::{self, Read};
use std::path::PathBuf;

const USAGE: &str = "usage: continue-tools yaml PATH KEY | env PATH KEY | profile-fields | model-present CATALOG MODELS";

pub enum Command {
    Help,
    Yaml { path: PathBuf, key: String },
    Env { path: PathBuf, key: String },
    ProfileFields,
    ModelPresent { catalog: PathBuf, models: PathBuf },
}

/// Parse all raw variants and complete operand shape before operations.
/// Parameters: args - raw process tokens excluding executable name.
/// Returns: parsed command, or usage error without reading/writing assets.
pub fn parse(args: &[String]) -> Result<Command, String> {
    match args
        .iter()
        .map(String::as_str)
        .collect::<Vec<_>>()
        .as_slice()
    {
        ["--help"] | ["-h"] => Ok(Command::Help),
        ["yaml", path, key] => Ok(Command::Yaml {
            path: (*path).into(),
            key: (*key).into(),
        }),
        ["env", path, key] => Ok(Command::Env {
            path: (*path).into(),
            key: (*key).into(),
        }),
        ["profile-fields"] => Ok(Command::ProfileFields),
        ["model-present", catalog, models] => Ok(Command::ModelPresent {
            catalog: (*catalog).into(),
            models: (*models).into(),
        }),
        _ => Err(USAGE.into()),
    }
}

/// Read UTF-8 config text with the original Path.read_text newline behavior.
/// Parameters: path - existing YAML/env file.
/// Returns: normalized text, or a file/encoding error.
fn read_config(path: &PathBuf) -> Result<String, String> {
    fs::read_to_string(path)
        .map(|text| text.replace("\r\n", "\n").replace('\r', "\n"))
        .map_err(|error| error.to_string())
}

/// Write the updated existing config and retain silent operation output.
/// Parameters: path - config file; text - updated complete contents.
/// Returns: empty output/status zero, or a write error.
fn write_config(path: &PathBuf, text: &str) -> Result<(String, i32), String> {
    fs::write(path, text).map_err(|error| error.to_string())?;
    Ok((String::new(), 0))
}

/// Replace only the two original Continue YAML template literals.
/// Parameters: path - deployed YAML; key - key already validated by the shell owner.
/// Returns: empty output/status zero or read/write error.
fn update_yaml(path: &PathBuf, key: &str) -> Result<(String, i32), String> {
    let text = read_config(path)?
        .replace(
            "name: VibeThinker 1.5B LM Studio",
            &format!("name: {key} LM Studio"),
        )
        .replace("model: vibethinker-1.5b", &format!("model: {key}"));
    write_config(path, &text)
}

/// Replace only the original LM Studio autocomplete model template literal.
/// Parameters: path - deployed env file; key - key already validated by the shell owner.
/// Returns: empty output/status zero or read/write error.
fn update_env(path: &PathBuf, key: &str) -> Result<(String, i32), String> {
    let text = read_config(path)?.replace(
        "LMSTUDIO_AUTOCOMPLETE_LOAD_MODEL=\"vibethinker-1.5b\"",
        &format!("LMSTUDIO_AUTOCOMPLETE_LOAD_MODEL=\"{key}\""),
    );
    write_config(path, &text)
}

/// Read profile JSON and format the original description/key pipeline result.
/// Parameters: none; a complete native owner profile arrives on stdin.
/// Returns: tab-separated description/key and status zero, or a JSON/shape error.
fn profile_fields() -> Result<(String, i32), String> {
    let mut text = String::new();
    io::stdin()
        .read_to_string(&mut text)
        .map_err(|_| "Cannot read model profile")?;
    let profile: Value = serde_json::from_str(&text).map_err(|_| "Invalid model profile JSON")?;
    let name = profile
        .get("description")
        .and_then(Value::as_str)
        .ok_or("Model profile needs a description")?;
    let key = profile
        .get("model_key")
        .and_then(Value::as_str)
        .ok_or("Model profile needs a model key")?;
    Ok((format!("{name}\t{key}\n"), 0))
}

/// Preserve JSON truthiness used by the original selected-profile query.
/// Parameters: value - decoded catalog field.
/// Returns: whether the field is truthy under the original query's rules.
fn truthy(value: &Value) -> bool {
    match value {
        Value::Null => false,
        Value::Bool(value) => *value,
        Value::Number(value) => value.as_f64().is_some_and(|value| value != 0.0),
        Value::String(value) => !value.is_empty(),
        Value::Array(value) => !value.is_empty(),
        Value::Object(value) => !value.is_empty(),
    }
}

/// Query the first selected VibeThinker profile and its on-disk model weight.
/// Parameters: catalog - installed model catalog; models - installed weight directory.
/// Returns: silent zero for present/selected, one for absent, unreadable or invalid state.
fn model_present(catalog: &PathBuf, models: &PathBuf) -> Result<(String, i32), String> {
    let document = fs::read_to_string(catalog)
        .ok()
        .and_then(|text| serde_json::from_str::<Value>(&text).ok());
    let profiles = document
        .as_ref()
        .and_then(|document| document.get("profiles"))
        .and_then(Value::as_array);
    if let Some(profiles) = profiles {
        for profile in profiles {
            if profile.get("id").and_then(Value::as_str) != Some("vibethinker")
                || !profile.get("default_install").is_some_and(truthy)
            {
                continue;
            }
            let path = match profile.get("model_path") {
                Some(Value::String(path)) => path.clone(),
                Some(value) if truthy(value) => value.to_string(),
                _ => String::new(),
            };
            return Ok((
                String::new(),
                if models.join(path).is_file() { 0 } else { 1 },
            ));
        }
    }
    Ok((String::new(), 1))
}

/// Dispatch parsed commands to their text/JSON/resource operation owners.
/// Parameters: command - parsed operation arguments.
/// Returns: output/status, or an operation error.
pub fn execute(command: Command) -> Result<(String, i32), String> {
    match command {
        Command::Help => Ok((format!("{USAGE}\n"), 0)),
        Command::Yaml { path, key } => update_yaml(&path, &key),
        Command::Env { path, key } => update_env(&path, &key),
        Command::ProfileFields => profile_fields(),
        Command::ModelPresent { catalog, models } => model_present(&catalog, &models),
    }
}
