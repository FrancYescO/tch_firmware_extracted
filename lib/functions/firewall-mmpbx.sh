#!/bin/sh
# Copyright (c) 2014 Technicolor
# MMPBX integration for firewall3

. $IPKG_INSTROOT/lib/functions.sh

local MMPBX_CHAIN=MMPBX
local WAN_UDP_PORTS= WAN_TCP_PORTS=

iptables -t nat -N "${MMPBX_CHAIN}" 2>/dev/null
iptables -t filter -N "${MMPBX_CHAIN}" 2>/dev/null
ip6tables -t filter -N "${MMPBX_CHAIN}" 2>/dev/null

create_jump() {
  local network_name="$1"
  local interface zone local_port transport_type

  config_get interface "$network_name" interface "wan"

  zone=$(fw3 -q network "$interface")
  [ -z "$zone" ] && return 0

  config_get local_port "$network_name" local_port 5060
  config_get transport_type "$network_name" transport_type "udp"
  transport_type=$(echo "$transport_type" | awk '{print tolower($0)}')

  iptables -t nat -C "zone_${zone}_prerouting" -j "${MMPBX_CHAIN}" 2>/dev/null ||
    iptables -t nat -I "zone_${zone}_prerouting" -j "${MMPBX_CHAIN}"
  # Create the ipv4 chain used by MMPBX and hook it in the correct zone
  iptables -t filter -C "zone_${zone}_input" -j "${MMPBX_CHAIN}" 2>/dev/null ||
    iptables -t filter -I "zone_${zone}_input" -j "${MMPBX_CHAIN}"
  # Create the ipv6 chain used by MMPBX and hook it in the correct zone
  ip6tables -t filter -C "zone_${zone}_input" -j "${MMPBX_CHAIN}" 2>/dev/null ||
    ip6tables -t filter -I "zone_${zone}_input" -j "${MMPBX_CHAIN}"

  # Put exception to exclude this service from DMZ rules/port forwarding rules
  iptables -t nat -C "${MMPBX_CHAIN}" -p "$transport_type" -m "$transport_type" --dport "$local_port" -m comment --comment "DMZ_Exception_SIP" -j ACCEPT 2>/dev/null ||
    iptables -t nat -I "${MMPBX_CHAIN}" -p "$transport_type" -m "$transport_type" --dport "$local_port" -m comment --comment "DMZ_Exception_SIP" -j ACCEPT

  if [ "$zone" == "wan" ]; then
    if [ "$transport_type" == "udp" ]; then
      append WAN_UDP_PORTS $local_port
    elif [ "$transport_type" == "tcp" ]; then
      append WAN_TCP_PORTS $local_port
    fi
  fi
}

config_load "mmpbxrvsipnet"
config_foreach create_jump network

if [ -n "$WAN_UDP_PORTS" ]; then
  [ "$(uci -P /var/state -q get system.mmpbx_udp)" == "wan-service" ] ||
    uci_set_state system mmpbx_udp '' wan-service
  uci_set_state system mmpbx_udp proto udp
  uci_set_state system mmpbx_udp ports "$WAN_UDP_PORTS"
else
  uci -P /var/state -q delete system.mmpbx_udp || true
fi

if [ -n "$WAN_TCP_PORTS" ]; then
  [ "$(uci -P /var/state -q get system.mmpbx_tcp)" == "wan-service" ] ||
    uci_set_state system mmpbx_tcp '' wan-service
  uci_set_state system mmpbx_tcp proto tcp
  uci_set_state system mmpbx_tcp ports "$WAN_TCP_PORTS"
else
  uci -P /var/state -q delete system.mmpbx_tcp || true
fi

