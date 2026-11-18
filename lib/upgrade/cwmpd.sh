#!/bin/sh
disable_cwmpd() {
  if [ "$REBOOT" -eq 1 ]; then
    echo "Removing cwmpd from the watchdog"
    uci del_list watchdog.@watchdog[0].pidfile='/var/run/cwmpd.pid'
    uci del_list watchdog.@watchdog[0].pidfile='/var/run/cwmpevents.pid'
    uci commit
    /etc/init.d/watchdog-tch reload

    echo "Closing cwmpd..."
    /etc/init.d/cwmpd stop
  fi
  return 0
}
append sysupgrade_pre_upgrade disable_cwmpd
