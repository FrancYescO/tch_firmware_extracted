#!/bin/sh

# Copyright (c) 2017 Technicolor

. "$IPKG_INSTROOT"/lib/functions.sh
. "$IPKG_INSTROOT"/usr/lib/intercept/common.sh

for iptables_cmd in iptables ip6tables; do
	$iptables_cmd -t mangle -N "$INTERCEPT_FW_PRECHAIN"
	$iptables_cmd -t mangle -I PREROUTING -j "$INTERCEPT_FW_PRECHAIN"
done

config_load intercept
config_get_bool enabled config enabled
[ "$enabled" = 1 ] && /etc/init.d/intercept reload

exit 0
