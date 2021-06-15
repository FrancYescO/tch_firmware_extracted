#!/bin/sh

. "$IPKG_INSTROOT/lib/functions/reboot_reason.sh"

path="/root"

# Log the reboot in console
echo "WATCHDOG REBOOT with code $1" >/dev/console

# Backup logs
logread >$path/logread_log
dmesg  >$path/dmesg_log
ps  >$path/ps_log
gzip -c $path/logread_log $path/dmesg_log $path/ps_log >$path/watchdog_$(date | tr ' ' '-').gz
rm -rf $path/logread_log $path/dmesg_log $path/ps_log

# Update reboot reason to WATCHDOG
set_reboot_reason WATCHDOG

# exit so that watchdog can now reboot
exit $1

