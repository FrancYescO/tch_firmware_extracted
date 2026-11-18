#!/bin/sh
disable_voice_run_in_foreground() {
  if [ "$REBOOT" -eq 1 ]; then
    echo "Closing voice..."
    export EXTRA_COMMANDS=stop_run_in_foreground
    /etc/init.d/mmpbxd stop_run_in_foreground
  fi
  return 0
}
append sysupgrade_pre_upgrade disable_voice_run_in_foreground
