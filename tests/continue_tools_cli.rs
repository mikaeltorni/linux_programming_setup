//! Public checks for Continue's native inline-helper replacements.

use std::fs;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};

/// Create an isolated populated YAML, env and selected-model fixture.
/// Parameters: label - case identifier.
/// Returns: temporary directory with independent model/config state.
fn fixture(label: &str) -> PathBuf {
    let root = std::env::temp_dir().join(format!(
        "continue native-{label}-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(root.join("models/owner")).unwrap();
    fs::write(root.join("models/owner/model.gguf"), "synthetic weight").unwrap();
    fs::write(root.join("catalog.json"), r#"{"profiles":[{"id":"vibethinker","default_install":true,"model_path":"owner/model.gguf"}]}"#).unwrap();
    fs::write(
        root.join("config.yaml"),
        "name: VibeThinker 1.5B LM Studio\nmodel: vibethinker-1.5b\nother: keep\n",
    )
    .unwrap();
    fs::write(
        root.join("autocomplete.env"),
        "LMSTUDIO_AUTOCOMPLETE_LOAD_MODEL=\"vibethinker-1.5b\"\nOTHER=\"keep\"\n",
    )
    .unwrap();
    root
}

/// Invoke the actual native command with optional JSON pipeline input.
/// Parameters: args - raw command tokens; input - complete stdin document.
/// Returns: process status/output.
fn run(args: &[&str], input: &str) -> Output {
    let mut process = Command::new(env!("CARGO_BIN_EXE_continue-tools"))
        .args(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    if let Err(error) = process.stdin.take().unwrap().write_all(input.as_bytes()) {
        assert_eq!(error.kind(), std::io::ErrorKind::BrokenPipe, "{error}");
    }
    process.wait_with_output().unwrap()
}

/// Observe the fixture's populated selected-model state through the public query.
/// Parameters: root - fixture containing the catalog and model file.
/// Returns: None.
fn observe(root: &std::path::Path) {
    let result = run(
        &[
            "model-present",
            root.join("catalog.json").to_str().unwrap(),
            root.join("models").to_str().unwrap(),
        ],
        "",
    );
    assert_eq!(result.status.code(), Some(0), "{:?}", result);
    assert!(result.stdout.is_empty());
}

#[test]
/// Preserve exact original replacements, unrelated text and second-run bytes.
/// Parameters: none.
/// Returns: None.
fn yaml_and_env_replacement_preserve_original_text_contract() {
    let root = fixture("replace");
    for _ in 0..2 {
        let yaml = run(
            &[
                "yaml",
                root.join("config.yaml").to_str().unwrap(),
                "custom-model",
            ],
            "",
        );
        assert_eq!(yaml.status.code(), Some(0), "{:?}", yaml);
        assert!(yaml.stdout.is_empty());
        assert_eq!(
            fs::read_to_string(root.join("config.yaml")).unwrap(),
            "name: custom-model LM Studio\nmodel: custom-model\nother: keep\n"
        );
        let env = run(
            &[
                "env",
                root.join("autocomplete.env").to_str().unwrap(),
                "custom-model",
            ],
            "",
        );
        assert_eq!(env.status.code(), Some(0));
        assert!(env.stdout.is_empty());
        assert_eq!(
            fs::read_to_string(root.join("autocomplete.env")).unwrap(),
            "LMSTUDIO_AUTOCOMPLETE_LOAD_MODEL=\"custom-model\"\nOTHER=\"keep\"\n"
        );
    }
    fs::remove_dir_all(root).unwrap();
}

#[test]
/// Decode profile description/key into the original tab-separated pipeline output.
/// Parameters: none.
/// Returns: None.
fn profile_fields_match_native_owner_json() {
    let input =
        r#"{"description":"Custom 世界 model","model_key":"owner/custom-model","unrelated":true}"#;
    for _ in 0..2 {
        let result = run(&["profile-fields"], input);
        assert_eq!(result.status.code(), Some(0));
        assert_eq!(
            result.stdout,
            "Custom 世界 model\towner/custom-model\n".as_bytes()
        );
    }
    for input in [
        "",
        "not-json",
        "[]",
        "{}",
        r#"{"description":3,"model_key":"key"}"#,
    ] {
        let result = run(&["profile-fields"], input);
        assert_eq!(result.status.code(), Some(1));
        assert!(result.stdout.is_empty());
    }
}

#[test]
/// Require the selected catalog row and existing weight without changing either.
/// Parameters: none.
/// Returns: None.
fn model_detection_is_read_only_and_selection_aware() {
    let root = fixture("detect");
    let catalog = root.join("catalog.json");
    let before = fs::read(&catalog).unwrap();
    observe(&root);
    observe(&root);
    assert_eq!(fs::read(&catalog).unwrap(), before);
    fs::remove_file(root.join("models/owner/model.gguf")).unwrap();
    let missing = run(
        &[
            "model-present",
            catalog.to_str().unwrap(),
            root.join("models").to_str().unwrap(),
        ],
        "",
    );
    assert_eq!(missing.status.code(), Some(1));
    assert_eq!(fs::read(&catalog).unwrap(), before);
    fs::write(root.join("models/owner/model.gguf"), "synthetic weight").unwrap();
    for text in [
        r#"{"profiles":[]}"#,
        r#"{"profiles":[{"id":"vibethinker","default_install":false,"model_path":"owner/model.gguf"}]}"#,
        "not-json",
    ] {
        fs::write(&catalog, text).unwrap();
        let rejected = run(
            &[
                "model-present",
                catalog.to_str().unwrap(),
                root.join("models").to_str().unwrap(),
            ],
            "",
        );
        assert_eq!(rejected.status.code(), Some(1));
        assert_eq!(fs::read_to_string(&catalog).unwrap(), text);
        assert_eq!(
            fs::read_to_string(root.join("models/owner/model.gguf")).unwrap(),
            "synthetic weight"
        );
    }
    fs::remove_dir_all(root).unwrap();
}

#[test]
/// Reject command shapes or missing files before touching existing assets.
/// Parameters: none.
/// Returns: None.
fn invalid_shapes_and_missing_resources_preserve_populated_state() {
    let root = fixture("reject");
    let path = root.join("config.yaml");
    let file = path.to_str().unwrap();
    let before = fs::read(&path).unwrap();
    for args in [
        vec![],
        vec!["unknown"],
        vec!["yaml", file],
        vec!["yaml", file, "key", "extra"],
        vec!["env", file],
        vec!["env", file, "key", "extra"],
        vec!["profile-fields", "extra"],
        vec!["model-present", file],
        vec!["model-present", file, file, "extra"],
    ] {
        let rejected = run(&args, "{}");
        assert_eq!(rejected.status.code(), Some(2));
        observe(&root);
        assert_eq!(fs::read(&path).unwrap(), before);
    }
    let rejected = run(&["yaml", root.join("missing").to_str().unwrap(), "key"], "");
    assert_eq!(rejected.status.code(), Some(1));
    observe(&root);
    assert_eq!(fs::read(&path).unwrap(), before);
    fs::remove_dir_all(root).unwrap();
}
