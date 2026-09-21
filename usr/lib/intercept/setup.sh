#!/bin/sh
# Copyright (c) 2014 Technicolor

INTERCEPT_DEBUG=0 # enable extra logging

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/functions/network.sh
. $IPKG_INSTROOT/usr/lib/intercept/functions.sh

UCI_BIN="/sbin/uci"
UCI_STATE="/var/state/"


ipset_table4="nointercept4"
ipset_table6="nointercept6"


# additional logging to discover interleaving instances
debug() {
    [ $INTERCEPT_DEBUG -eq 1 ] && logger -t intercept "[$$] $@"
}

init_state() {
    $UCI_BIN -P $UCI_STATE set intercept.state=state
    state_set_active 0
}

is_booted() {
    [ -e $UCI_STATE/intercept ]
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
    debug "ip_flush()"
    # IPv4
    ip -4 rule del table intercept
    ip -4 route flush table intercept
    # IPv6
    ip -6 rule del table intercept
    ip -6 route flush table intercept
}

ip_setup() {
    is_booted || return
    [ -n "$lan" ] || return
    debug "ip_setup()"
    network_get_physdev lan_dev "$lan"

    # IPv4
    ip -4 rule add iif $lan_dev fwmark $INTERCEPT_MARK pref 10 table intercept
    ip -4 route add local 0/0 dev lo table intercept
    # IPv6
    ip -6 rule add iif $lan_dev fwmark $INTERCEPT_MARK pref 10 table intercept
    ip -6 route add local ::/0 dev lo table intercept
}



ipset_flush() {
    debug "ipset_flush()"
    for SETNAME in "${ipset_table4}" "${ipset_table6}"
    do
	ipset flush "${SETNAME}"
    done
    logger -t intercept "[$$] flushed nointercept[46] ipsets"
}

ipset_setup() {
    is_booted || return
    debug "ipset_setup()"
    local CMD_SH='/bin/sh '
    #  add routable ipv4 networks
    ip -4 route show table main | awk -v set="${ipset_table4}" '/^[0-9]/ {print "ipset add "set " "$1}' | uniq | $CMD_SH
    #  add routable ipv6 networks (but no need for link local address)
    ip -6 route show table main | awk -v set="${ipset_table6}" '/^[0-9a-f]+:/ {if ($1 !~ /^fe80:/) print "ipset add "set" " $1}' | uniq | $CMD_SH
    logger -t intercept "[$$] populated nointercept[46] ipsets"
}

ipset_update() {
    debug "ipset_update()"
    ipset_flush
    [ $active -eq 1 ] && ipset_setup
}


firewall_flush() {
    debug "firewall_flush()"
    # IPv4
    iptables  -t mangle -F $INTERCEPT_FW_PRECHAIN
    iptables  -t mangle -F $INTERCEPT_FW_CHAIN && iptables  -t mangle -X $INTERCEPT_FW_CHAIN
     # IPv6
    ip6tables -t mangle -F $INTERCEPT_FW_PRECHAIN
    ip6tables -t mangle -F $INTERCEPT_FW_CHAIN && ip6tables -t mangle -X $INTERCEPT_FW_CHAIN
}

firewall_add_port() {
    local port=$1
    debug "firewall_add_port()"
    # IPv4
    iptables  -t mangle -A $INTERCEPT_FW_PRECHAIN -p tcp --dport $port -j $INTERCEPT_FW_CHAIN
    # IPv6
    ip6tables -t mangle -A $INTERCEPT_FW_PRECHAIN -p tcp --dport $port -j $INTERCEPT_FW_CHAIN
}

