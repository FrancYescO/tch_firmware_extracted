#!/bin/sh
# Copyright (c) 2013 Technicolor

. $IPKG_INSTROOT/lib/functions.sh

create_wanif_invalid_packets_drop_log()
{
	iptables -t filter -I zone_wan_src_DROP -m limit --limit 3/s -j LOG --log-prefix "Security warning-packet drop:" --log-level 4
}

create_wanif_invalid_packets_drop_log
