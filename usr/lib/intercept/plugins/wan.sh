#!/bin/sh

# Copyright (c) 2017 Technicolor

. "$IPKG_INSTROOT"/lib/functions.sh
. "$IPKG_INSTROOT"/lib/functions/network.sh

# For an interface in the wan list
# first check if we already decided whether a wan connection is up and skip testing that again
# then test for a default gateway on an interface
# if not yet decided wan_is_up, we test for an IPv6 default route
check_wan_intf() {
   local intf="$1"
   local inactive=0  # Do not check for inactive routes

   [ "$wan_is_up" -ne 0 ] && return  # Do not test what is already known

# Proximus network side DO NOT have the default route in vlan-20 in 3VLAN scenario
# therefore excluding the default route check
   if [ $(uci get version.@version[0].product | grep proximus) ]; then
      if network_is_up $intf; then
        wan_is_up=1 && return
      fi
   else
     local gw_ipv4=''
     network_get_gateway 'gw_ipv4' "$intf" "$inactive"
     [ -n "$gw_ipv4" ] && wan_is_up=1 && return

     local gw_ipv6=''
     network_get_gateway6 'gw_ipv6' "$intf" "$inactive"
     [ -n "$gw_ipv6" ] && wan_is_up=1
   fi
}

# search in the list of wan interfaces whether at least one has a default route
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
