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
See the full cross-repository map in
[installation_scripts/DEPENDENCIES.md](https://github.com/mikaeltorni/installation_scripts/blob/master/DEPENDENCIES.md).

## Features

- **Cursor IDE**: Downloads and installs the Cursor IDE .deb package
- **VS Code Extensions**: Installs extensions listed in `configs/vsc_cursor_extensions`
- **Continue AI**: Installs Continue config and the LM Studio autocomplete profile; the vibethinker model download is a separate default-on component
- **Autostart**: Configures Cursor IDE to launch on login
- **tmux**: Installs a shared `~/.tmux.conf` (mouse support, large scrollback, vi mode-keys)

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
| `CURSOR_EXTENSIONS_FILE` | Path to extensions list file | `$CONFIG_DIR/vsc_cursor_extensions` |
| `LMSTUDIO_USER_SERVICE_NAME` | Agent Command Center LM Studio service to restart after profile changes | `lmstudio-serve.service` |
| `CONTINUE_AUTOCOMPLETE_MODEL_KEY` | Override the model key written to Continue and its autocomplete profile | `vibethinker-1.5b` |
| `CONTINUE_AUTOCOMPLETE_MODEL_NAME` | Custom-model display name | model key |
| `CONTINUE_AUTOCOMPLETE_MODEL_URL` | GGUF URL used by the default-off custom autocomplete component | (prompted) |
| `CONTINUE_AUTOCOMPLETE_MODEL_SHA256` | Optional custom GGUF checksum | empty |

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
sudo CURSOR_EXTENSIONS_FILE=/path/to/extensions.txt bash install.sh
```

## Project Structure

```
linux_programming_setup/
├── install.sh                    # Main installer script
├── README.md                     # This file
├── LICENSE.md                    # MIT License
├── configs/
│   ├── .tmux.conf                # tmux user configuration
│   ├── vsc_cursor_extensions     # VS Code/Cursor extension IDs (one per line)
│   └── continue/
│       └── config.yaml           # Continue AI assistant configuration
│   ├── lmstudio/
│   │   └── autocomplete.env      # Continue model preload profile
│   └── uv/
│       └── uv.toml               # Global UV supply-chain config
└── lib/
    ├── apt_helpers.sh            # Root-optional APT package installation
    ├── helpers.sh                # Core utility functions and logging
    ├── gsettings_helpers.sh      # GSettings list manipulation helpers
    ├── gsettings_strv.py         # GSettings string-array parser/formatter
    ├── logging_utils.py          # Centralized Python logging helper
    ├── cursor_install.sh         # Cursor IDE installation and extensions
    ├── continue_setup.sh         # Continue config and model profile deployment
    ├── uv_supply_chain.sh        # Global UV supply-chain protection
    ├── tmux_config.sh            # tmux user configuration deployment
    └── installer_runtime.sh      # Installer logging and reboot policy
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
The menu's default-off `continue_custom_model` row prompts for a GGUF URL and
model key, delegates the download to `linux_lmstudio_local_agents`, and persists
that key as the Continue override. Autocomplete models are keep-on profiles and
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
```

In the interactive menu, **space** toggles a component, `a`/`n` select all
or none, and **Enter** installs the selection. Components:

| Component id | Description | Default |
|---|---|---|
| `continue_vibethinker_model` | Continue VibeThinker autocomplete model | on |
| `continue_custom_model` | Custom Continue autocomplete model (prompts for GGUF URL) | off |
| `cursor` | Cursor IDE | on |
| `cursor_extensions` | Cursor/VS Code extensions | on |
| `continue` | Continue AI assistant config | on |
| `uv_supply_chain` | UV supply-chain protection | on |
| `tmux` | tmux configuration | on |

Cursor login startup is controlled by `[S]` on the `cursor` application row in
the master installer, where it is grouped under **Desktop applications**. The
programming installer does not create an autostart entry independently.

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
