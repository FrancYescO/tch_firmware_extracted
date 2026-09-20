#!/bin/sh

# Copyright (c) 2017 Technicolor

. "$IPKG_INSTROOT"/lib/functions.sh
. "$IPKG_INSTROOT"/lib/functions/network.sh
. "$IPKG_INSTROOT"/usr/lib/intercept/common.sh

print() {
	logger -t intercept "[$$] $*"
}

debug() {
	[ "$INTERCEPT_DEBUG" = 1 ] && logger -t intercept -p DEBUG "[$$] $*"
}

configure_dnsmasq() {
	local active="$1"
	if /etc/init.d/dnsmasq enabled; then
		if [ "$active" = 1 ]; then
			local spoofip
			spoofip="$(uci_get intercept dns spoofip)"
			uci set dhcp.@dnsmasq[0].spoofip="$spoofip"
		else
			uci -q del dhcp.@dnsmasq[0].spoofip
		fi
		uci commit dhcp
		/etc/init.d/dnsmasq restart
	fi
}

restart_ntpd() {
	/etc/init.d/sysntpd enabled && /etc/init.d/sysntpd restart
}

ip_flush() {
	debug "ip_flush()"
	for ip in 4 6; do
		ip -$ip rule del table intercept
		ip -$ip route flush table intercept
	done
}

ip_setup() {
	local lan="$1"
	debug "ip_setup($lan)"

	local lan_dev
	network_get_physdev lan_dev "$lan"

	if [ -z "$lan_dev" ]; then
		print "Failed to find LAN device"
		exit 1
	fi

	# IPv4
	ip -4 rule add iif "$lan_dev" fwmark "$INTERCEPT_MARK" pref 10 table intercept
	ip -4 route add local 0/0 dev lo table intercept
	# IPv6
	ip -6 rule add iif "$lan_dev" fwmark "$INTERCEPT_MARK" pref 10 table intercept
	ip -6 route add local ::/0 dev lo table intercept
}

ipset_flush() {
	debug "ipset_flush()"

	for SET in "${IPSET_TABLE4}" "${IPSET_TABLE6}"; do
		ipset flush "${SET}"
	done
}

ipset_setup() {
	debug "ipset_setup()"

	# Add routable IPv4 networks
	ip -4 route show table main | awk -v set="${IPSET_TABLE4}" '/^[0-9]/{print "ipset -exist add "set " "$1}' | uniq | /bin/sh
	# Add routable IPv6 networks (but no need for link local address)
	ip -6 route show table main | awk -v set="${IPSET_TABLE6}" '/^[0-9a-f]+:/ {if ($1 !~ /^fe80:/) print "ipset -exist add "set " "$1}' | uniq | /bin/sh
}

ipset_update() {
	local active="$1"
	debug "ipset_update($active)"

	ipset_flush
	[ "$active" = 1 ] && ipset_setup
}

firewall_flush() {
	debug "firewall_flush()"

	for iptables_cmd in iptables ip6tables; do
		$iptables_cmd -t mangle -F "$INTERCEPT_FW_PRECHAIN"
		$iptables_cmd -t mangle -F "$INTERCEPT_FW_CHAIN" && $iptables_cmd -t mangle -X "$INTERCEPT_FW_CHAIN"
	done
}

firewall_add_port() {
	local port="$1"
	debug "firewall_add_port($port)"

	for iptables_cmd in iptables ip6tables; do
		$iptables_cmd -t mangle -A "$INTERCEPT_FW_PRECHAIN" -p tcp --dport "$port" -j "$INTERCEPT_FW_CHAIN"
	done
}

firewall_setup() {
	local lan="$1"
	debug "firewall_setup($lan)"

	local lan_intf
	network_get_device lan_intf "$lan"

	if [ -z "$lan_intf" ]; then
		print "Failed to find LAN interface"
		exit 1
	fi

	# If a nointerceptX ipset does not yet exist, create it
	ipset -exist create "${IPSET_TABLE4}" hash:net family inet
	ipset -exist create "${IPSET_TABLE6}" hash:net family inet6

	# IPv4
	iptables  -t mangle -N "$INTERCEPT_FW_CHAIN"
	iptables  -t mangle -A "$INTERCEPT_FW_PRECHAIN" ! -i "$lan_intf" -j RETURN
	iptables  -t mangle -A "$INTERCEPT_FW_PRECHAIN" -i "$lan_intf" -m set --match-set "${IPSET_TABLE4}" dst -j RETURN
	# IPv6
	ip6tables -t mangle -N "$INTERCEPT_FW_CHAIN"
	ip6tables -t mangle -A "$INTERCEPT_FW_PRECHAIN" ! -i "$lan_intf" -j RETURN
	ip6tables -t mangle -A "$INTERCEPT_FW_PRECHAIN" -i "$lan_intf" -m set --match-set "${IPSET_TABLE6}" dst -j RETURN
	config_list_foreach config port firewall_add_port
	firewall_update 0
}

firewall_update() {
	local active="$1"
	debug "firewall_update($active)"

	local spoofip
	if [ "$active" = 0 ]; then
		spoofip="$(uci_get intercept dns spoofip)"
	fi

	# IPv4
	iptables -t mangle -F "$INTERCEPT_FW_CHAIN"
	iptables -t mangle -A "$INTERCEPT_FW_CHAIN" ${spoofip:+-d $spoofip} -p tcp -j TPROXY --tproxy-mark "$INTERCEPT_MARK" --on-port "$INTERCEPT_PORT"

	# IPv6
	ip6tables -t mangle -F "$INTERCEPT_FW_CHAIN"
	[ "$active" = 1 ] && ip6tables -t mangle -A "$INTERCEPT_FW_CHAIN" -p tcp -j TPROXY --tproxy-mark "$INTERCEPT_MARK" --on-port "$INTERCEPT_PORT"
}

intercept_update() {
	local active="$1"

	ipset_update "$active"
	firewall_update "$active"
}

intercept_set_state() {
	local active="$1"

	intercept_update "$active"
	configure_dnsmasq "$active"
	[ "$active" = 0 ] && restart_ntpd
}

case "$1" in
	start)
		intercept_set_state 1
		exit 0
		;;
	stop)
		intercept_set_state 0
		exit 0
		;;
	update)
		intercept_update 1
		exit 0
		;;
	setup)
		ip_flush
		ipset_flush
		firewall_flush

		config_load intercept
		config_get lan config lan

		if [ -z "$lan" ]; then
			print "Invalid LAN interface configured"
			exit 1
		fi

		ip_setup "$lan"
		firewall_setup "$lan"
		ubus call service event '{"type":"intercept.setup", "data":{}}'
		exit 0
		;;
	default)
		print "Invalid action \"$1\""
		exit 1
		;;
esac
