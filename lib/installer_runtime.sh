#!/usr/bin/env bash
# installer_runtime.sh — Installer output logging and reboot policy.
#
# Components:
#   - run_and_log_with_reboot(args...): Run main_inner with repository-local
#     logging, then apply the configured reboot policy.
#
# Sourced after lib/helpers.sh. Depends on: msg and main_inner.
# Requires variable: SCRIPT_DIR.

# run_and_log_with_reboot — Tee installer output to a timestamped log under the
# repository-local .log/ directory, then reboot unless reboots are suppressed.
# Reboots are skipped when either ISC_NO_REBOOT=1 or INSTALLER_NO_REBOOT=1 is
# set. The master orchestrator runs every child installer with
# INSTALLER_NO_REBOOT=1 so only it reboots once at the end; honoring that
# variable here keeps this installer from rebooting the machine mid-sequence and
# killing the repositories the orchestrator runs after it.
# Arguments: $@ — forwarded to main_inner.
# Returns: the main installer status on failure; does not return when a reboot
# is triggered; 0 otherwise.
run_and_log_with_reboot() {
  local ts log_dir log_file
  ts=$(date +"%Y%m%d-%H%M%S")
  log_dir="$SCRIPT_DIR/.log"
  mkdir -p "$log_dir"
  log_file="$log_dir/linux_programming_setup-$ts.log"

  if [[ $# -eq 0 && -t 0 && -t 1 ]]; then
    # A tee pipeline makes stdout cease to be a TTY, causing component_main to
    # skip its standalone submenu and install defaults immediately. Keep the
    # interactive path attached to the terminal; lib/helpers.sh still records
    # structured repository logs for actions taken after selection.
    main_inner
    msg "All done. Interactive output remained attached to the terminal."
  else
    main_inner "$@" 2>&1 | tee "$log_file"
    msg "All done. Log file written to: $log_file"
  fi

  if [[ "${ISC_NO_REBOOT:-0}" == "1" || "${INSTALLER_NO_REBOOT:-0}" == "1" ]]; then
    msg "Skipping reboot due to ISC_NO_REBOOT/INSTALLER_NO_REBOOT"
  elif [ "$(id -u)" -ne 0 ]; then
    msg "Done. Log out and back in for changes to take effect (reboot skipped in user mode)."
  else
    msg "Rebooting now in 10 seconds. Press Ctrl+C to cancel."
    sleep 10
    reboot
  fi
}
