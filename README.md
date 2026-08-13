# Linux Programming Setup

> Part of [installation_scripts](https://github.com/mikaeltorni/installation_scripts) — the master installer that orchestrates a productivity-focused Ubuntu 24.04 desktop setup (workspaces, hotkeys, window tiling, programming tools, and more). Tested on Ubuntu 24.04.4 LTS.

Cursor IDE installation, VS Code extension management, and Continue AI assistant configuration.

Installer run logs are written to the repository-local `.log/` directory.

## Repository dependencies

This repository installs and runs **standalone**; sibling repositories only
enhance it and never block installation when absent.

- **Build-time (soft):** the shared installer component framework
  [`linux_installation_scripts_functions`](https://github.com/mikaeltorni/linux_installation_scripts_functions) —
  loaded from a sibling checkout when present, otherwise downloaded on demand.
- **Content (soft, cursor_skills):** [`programming_prompts`](https://github.com/mikaeltorni/programming_prompts)
  supplies the skill bodies linked into each project's `.cursor/skills/`; cloned
  on demand when the `cursor_skills` component runs and the checkout is missing.
- **Manifest (soft, cursor_skills):** [`installation_scripts`](https://github.com/mikaeltorni/installation_scripts)
  `scripts/repository_manifest.sh` lists which sibling projects receive the
  deployment (`CLONE_REPOS` plus `installation_scripts` itself).
See the full cross-repository map in
[installation_scripts/DEPENDENCIES.md](https://github.com/mikaeltorni/installation_scripts/blob/master/DEPENDENCIES.md).

## Features

- **Cursor IDE**: Downloads and installs the Cursor IDE .deb package
- **Cursor Extensions**: Installs extensions into Cursor from an optionally selected list under `configs/`
- **Cursor skills (programming_prompts)**: Links every skill from the sibling
  [`programming_prompts`](https://github.com/mikaeltorni/programming_prompts)
  repository into each setup-chain project's
  `.cursor/skills/programming-prompts/<skill>/` folder, writes an
  `alwaysApply` Cursor rule so **General Programming Guidelines** inject on
  every Agent prompt, and adds a selective `.gitignore` that covers only those
  managed paths (project-specific `.cursor/skills/<other>/` skills stay
  trackable)
- **Continue AI**: Installs an optionally selected Continue config and the LM Studio autocomplete profile; the vibethinker model download is a separate default-on component
- **Desktop integration**: Cursor can be marked as a dock favorite, startup app, and workspace-assigned app in the master menu

## Installation

```bash
# Full installation (requires sudo)
sudo bash install.sh

# Configuration-only mode (no installs, just applies settings)
sudo ISC_APPLY_HOTKEYS_ONLY=1 bash install.sh

# Skip reboot after installation
sudo ISC_NO_REBOOT=1 bash install.sh
```

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CURSOR_DEB_URL` | URL to Cursor .deb package | (required, must be set) |
| `CURSOR_EXTENSIONS_CONFIG` | Extension-list filename relative to `configs/` | `vsc_cursor_extensions` |
| `CONTINUE_CONFIG_NAME` | Continue YAML filename relative to `configs/` | `continue/config.yaml` |
| `LMSTUDIO_USER_SERVICE_NAME` | Agent Command Center LM Studio service to restart after profile changes | `lmstudio-serve.service` |
| `CONTINUE_AUTOCOMPLETE_MODEL_KEY` | Override the model key written to Continue and its autocomplete profile | `vibethinker-1.5b` |
| `CONTINUE_AUTOCOMPLETE_MODEL_NAME` | Custom-model display name | model key |
| `CONTINUE_AUTOCOMPLETE_MODEL_SOURCE` | Hugging Face repository URL or exact `owner/model@quant` source | (prompted) |
| `CONTINUE_AUTOCOMPLETE_MODEL_URL` | GGUF URL used by the default-off custom autocomplete component | (prompted) |
| `CONTINUE_AUTOCOMPLETE_MODEL_SHA256` | Optional custom GGUF checksum | empty |
| `PROGRAMMING_PROMPTS_DIR` | Checkout used as the Cursor skill source | `$TARGET_HOME/projects/programming_prompts` |
| `PROJECTS_DIR` | Sibling projects directory that receives skill links | `$TARGET_HOME/projects` |
| `INSTALLATION_SCRIPTS_DIR` | Manifest source for `CLONE_REPOS` | `$TARGET_HOME/projects/installation_scripts` |
| `CURSOR_SKILLS_REPOS` | Override the target repo list (space/comma separated) | (from `CLONE_REPOS` + `installation_scripts`) |

## Managing Extensions

### Export current extensions:
```bash
cursor --list-extensions > configs/vsc_cursor_extensions
```

### Install all extensions manually:
```bash
xargs -r -L 1 cursor --install-extension < configs/vsc_cursor_extensions
```

### Custom extensions file:
```bash
CURSOR_EXTENSIONS_CONFIG=my_extensions bash install.sh --select cursor_extensions
```

Interactive component runs show the default filename as editable text. Custom
files stay under `configs/`; absolute paths and `..` traversal are rejected.

## Project Structure

```
linux_programming_setup/
├── install.sh                    # Main installer script
├── README.md                     # This file
├── LICENSE.md                    # MIT License
├── configs/
│   ├── vsc_cursor_extensions     # VS Code/Cursor extension IDs (one per line)
│   └── continue/
│       └── config.yaml           # Continue AI assistant configuration
│   ├── lmstudio/
│   │   └── autocomplete.env      # Continue model preload profile
└── lib/
    ├── apt_helpers.sh            # Root-optional APT package installation
    ├── helpers.sh                # Core utility functions and logging
    ├── gsettings_helpers.sh      # GSettings list manipulation helpers
    ├── lps_bin.sh                # Builds/runs the Rust lps-tools GSettings helper
    ├── logging_utils.py          # Centralized Python logging helper
    ├── cursor_install.sh         # Cursor IDE installation and extensions
    ├── cursor_skills.sh          # Deploy programming_prompts into project .cursor/
    ├── cursor_skills.py          # Symlink skills, always-on rule, selective gitignore
    ├── continue_setup.sh         # Continue config and model profile deployment
    └── installer_runtime.sh      # Installer logging and reboot policy
```

## Cursor skills from programming_prompts

The `cursor_skills` component (default on) deploys the content-only
`programming_prompts` skills into every repository listed in the master
`CLONE_REPOS` manifest, plus `installation_scripts` itself:

| Path | Purpose |
|------|---------|
| `.cursor/skills/programming-prompts/<skill>/` | Symlink to the authoritative skill under `programming_prompts` (one folder per skill). Cursor walks nested skill categories, so discovery works. |
| `.cursor/rules/programming-prompts-always-on.mdc` | `alwaysApply: true` rule that forces General Programming Guidelines on every Agent chat. Skills alone are relevance-based; Cursor's always-on mechanism is rules. |
| `.gitignore` managed block | Ignores **only** the two managed paths above — never `.cursor/skills/` wholesale — so project-specific skills remain commit-able. |

Managed skills currently include: `general-programming-guidelines`, `init-project`,
`refactoring`, `setup-repository-guidelines`, `commit`, and `linux-configuration`.
None set `disable-model-invocation`, so Cursor auto-applies them when relevant;
use `/skill-name` to force one.

```bash
# Deploy (or refresh) into every setup-chain project
bash install.sh --select cursor_skills

# Verify
bash install.sh --detect | grep cursor_skills
```

## Continue AI Configuration

The `configs/continue/config.yaml` file configures the Continue VS Code/Cursor
extension to use VibeThinker 1.5B via LM Studio's local OpenAI-compatible API
endpoint (`http://localhost:1234/v1`).

The installer copies the editor configuration to `~/.continue/config.yaml` and
the model profile to
`~/.config/linux-programming-setup/lmstudio/autocomplete.env`. Agent Command
Center's shared LM Studio boot service reads that optional profile and loads
the model after the coding-agent model.

The vibethinker model download itself is not hidden inside the Continue config
component. Keep `continue_vibethinker_model` selected for the default autocomplete
model, or deselect it when no Programming-owned local model should be installed.
In either the standalone or master submenu, highlight the default-off
`continue_custom_model` row and press `→` to show its one source prompt for a
Hugging Face repository URL or `owner/model@quant`, delegates parsing and the
download to `linux_lmstudio_local_agents`, and persists the resulting model key
as the Continue override. The older explicit key/URL variables remain available
for automation. A standalone checkout clones the public
`linux_lmstudio_local_agents` dependency on first model use when it is absent.
Autocomplete models are keep-on profiles and
therefore do not require a per-model switch environment variable.

## License

MIT License — see LICENSE.md

## Part of 7-Repo Desktop Setup Chain

This repository is **Phase 5** in the desktop setup chain:

1. `linux_installations_setup` — Base packages, hardware, apps
2. `linux_configuration_setup` — GNOME desktop, autostart, GSettings
3. `linux_hotkey_setup` — GNOME hotkeys and workspace bindings
4. `agent_command_center` — Agent command center components
5. **`linux_programming_setup` (this repo)** — Cursor IDE, VS Code extensions
6. `ubuntu_2404_taskbar_system_status_monitor` — Taskbar system monitor extension
7. `phrase_automation` — Phrase automation tmux service

It is automatically cloned and run by the main installer (`installation_scripts/install.sh`).

## Component selection

This repository's `install.sh` participates in the shared installer
component menu (see the [`installation_scripts`](https://github.com/mikaeltorni/installation_scripts)
master installer). Run standalone, it offers an interactive submenu on a
terminal; the master installer drives it non-interactively.

```bash
bash install.sh                 # interactive component selection (TTY), else defaults
bash install.sh --default       # install all default-on components, no prompts
bash install.sh --all           # install every component, no prompts
bash install.sh --select a,b    # install exactly these component ids
bash install.sh --list-components  # print: id<TAB>label<TAB>default
bash install.sh --list-startup-components
                                # print Cursor [S] startup metadata
bash install.sh --list-favorite-components
                                # print Cursor [F] favorite metadata
```

In the interactive menu, **space** toggles a component, `a`/`n` select all
or none, and **Enter** installs the selection. Components:

| Component id | Description | Default |
|---|---|---|
| `continue_vibethinker_model` | Continue VibeThinker autocomplete model | on |
| `continue_custom_model` | Custom Continue autocomplete model (URL or `owner/model@quant`) | off |
| `cursor` | Cursor IDE | on |
| `cursor_extensions` | Cursor extensions (default: `vsc_cursor_extensions`; requires Cursor) | on |
| `continue` | Continue AI assistant config (default: `continue/config.yaml`; requires Cursor) | on |

Cursor favorite, login startup, and workspace assignment are controlled by the
`[F]`, `[S]`, and `[1-9]` actions on its application row in the master menu. The
programming installer does not write those desktop settings independently.

## Detect, reconfigure, and uninstall

This installer tracks what it has installed and can re-apply or remove it, so you
can refresh configuration after a repo update or cleanly back a feature out.

```bash
bash install.sh --detect            # show each component as installed|absent
bash install.sh --reconfigure a,b   # re-apply (idempotent) these component ids
bash install.sh --uninstall a,b     # uninstall these component ids
```

In the interactive menu (run `bash install.sh` on a terminal, or via the master
installer), already-installed components show a green `✓`. Select one with
**space** to **reconfigure** it (`~`), press **`u`** to mark it for **uninstall**
(`✗`), or press **`r`** to reconfigure every installed component at once. Detection
uses a live check where deterministic and otherwise an install receipt under
`${XDG_STATE_HOME:-~/.local/state}/isc/receipts/`; a component without a reversal
step simply clears that receipt on uninstall.

## Disclaimer

This software is provided under the MIT License on an **“as is”** basis, without warranties of any kind. To the maximum extent permitted by applicable law, the authors and copyright holders shall not be liable for any claims, damages, losses, or other liability arising from the use of this software.

You are solely responsible for determining whether this software is suitable, safe, lawful, and appropriate for your intended use. Unless explicitly stated otherwise, this project is general-purpose software and is not designed, tested, certified, or approved for safety-critical, medical, automotive, aviation, industrial-control, life-support, cybersecurity-critical, financial-critical, or other high-risk use cases.

The authors and copyright holders make no guarantees regarding security, reliability, availability, correctness, compliance, non-infringement, or fitness for any particular purpose.

This notice is intended to clarify the nature of the project and does not impose additional restrictions beyond the MIT License.
