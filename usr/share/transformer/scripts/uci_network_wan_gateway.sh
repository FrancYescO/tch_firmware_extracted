# Fastweb virtual IP scenario
wan_ifname=`uci get network.wan.ifname 2> /dev/null`

if [ "${wan_ifname##*@}" != "mgmt" ] ;then
return
fi

wan_ip=`uci get network.wan.ipaddr 2> /dev/null`

if [ "$wan_ip" == "_SET_BY_CWMP_SCRIPT_" ] || [ "$wan_ip" == "" ]; then
uci set firewall.SNAT_RADIUS.enabled='0'
uci set firewall.SNAT_wan_zone.enabled='0'
uci set firewall.SNAT_wan_zone_guest.enabled='0'
uci set firewall.SNAT_PING.enabled='0'
uci set firewall.MARK_WAN_TO_LAN.enabled='0'
uci set firewall.MARK_LAN_TO_WAN.enabled='0'
uci set firewall.MARK_GUEST_TO_WAN.enabled='0'
uci set firewall.@zone[2].output='DROP'
uci set firewall.@cone[0].src_dip='_SET_BY_CWMP_SCRIPT_'
uci set firewall.@cone[1].src_dip='_SET_BY_CWMP_SCRIPT_'
uci set firewall.@cone[2].src_dip='_SET_BY_CWMP_SCRIPT_'
uci set firewall.SNAT_RADIUS.src_dip='_SET_BY_CWMP_SCRIPT_'
uci set firewall.SNAT_wan_zone.src_dip='_SET_BY_CWMP_SCRIPT_'
uci set firewall.SNAT_wan_zone_guest.src_dip='_SET_BY_CWMP_SCRIPT_'
uci set firewall.SNAT_PING.src_dip='_SET_BY_CWMP_SCRIPT_'
uci set firewall.MARK_WAN_TO_LAN.dest_ip='_SET_BY_CWMP_SCRIPT_'
DenyRadius=`uci get firewall.Deny_RADIUS 2> /dev/null`
if [ "$DenyRadius" != "" ]; then
    uci set firewall.Deny_RADIUS.enabled='1'
fi
uci del firewall.@forwarding[0]
uci set network.wan.ipaddr='_SET_BY_CWMP_SCRIPT_'
uci set network.wan.auto='0'
uci commit network
ifdown wan
else
uci set firewall.SNAT_RADIUS.enabled='1'
uci set firewall.SNAT_wan_zone.enabled='1'
uci set firewall.SNAT_wan_zone_guest.enabled='1'
uci set firewall.SNAT_PING.enabled='1'
uci set firewall.MARK_WAN_TO_LAN.enabled='1'
uci set firewall.MARK_GUEST_TO_WAN.enabled='1'
uci set firewall.MARK_LAN_TO_WAN.enabled='1'
uci set firewall.@zone[2].output='ACCEPT'

uci set firewall.@cone[0].src_dip=$wan_ip
uci set firewall.@cone[1].src_dip=$wan_ip
uci set firewall.@cone[2].src_dip=$wan_ip
uci set firewall.SNAT_RADIUS.src_dip=$wan_ip
uci set firewall.SNAT_wan_zone.src_dip=$wan_ip
uci set firewall.SNAT_wan_zone_guest.src_dip=$wan_ip
uci set firewall.SNAT_PING.src_dip=$wan_ip
uci set firewall.MARK_WAN_TO_LAN.dest_ip=$wan_ip

DenyRadius=`uci get firewall.Deny_RADIUS 2> /dev/null`
if [ "$DenyRadius" != "" ]; then
    uci set firewall.Deny_RADIUS.enabled='0'
fi
uci set network.wan.auto='1'
uci commit network
ifup wan

forwarding=`uci get firewall.@forwarding[0] 2> /dev/null`
if [ "$forwarding" == "" ]; then
    uci add firewall forwarding >/dev/null
    uci set firewall.@forwarding[-1].src='lan'
    uci set firewall.@forwarding[-1].dest='wan'
fi

fi

uci commit firewall

/etc/init.d/firewall reload
