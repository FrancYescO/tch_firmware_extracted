#!/bin/sh
# Copyright (c) 2014 Technicolor
# MMPBX integration for firewall3

. $IPKG_INSTROOT/lib/functions.sh

local MMPBX_CHAIN=MMPBX

iptables -t filter -N ${MMPBX_CHAIN} 2>/dev/null
iptables -t nat -N ${MMPBX_CHAIN} 2>/dev/null
ip6tables -t filter -N ${MMPBX_CHAIN} 2>/dev/null

create_jump() {
  local network_name="$1"
  local interface
  local zone

  config_get interface "$network_name" interface "wan"

  zone=$(fw3 -q network "$interface")
  [ -z "$zone" ] && return

  # Create the ipv4 chain used by MMPBX and hook it in the correct zone
  iptables -t filter -I zone_${zone}_input -j ${MMPBX_CHAIN} 2>/dev/null
  iptables -t nat -I zone_${zone}_prerouting -j ${MMPBX_CHAIN} 2>/dev/null
  # Create the ipv6 chain used by MMPBX and hook it in the correct zone
  ip6tables -t filter -I zone_${zone}_input -j ${MMPBX_CHAIN} 2>/dev/null
}

config_load "mmpbxrvsipnet"
config_foreach create_jump network
