# Clean Installation Compatibility

All repository changes must remain compatible with a clean installation run
through `installation_scripts/install.sh` and this repository's `install.sh`.
Do not rely on packages, files, settings, or manual steps that exist only on
the current machine. Add every required dependency, asset, configuration
step, and migration to the installer so a fresh checkout can reproduce the
complete setup.

Keep installation steps idempotent and verify the clean-install path for every
change.

## Reloading GNOME Shell

When a change needs GNOME Shell to reload (extensions, themes, shell-side
configuration), reload it in place — never log the user out or terminate the
session.

- X11 session: run the complete command
  `xdotool key Alt+F2; sleep 1; xdotool type r; xdotool key Return`.
  This opens the GNOME run dialog, enters its internal `r` command, and submits
  it, restarting gnome-shell while preserving open windows and applications.
  Do not open Alt+F2 by itself to test or inspect the dialog; that interrupts
  the human's active work. Always run the complete sequence when a reload is
  required.
- Wayland session: there is no in-place reload. Ask the user to log out and
  back in themselves. Do NOT initiate it.

Never use any of the following to force changes through, regardless of session
type:

- `gnome-session-quit` / `--logout` / `--force`
- `loginctl terminate-session …` / `loginctl kill-user …`
- `systemctl --user stop gnome-session*` or similar unit stops
- `pkill -HUP gnome-shell`, `killall gnome-shell`, or any signal that ends the
  shell process on Wayland

Losing the user's open work is a worse outcome than waiting for them to reload
manually.
