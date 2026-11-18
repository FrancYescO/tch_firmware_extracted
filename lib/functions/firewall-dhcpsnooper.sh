#!/bin/sh
# Copyright (c) 2016 Technicolor
# dhcpsnooper integration for firewall3

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/usr/share/libubox/jshn.sh

config_load "dhcpsnooping"

# check if service is enabled
local enable
config_get_bool enable global enable 1
if [ "$enable" -eq 0 ]; then
    # remove chains and rules created previously by this script
    iptables -t mangle -F dhcpsnooping 2>/dev/null
    iptables -t mangle -D FORWARD -p udp --dport 67 -j dhcpsnooping 2>/dev/null
    iptables -t mangle -X dhcpsnooping 2>/dev/null
    return 0
fi

iptables -t mangle -N dhcpsnooping 2>/dev/null
iptables -t mangle -C FORWARD -p udp --dport 67 -j dhcpsnooping 2>/dev/null ||
    iptables -t mangle -A FORWARD -p udp --dport 67 -j dhcpsnooping

local oldrules=$(iptables -t mangle -S dhcpsnooping | grep '^-A' | wc -l)
local queue
config_get queue global queue 0

create_queue_rule() {
    local iface=$1
    local enable

    # ignore disabled sections
    config_get_bool enable "$iface" enable "1"
    [ "$enable" -gt 0 ] || return 0
    
    # retrieve the Linux interface name
    local l3dev
    local UBUS_OUTPUT=$(ubus call network.interface."$iface" status)
    json_load "$UBUS_OUTPUT" || return 0
    json_get_var l3dev l3_device
    [ -n "$l3dev" ] || return 0

    # pass bridged traffic through the iptables hooks
    echo 1 > /sys/devices/virtual/net/$l3dev/bridge/nf_call_iptables || return 0

    iptables -t mangle -A dhcpsnooping -i "$l3dev" -o "$l3dev" -j NFQUEUE --queue-num "$queue"
}

config_foreach create_queue_rule interface

# remove old rules from dhcpsnooping chain
while [ $oldrules -gt 0 ]; do
    iptables -t mangle -D dhcpsnooping 1
    oldrules=$((oldrules-1))
done

