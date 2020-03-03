#!/bin/sh
disable_watchdog() {
        /etc/init.d/hostapd stop
		sleep 2
        /etc/init.d/watchdog-tch stop
        return 0
}
append sysupgrade_pre_upgrade disable_watchdog