firewall_setup() {
    is_booted || return
    [ "$enabled" == 1 ] && [ -n "$lan" ] || return
    debug "firewall_setup()"

    network_get_device lan_intf "$lan"
    network_get_ipaddr lan_ip "$lan"

    # if a nointerceptX ipset does not yet exist, create it
    ipset -exist create "${ipset_table4}" hash:net family inet
    ipset -exist create "${ipset_table6}" hash:net family inet6

    # IPv4
    iptables  -t mangle -N $INTERCEPT_FW_CHAIN
    iptables  -t mangle -A $INTERCEPT_FW_PRECHAIN ! -i $lan_intf -j RETURN
    iptables  -t mangle -A $INTERCEPT_FW_PRECHAIN -i $lan_intf -m set --match-set ${ipset_table4} dst -j RETURN
    # IPv6
    ip6tables -t mangle -N $INTERCEPT_FW_CHAIN
    ip6tables -t mangle -A $INTERCEPT_FW_PRECHAIN ! -i $lan_intf -j RETURN
    ip6tables -t mangle -A $INTERCEPT_FW_PRECHAIN -i $lan_intf -m set --match-set ${ipset_table6} dst -j RETURN
    config_list_foreach config port firewall_add_port
    firewall_update
}

firewall_update() {
    local destip
    debug "firewall_update()"
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
    logger -t intercept "[$$] intercept_set_state($active)"
    intercept_active && current_active=1 || current_active=0
    [ $current_active -eq 0 ] && [  $active -eq 0 ]  && {
	logger -t intercept "[$$] skipping reconfiguration (active remains $active, was $current_active)"
	return
    }
    logger -t intercept "[$$] reconfigure active from $current_active to $active"
    state_set_active $active
    ipset_update
    [ $active -eq $current_active ]  && return
    firewall_update
    restart_dnsmasq
    [ $active == 0 ] && restart_ntpd
}


# for a interface in the wan list
# first check if we already decided whether a wan connection is up and skip testing that again
# then test for a default gateway on an interface
# if not yet decided wan_is_up, we test for an ipv6 default route
check_wan_intf() {
   local intf=$1
   local inactive=0  # do not check for inactive routes

   [ $wan_is_up -ne 0 ]  && return  # do not test what is already known

   local gw_ipv4=''
   network_get_gateway 'gw_ipv4' $intf $inactive
   [ -n "$gw_ipv4" ] && wan_is_up=1  && return

   local gw_ipv6=''
   network_get_gateway 'gw_ipv6' $intf $inactive
   [ -n "$gw_ipv6" ] && wan_is_up=1
}


# search in the list of wan interfaces whether at least one has a default route
check_all_wan_down() {
    wan_is_up=0
    config_list_foreach config wan check_wan_intf
    logger -t intercept "[$$] WAN connectivity $wan_is_up"
    return $wan_is_up
}

intercept_unlock() {
    lock -u /var/lock/LCK.intercept || logger -t intercept "[$$] setup cannot unlock"
}

# a lock to prevent race condition while booting NG-84252
lock /var/lock/LCK.intercept || logger -t intercept "[$$] setup cannot lock"
trap intercept_unlock EXIT

logger -t intercept "[$$] setup (action=$1)"
config_load intercept
config_get_bool enabled config enabled

case "$1" in
    ifchanged)
	# when not enabled, we do not even expect this event
	[ "$enabled" == 0 ] &&  {
	    logger -t intercept "[$$] Unexpected ifchanged event since intercept was not enabled"
	    exit 0
	}
	# don't handle ifchanged events if intercept is not started yet (see boot)
	if [ ! -e $UCI_STATE/intercept ]
	then
	    logger -t intercept "[$$] Ifchanged event not handled before boot"
	    exit 0
	fi
	logger -t intercept "[$$] an interface changed, test default route via observed interface"
	if check_all_wan_down
	then
	    intercept_set_state 1
	else
	    intercept_set_state 0
	fi
	logger -t intercept "[$$] completely handled 'ifchanged'"
	exit 0
	;;
    boot|reload|firewall)
    ;;
    default)
    logger -t intercept "[$$] setup error : invalid action $1"
    exit 1
    ;;
esac

config_get lan config lan

case "$1" in
    boot|reload)
    active=0
    ip_flush
    ipset_flush
    firewall_flush
    is_booted || init_state
    [ "$enabled" == 1 ] && {
	check_all_wan_down && active=1
	ip_setup
	firewall_setup
    }
    logger -t intercept "[$$] $1 in state $active"
    intercept_set_state $active
    logger -t intercept "[$$] completely handled '$1'"
    exit 0
    ;;
    firewall)
    firewall_flush
    intercept_active && active=1 || active=0
    firewall_setup
    exit 0
    ;;
esac
