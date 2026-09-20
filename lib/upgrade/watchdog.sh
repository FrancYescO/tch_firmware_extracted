#!/bin/sh
disable_watchdog() {
        /etc/init.d/watchdog-tch stop
        return 0
}
append sysupgrade_pre_upgrade disable_watchdog
