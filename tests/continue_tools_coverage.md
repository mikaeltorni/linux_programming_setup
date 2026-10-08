# Continue native inline helper checks

Runner: `cargo test --offline --locked --release --test continue_tools_cli`.

| Rule | Executable expected result |
| --- | --- |
| YAML/env replacement and repeated invocation | `yaml_and_env_replacement_preserve_original_text_contract`: exact independent strings, unrelated text retained, twice silent success. |
| Native profile pipeline fields | `profile_fields_match_native_owner_json`: exact Unicode description/tab/key/newline; malformed/missing/wrong-type JSON status one without output. |
| Selected model resource lookup | `model_detection_is_read_only_and_selection_aware`: two silent successes; missing weight, deselection/empty/bad catalog fail; catalog/weight bytes unchanged immediately. |
| Empty/unknown/missing/extra raw tokens per operation | `invalid_shapes_and_missing_resources_preserve_populated_state`: status two, immediate selected-model query and original YAML bytes; missing YAML path status one preserves populated state. |
| Installer bridge and source parser integration | `tests/test_continue_native_shell.sh`: Python trap; repeated real configuration matches original file hashes; model owner's native source parser feeds the public custom installer, with only download/service installer stubbed; exact persisted key/source and captured model arguments; standalone detection works without installer runner. |

Paths/keys are text; no numeric conversion/range applies. Existing shell key
validation remains its single owner. Helpers replace only existing literal
template placeholders, mirroring original inline code. Each mutable test owns
fresh temp state; no downloads, service restarts or GUI calls. LM Studio source
parsing remains owned by its native `lmstudio-models` CLI.
