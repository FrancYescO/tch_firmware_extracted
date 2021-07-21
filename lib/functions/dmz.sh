#!/bin/sh
# Copyright (c) 2013 Technicolor

. $IPKG_INSTROOT/lib/functions.sh

create_dmz_rules_proto()
{
    local src="$1"
    local dest_ip="$2"
    local proto="$3"

    iptables -t nat -A zone_${src}_prerouting -p ${proto} -m comment --comment DMZ -j DNAT --to-destination ${dest_ip}
    iptables -I zone_${src}_src_DROP -d ${dest_ip} -p ${proto} -m comment --comment DMZ -j ACCEPT
}

create_dmz_rules()
{
    create_dmz_rules_proto $1 $2 tcp
    create_dmz_rules_proto $1 $2 udp
}

dmz_load() {
    local cfg="$1"

    config_get enable $cfg enable
    config_get dest_ip $cfg dest_ip
    config_get src $cfg src

    if [ "${enable}" == "1" -a -n "${dest_ip}" ]; then
        echo "Enabling DMZ for destination [${dest_ip}] via interface [${src:-wan}]"
	create_dmz_rules ${src:-wan} ${dest_ip}
    fi
}

config_load firewall
dmz_load dmz
