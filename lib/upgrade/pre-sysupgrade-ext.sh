#!/bin/sh
disable_app() {
        echo "Closing hostapd ..."
        /etc/init.d/hostapd stop
        sleep 2
        echo "Closing ledfw ..."
        /etc/init.d/ledfw stop
        return 0
}
append sysupgrade_pre_upgrade disable_app
