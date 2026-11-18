#!/bin/sh
# Copyright (c) 2014 Technicolor

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/functions/network.sh
. $IPKG_INSTROOT/usr/lib/intercept/functions.sh

config_load intercept
config_get_bool enabled config enabled

# IPv4
iptables -t mangle -N $INTERCEPT_FW_PRECHAIN
iptables -t mangle -I PREROUTING -j $INTERCEPT_FW_PRECHAIN

# IPv6
ip6tables -t mangle -N $INTERCEPT_FW_PRECHAIN
ip6tables -t mangle -I PREROUTING -j $INTERCEPT_FW_PRECHAIN

[ "$enabled" == 1 ] && $INTERCEPT_SETUP firewall

exit 0
