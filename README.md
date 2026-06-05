# Linux Programming Setup

Cursor IDE installation, VS Code extension management, and Continue AI assistant configuration.

Installer run logs are written to the repository-local `.log/` directory.

## Features

- **Cursor IDE**: Downloads and installs the Cursor IDE .deb package
- **VS Code Extensions**: Installs extensions listed in `configs/vsc_cursor_extensions`
- **Continue AI**: Copies Continue config to user's home directory for Qwen 2.5 Coder with LM Studio backend
- **Autostart**: Configures Cursor IDE to launch on login

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
| `CURSOR_VERSION` | Version string for reference | `2.6.22` |
| `CURSOR_EXTENSIONS_FILE` | Path to extensions list file | `$CONFIG_DIR/vsc_cursor_extensions` |

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
│   ├── vsc_cursor_extensions     # VS Code/Cursor extension IDs (one per line)
│   └── continue/
│       └── config.yaml           # Continue AI assistant configuration
└── lib/
    ├── helpers.sh                # Core utility functions
    ├── gsettings_helpers.sh      # GSettings helper functions
    ├── cursor_install.sh         # Cursor IDE installation
    └── autostart_cursor.sh       # Cursor autostart configuration
```

## Continue AI Configuration

The `configs/continue/config.yaml` file configures the Continue VS Code/Cursor extension to use Qwen 2.5 Coder via LM Studio's local OpenAI-compatible API endpoint (`http://localhost:1234/v1`).

After installing Cursor and the Continue extension, copy this config to:
```bash
mkdir -p ~/.continue
cp configs/continue/config.yaml ~/.continue/config.yaml
```

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

## Disclaimer

This software is provided under the MIT License on an **“as is”** basis, without warranties of any kind. To the maximum extent permitted by applicable law, the authors and copyright holders shall not be liable for any claims, damages, losses, or other liability arising from the use of this software.

You are solely responsible for determining whether this software is suitable, safe, lawful, and appropriate for your intended use. Unless explicitly stated otherwise, this project is general-purpose software and is not designed, tested, certified, or approved for safety-critical, medical, automotive, aviation, industrial-control, life-support, cybersecurity-critical, financial-critical, or other high-risk use cases.

The authors and copyright holders make no guarantees regarding security, reliability, availability, correctness, compliance, non-infringement, or fitness for any particular purpose.

This notice is intended to clarify the nature of the project and does not impose additional restrictions beyond the MIT License.
