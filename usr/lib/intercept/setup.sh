#!/bin/sh
# Copyright (c) 2014 Technicolor

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/functions/network.sh
. $IPKG_INSTROOT/usr/lib/intercept/functions.sh

UCI_BIN="/sbin/uci"
UCI_STATE="/var/state/"

init_state() {
    $UCI_BIN -P $UCI_STATE set intercept.state=state
}

state_set_active() {
    uci_toggle_state intercept state active $1
}

restart_dnsmasq() {
    /etc/init.d/dnsmasq enabled && /etc/init.d/dnsmasq restart
}

restart_ntpd() {
    /etc/init.d/sysntpd enabled && /etc/init.d/sysntpd restart
}

ip_flush() {
    # IPv4
    ip -4 rule del table intercept
    ip -4 route flush table intercept
    # IPv6
    ip -6 rule del table intercept
    ip -6 route flush table intercept
}

ip_setup() {
    [ -n "$lan" ] || return
    network_get_physdev lan_dev "$lan"

    # IPv4
    ip -4 rule add iif $lan_dev fwmark $INTERCEPT_MARK pref 10 table intercept
    ip -4 route add local 0/0 dev lo table intercept
    # IPv6
    ip -6 rule add iif $lan_dev fwmark $INTERCEPT_MARK pref 10 table intercept
    ip -6 route add local ::/0 dev lo table intercept
}

firewall_flush() {
    # IPv4
    iptables  -t mangle -F $INTERCEPT_FW_PRECHAIN
    iptables  -t mangle -F $INTERCEPT_FW_CHAIN && iptables  -t mangle -X $INTERCEPT_FW_CHAIN
     # IPv6
    ip6tables -t mangle -F $INTERCEPT_FW_PRECHAIN
    ip6tables -t mangle -F $INTERCEPT_FW_CHAIN && ip6tables -t mangle -X $INTERCEPT_FW_CHAIN
}

firewall_add_port() {
    local port=$1
    # IPv4
    iptables  -t mangle -A $INTERCEPT_FW_PRECHAIN -p tcp --dport $port -j $INTERCEPT_FW_CHAIN
    # IPv6
    ip6tables -t mangle -A $INTERCEPT_FW_PRECHAIN -p tcp --dport $port -j $INTERCEPT_FW_CHAIN
}

firewall_setup() {
    [ "$enabled" == 1 ] && [ -n "$lan" ] || return
    network_get_device lan_intf "$lan"
    network_get_ipaddr lan_ip "$lan"

    # IPv4
    iptables  -t mangle -N $INTERCEPT_FW_CHAIN
    iptables  -t mangle -A $INTERCEPT_FW_PRECHAIN ! -i $lan_intf -j RETURN
    iptables  -t mangle -A $INTERCEPT_FW_PRECHAIN -d $lan_ip -j RETURN
    # IPv6
    ip6tables -t mangle -N $INTERCEPT_FW_CHAIN
    ip6tables -t mangle -A $INTERCEPT_FW_PRECHAIN ! -i $lan_intf -j RETURN

    config_list_foreach config port firewall_add_port
    firewall_update
}

firewall_update() {
    local destip
    [ $active == 1 ] || destip="-d $(intercept_spoofip)"

    # IPv4
    iptables -t mangle -F $INTERCEPT_FW_CHAIN
    iptables -t mangle -A $INTERCEPT_FW_CHAIN $destip -p tcp -j TPROXY --tproxy-mark $INTERCEPT_MARK --on-port $INTERCEPT_PORT

    # IPv6
    ip6tables -t mangle -F $INTERCEPT_FW_CHAIN
    [ $active == 1 ] && ip6tables -t mangle -A $INTERCEPT_FW_CHAIN -p tcp -j TPROXY --tproxy-mark $INTERCEPT_MARK --on-port $INTERCEPT_PORT
}

intercept_set_state() {
    active=$1
    config_get current_active state active
    [ "$active" = "$current_active" ] && {
	logger -t intercept "skipping reconfiguration (active remains $current_active)"
	return
    }
    logger -t intercept "reconfiguration from $current_active to $active"
    state_set_active $1
    firewall_update
    restart_dnsmasq
    [ $active == 0 ] && restart_ntpd
}

datamodel_check() {
    local intf=$1
    config_get section_type "$intf" 'TYPE'
    [ "$section_type" != "interface" ] && return 0  # section is not an interface
    config_get dmstatus "$intf" 'dmstatus'
    [ -z "$dmstatus" ] && return 0 # no test on datamodel specified
    logger -t intercept "confirm $intf via datamodel"
    local STATUS="$(transformer-cli get ${dmstatus} | awk -F' = *'  '{print $2}')"
    if [ "${STATUS##Error_}" != "${STATUS}" ]
    then
	logger -t intercept "$intf shows ${STATUS} via $dmstatus"
	return 1
    fi
}

check_wan_intf() {
    network_is_up "$1" && datamodel_check "$1" && wan_is_up=1
}

check_all_wan_down() {
    wan_is_up=0
    config_list_foreach config wan check_wan_intf
    logger -t intercept "WAN connectivity $wan_is_up"
    return $wan_is_up
}

logger -t intercept "setup (action=$1)"
config_load intercept
config_get_bool enabled config enabled

case "$1" in
    ifchanged)
	# when not enabled, we do not even expect this event
	[ "$enabled" == 0 ] &&  {
	    logger -t intercept "Unexpected ifchanged event since intercept was not enabled"
	    exit 0
	}
        # don't handle ifchanged events if intercept is not started yet (see boot)
	[ -e $UCI_STATE/intercept ] || exit 0
	logger -t intercept "an observed interface changed"
	check_all_wan_down && intercept_set_state 1 || intercept_set_state 0
	exit 0
	;;
    boot|reload|firewall)
    ;;
    default)
    logger -t intercept "setup error : invalid action"
    exit 1
    ;;
esac

config_get lan config lan

case "$1" in
    boot)
    active=0
    [ "$enabled" == 1 ] && {
	check_all_wan_down && active=1
	[ -e $UCI_STATE/intercept ] || {
	    ip_setup
	    firewall_setup
	}
    }
    init_state
    state_set_active $active
    exit 0
    ;;
    reload)
    ip_flush
    firewall_flush
    active=0
    [ "$enabled" == 1 ] && {
	check_all_wan_down && active=1
	ip_setup
	firewall_setup
    }
    state_set_active $active
    restart_dnsmasq
    [ $active == 0 ] && restart_ntpd
    exit 0
    ;;
    firewall)
    intercept_active && active=1 || active=0
    firewall_setup
    exit 0
    ;;
esac
