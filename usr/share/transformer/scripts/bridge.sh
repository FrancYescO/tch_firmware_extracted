#!/bin/sh

for i in lan eth0_guest eth1_guest eth2_guest eth3_guest guest lan_public wan6 wwan atm0 eth4; do
	uci del network.$i
done
for i in $(seq 0 4); do
	uci set network.eth$i=device
	uci set network.eth$i.name=eth$i
	uci set network.eth$i.ipv6=0
	uci set network.eth$i.mtu=1508
done

uci del xtm.atm0
uci commit xtm

for i in dnsmasq odhcpd dhcpopassthrud dhcpsnooper gre-hotspotd xl2tpd sysntpd wansensing wireless hostapd ewifi mmpbxd mmpbxfwctl nqe samba cupsd dlnad mvfs miniupnpd-tch igmpproxy mldproxy mcsnooper ipset dropbear ngwfdd nginx ra intercept mosquitto weburl mqttjson-services fhcd multiap_agent multiap_controller wifi-conductor wifi-doctor-agent pinholehelper redirecthelper tod mobiled lte-doctor-logger lxc lxc.mount vdfcert vdfpnpd; do
	/etc/init.d/$i disable
done
reboot
