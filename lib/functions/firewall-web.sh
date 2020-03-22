#!/bin/sh
# Copyright (c) 2015 Technicolor
# web integration for firewall3

. $IPKG_INSTROOT/lib/functions.sh

RESERVED_PORT=443
WAN_ACCESS_PORT=8090
INVALID_PORT=65535
dmz_enabled=0
userredirect_enabled=0
port_forwarding=0
zone="wan"
redirect_port=$RESERVED_PORT


config_load "firewall"

if [ "$zone" == "wan" ]; then
[ "$(uci -P /var/state -q get system.web)" == "wan-service" ] ||
	uci_set_state system web '' wan-service
	uci_set_state system web ports "$WAN_ACCESS_PORT"
fi

# check dmzredirect
dmzredirect_each () {
	local cfg="$1"
	local name

	config_get name "$cfg" name
	if [ "DMZ rule" = "$name" ]; then
		config_get zone "$cfg" src
	fi
}

# check userredirect
userredirect_each () {
	local cfg="$1"
	local src_dport
	local enabled

	config_get src_dport "$cfg" src_dport
	config_get enabled "$cfg" enabled
	if [ -n "$src_dport" -a "$src_dport" = "$RESERVED_PORT" ]; then
		if [ "$enabled" -eq 1 ]; then
			config_get zone "$cfg" src
			port_forwarding=1
		fi
	fi
}

#config_get dmz_enabled dmzredirects enabled 0
#config_get userredirect_enabled userredirects enabled 0
#[ "$dmz_enabled" -eq 0 ] || config_foreach dmzredirect_each dmzredirect
#[ "$userredirect_enabled" -eq 0 ] || config_foreach userredirect_each userredirect

#if [ "$dmz_enabled" = 0 -a "$port_forwarding" = 0 ]; then
#	redirect_port=$INVALID_PORT
#fi

# the request now is : always access wan on port 8090
iptables -t nat -I zone_${zone}_prerouting -p tcp -m tcp --dport $WAN_ACCESS_PORT -m comment --comment "Telmex_reserved_HTTP_access_port_$WAN_ACCESS_PORT" -j REDIRECT --to-ports $redirect_port
