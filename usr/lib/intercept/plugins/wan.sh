#!/bin/sh

# Copyright (c) 2017 Technicolor

. "$IPKG_INSTROOT"/lib/functions.sh
. "$IPKG_INSTROOT"/lib/functions/network.sh

# For an interface in the wan list
# first check if we already decided whether a wan connection is up and skip testing that again
# Check if the interface is up
check_wan_intf() {
   local intf="$1"

   [ "$wan_is_up" -ne 0 ] && return  # Do not test what is already known

   if network_is_up $intf; then
      wan_is_up=1 && return
   fi
}

# search in the list of wan interfaces and find the interface is up
check_all_wan_down() {
    wan_is_up=0
    config_load intercept
    config_list_foreach config wan check_wan_intf
    return "$wan_is_up"
}

case "$1" in
    ifchanged|setup)
        check_all_wan_down
        if [ "$wan_is_up" = "0" ]; then
            ubus call intercept add_reason '{"reason":"wan_down"}'
        else
            ubus call intercept del_reason '{"reason":"wan_down"}'
        fi
        exit 0
        ;;
    default)
        logger -t intercept "[$$] Invalid action \"$1\""
        exit 1
        ;;
esac
