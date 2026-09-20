#!/bin/sh
# Copyright (C) 2015 Technicolor Delivery Technologies, SAS

# This file handles the L2TP/IPSec server setup.
# More specifically, it sets up the configuration files used by the ipsec and xl2tpd daemons:
#    - gets the CHAP credentials from UCI and puts them to /etc/ppp/chap-secrets
#    - gets the single IPSec PSK from UCI and puts it to /etc/ipsec.secrets
#    - puts a local ip address and ip range to /etc/xl2tpd/xl2tpd.conf, taking the local LAN address into account to avoid conflicts
#    - adds option 121 to the DHCP server to push static routes to clients, so they know how to route packets destined for the tunnel
#
# This script run at:
#    - first boot
#    - start, reload or restart of /etc/init.d/l2tp-ipsec-server

. $IPKG_INSTROOT/lib/functions.sh

local provider="tchvpn"
local config="l2tpipsecserver"

local chapsecrets="/etc/ppp/chap-secrets"
local dhcp_option="dhcp.lan.dhcp_option"
local l2tpipsecserver_state="/var/state/${config}"

# Helper function to setup routing for VPN clients so they know how to route back to remote clients
# Parameters: the ppp interface's IP address, the GW's IP address
__setup_routing() {
    local ppp_ip=$1
    local gw=$2

    local ppp_nm="255.255.255.0" # This is an appropriate netmask for the ppp interface's virtual network
    local ppp_nw=$(ipcalc.sh $ppp_ip $ppp_nm | sed -n -e 's/NETWORK=//p')
    local ppp_pf=$(ipcalc.sh $ppp_ip $ppp_nm | sed -n -e 's/PREFIX=//p')

    # Routing is achieved by pushing routes to client(s) through option 121
    # Look for the old 121 dhcp_option entry, delete and add again
    local data="121,$ppp_nw/$ppp_pf,$gw"

    # Store our option through /var/state
    touch ${l2tpipsecserver_state}
    uci -P /var/state set ${config}.dhcpoption="$data"
    uci add_list "$dhcp_option"="$data"
    uci commit
}

# Helper function to tear down routing for VPN clients
# Parameters: none
__teardown_routing() {
    local data=$(uci_get_state ${config} dhcpoption "")
    if [ -n "$data" ]; then
        uci del_list "$dhcp_option"="$data"
        uci commit
        rm ${l2tpipsecserver_state}
    fi
}

# Set 'local ip', 'ip range' and 'name' options to /etc/xl2tpd/xl2tpd.conf, depending on LAN network config
# Parameters: none
__setup_xl2tpd_conf() {
    local conf="/etc/xl2tpd/xl2tpd.conf"

    # Our PPP IP address
    local lanip=$(uci get network.lan.ipaddr)
    local ip="192.168.10.1"
    if [ "$ip" == "$lanip" ]; then
        # Set to non-conflicting IP address if lanip happens to be in our range
        ip="192.168.100.1"
    fi
    sed -i '/local ip/c\local ip = '$ip'' "$conf"

    # Range for our PPP peers - up to 15 peers supported with this construct
    local iprange="${ip}00-${ip}14"
    sed -i '/ip range/c\ip range = '$iprange'' "$conf"

    # Name of provider (ourselves); used for chap authentication
    sed -i '/name =/c\name = '$provider'' "$conf"

    # Finally, setup routing depending on the IP address we chose
    __setup_routing $ip $lanip
}

# Helper function to set 'USERNAME, PROVIDER, PASSWORD, IPADDRESS' records to /etc/ppp/chap-secrets for the specified user
# Parameters: l2tp_upser UCI object
__install_chap_secret() {
    local user="$1"
    local username=$(uci_get "$config" "$user" name)
    local password=$(uci_get "$config" "$user" secret)

    if [ ! -z "$username" -a ! -z "$password" ]; then
        # chap-secrets file has records in format:
        #           USERNAME  PROVIDER  PASSWORD  IPADDRESS
        local chap="$username $provider $password *"

        # Init or replace each (username, password, provider, IP address) entry
        grep -q "$username.*$provider" $chapsecrets && sed -i "s/.*$username.*$provider.*/$chap/" $chapsecrets || echo "$chap" >> $chapsecrets
    fi
}

# Clear and regenerate /etc/ppp/chap-secrets, depending on credentials specified in UCI
# Parameters: none
__setup_chap_secrets() {
    # Start from clean file to get rid of old accounts, if any
    echo "# USERNAME  PROVIDER  PASSWORD  IPADDRESS" > $chapsecrets

    config_foreach __install_chap_secret l2tp_user
}

# Set the single IPSec PSK to /etc/ipsec.secrets, depending on the PSK specified in UCI.
# Parameters: none
__setup_ipsec_secrets() {
    local conf="/etc/ipsec.secrets"

    local entry=": PSK"
    local psk=$(uci_get "$config" "ipsec_global" "PSK")
    local newentry="$entry $psk"

    # Security measure: only init or replace if PSK not empty
    if [ ! -z "$psk" ]; then
        # Init or replace the single PSK for IPSec authentication
        grep -q "$entry" $conf && sed -i "s/.*$entry.*/$newentry/" $conf || echo "$newentry" >> $conf
    fi
}

setup() {
    config_load "$config"
    config_get_bool enabled global enabled 0

    __teardown_routing

    # Only setup files if the L2TP/IPSec server is enabled
    if [ $enabled -eq 1 ]; then
        __setup_ipsec_secrets
        __setup_xl2tpd_conf
        __setup_chap_secrets
    fi

    # Reload the DHCP server to update the routing option
    /etc/init.d/dnsmasq reload
}

setup
