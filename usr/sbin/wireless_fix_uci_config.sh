#!/bin/sh

# UCI fixes

need_commit=0

# 1) Make sure the wifi-iface object has a mode parameter

check_mode_parameter()
{
    iface=$1

    uci get wireless.$iface > /dev/null 2> /dev/null

    if [ "$?" = "0" ] ; then

        uci get wireless.$iface.mode > /dev/null 2> /dev/null
        if [ "$?" != "0" ] ; then
            uci set wireless.$iface.mode=ap
            need_commit=1    
        fi
    fi
}

for iface in wl0 wl0_1 wl0_2 wl0_3 wl1 wl1_1 wl1_2 wl1_3
do
    check_mode_parameter $iface
done


# Commit if needed
if [ "$need_commit" = "1" ]; then
    echo "Fixed wireless uci config" > /dev/console
    uci commit wireless
fi
