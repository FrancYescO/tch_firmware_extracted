#!/bin/sh

#cleaning the dhcp static entries pointing to a STB; mac oui of the STB is used to identify such entries.

mac_oui="00:02:9b\|6c:ca:08\|3c:df:a9\|e0:b7:0a\|10:05:b1\|d0:39:b3\|d4:04:cd\|00:26:44\|d4:0a:a9\|a8:11:fc\|74:ea:e8\|34:1f:e4"

if [ $(uci show dhcp | grep $mac_oui | wc -l) -gt 0 ];
	then
		indexes=`uci show dhcp | grep $mac_oui | sed 's:^.*\[::;s:\].*$::'`
		
		rev_indexes=""
		for i in $indexes; do
			rev_indexes=$i" "$rev_indexes 
		done
		
		for k in $rev_indexes; do
			uci del dhcp.@host[$k]
		done
fi

uci commit dhcp

#cleaning userredirect entries used for STB; the userredirect name is used to identify such entries. Names begin with STB_

if [ $(uci show firewall | grep STB_ | wc -l) -gt 0 ];
	then
		indexes=`uci show firewall | grep STB_ | sed 's:^.*\[::;s:\].*$::'`

		rev_indexes=""
		for i in $indexes; do
			rev_indexes=$i" "$rev_indexes 
		done

		for k in $rev_indexes; do
			uci del firewall.@userredirect[$k]
		done
fi

uci commit firewall

