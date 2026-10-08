# Native Cursor deployer coverage

Runner: `cargo test --offline --locked --release --test cursor_skills_cli`.

| Rule | Public case and assertion |
| --- | --- |
| Direct/plugin discovery, spaced/comma repo selectors, missing checkout | `deployment_and_detection_round_trip_preserve_user_assets`: exact links, silent success, old CLI rule fixture, installed query, repeat runs and user asset preservation. |
| Selective/idempotent ignore block and uninstall | Same case: one managed marker, no blanket ignore, unrelated skill unchanged; twice uninstall yields absent and original `.log/` ignore bytes. |
| Stale managed links / unmanaged directory and external link | `stale_links_migrate_and_unmanaged_collisions_are_preserved`: migration points to exact source; rejected collisions immediately retain public detection and user-owned bytes/links. |
| Invalid/duplicate/empty source | `invalid_sources_preserve_deployed_state`: one rejection followed immediately by installed query and unchanged rule bytes. |
| Missing/extra/unknown tokens and required flags | `rejected_argument_shapes_leave_existing_assets_intact`: status two, immediate installed query/rule preservation; equals-form flags accepted. |
| No target / legacy guidelines absent | `absent_projects_and_missing_guidelines_keep_original_exit_codes`: install without checkouts one, absent text/one, installation without legacy guidelines zero but detector remains absent. |

Paths and names are textual; numeric conversion is inapplicable. Every case owns
fresh fixtures and removes them. Existing Python library tests remain as parity
references; product shell execution will invoke only the native CLI. The full
rule fixture is captured from the original public CLI before implementation.
