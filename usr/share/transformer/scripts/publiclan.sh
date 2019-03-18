#!/bin/sh
# Copyright (c) 2013 Technicolor

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/functions/network.sh

get_netmask() {
   local netmask=${1##*255.}
   set -- 0^^^128^192^224^240^248^252^254^ $(( (${#1} - ${#netmask})*2 )) ${netmask%%.*}
   netmask=${1%%$3*}
   mask="$(( $2 + (${#netmask}/4) ))"
}


set_ipaddr() {                          
    local interface="$1"                              

    if [ "{$interface}" == "{public_lan}" ] ; then
		config_get ipaddr $interface ipaddr
		config_get netmask $interface netmask
      
		get_netmask $netmask
     
		uci delete firewall.wan.masq_src
		uci delete firewall.public_lan.subnet
		if [ "{$ipaddr}" != "{0.0.0.0}" ] ; then
			uci add_list firewall.wan.masq_src="!$ipaddr/$mask"
			uci add_list firewall.public_lan.subnet="$ipaddr/$mask"
		fi
		uci commit
    fi
}

config_load network
config_foreach set_ipaddr interface
