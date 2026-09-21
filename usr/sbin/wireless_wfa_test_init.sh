#!/bin/sh

#enable wfa testsuite deamon to start on boot
uci set wireless.global.wfa_testsuite_daemon=1

#set networking on wan
uci set network.wan.proto='static'
uci set network.wan.ipaddr=192.168.250.1
uci set network.wan.netmask=255.255.255.0

for i in 0 1 2 3 4 5 6 7; do
DUMMY=`uci get ethernet.eth$i.wan 2> /dev/null`
if [ "$?" == "0" ] ; then
uci set network.wan.ifname=eth$i
fi
done

#accept TCP on wan port 9000
uci set firewall.@rule[0]=rule
uci set firewall.@rule[0].src='wan'
uci set firewall.@rule[0].proto='tcp'
uci set firewall.@rule[0].name='wfa-wan'
uci set firewall.@rule[0].dest_port='9000'
uci set firewall.@rule[0].target='ACCEPT'

#set other parameters for certification
uci set wireless.radio_2G.frame_bursting='0'
uci set wireless.radio_5G.frame_bursting='0'

uci set wireless.wl0.qos_prio_override='1'
uci set wireless.wl1.qos_prio_override='1'

#pmf
uci set wireless.ap0.pmf='1'
uci set wireless.ap1.pmf='1'
uci set wireless.ap0.sae_require_pmf='1'
uci set wireless.ap1.sae_require_pmf='1'

uci set wireless.ap0.wps_w7pbc='0'
uci set wireless.ap0.wsc_state='configured'

uci set wireless.ap1.wps_w7pbc='0'
uci set wireless.ap1.wsc_state='configured'

uci set wireless.ap0_iw=wifi-ap-interworking
uci set wireless.ap0_iw.state='1'
uci set wireless.ap0_iw.internet='0'
uci set wireless.ap0_iw.venue_group='7'
uci set wireless.ap0_iw.venue_type='0'

uci set wireless.ap1_iw=wifi-ap-interworking
uci set wireless.ap1_iw.state='1'
uci set wireless.ap1_iw.internet='0'
uci set wireless.ap1_iw.venue_group='7'
uci set wireless.ap1_iw.venue_type='0'

uci set upnpd.config.enable_upnp='0'

#disable guest interfaces
for iface in wl0_1 wl0_2 wl1_1 wl1_2; do
	uci get wireless.$iface.state &> /dev/null
	if [ "$?" -eq 0 ]; then
		uci set wireless.$iface.state=0
	fi
done

#disable bandsteering
for bs in bs0 bs1 bs2 bs3 bs4; do
	uci get wireless.$bs.state &> /dev/null
	if [ "$?" -eq 0 ]; then
		uci set wireless.$bs.state=0
	fi
done

#drop hotspot and guest interfaces
for ap in ap2 ap3 ap4 ap5; do
        uci delete wireless.$ap &> /dev/null
done
for iface in wl0_1 wl0_2 wl1_1 wl1_2; do
        uci delete wireless.$iface &> /dev/null
done
uci commit

/etc/init.d/network restart
/etc/init.d/hostapd restart
