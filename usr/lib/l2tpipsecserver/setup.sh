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

xl2tpd_conf="/etc/xl2tpd/xl2tpd.conf"
ppp_options="/etc/ppp/options.xl2tpd"
chapsecrets="/etc/ppp/chap-secrets"

tmp_xl2tpd_conf="/var/xl2tpd/xl2tpd.conf"
tmp_ppp_options="/var/ppp/options.xl2tpd"
tmp_chapsecrets="/var/ppp/chap-secrets"

uci_config="vpn"
provider="tchvpn"

# Set 'local ip', 'ip range' and 'name' options to /etc/xl2tpd/xl2tpd.conf, depending on LAN network config
# Parameters: none
__setup_xl2tpd_conf() {
    mkdir -p "$(dirname $tmp_xl2tpd_conf)"
    cp -f "$xl2tpd_conf.template" "$tmp_xl2tpd_conf"
    [ -L "$xl2tpd_conf" ] || ln -snf "$tmp_xl2tpd_conf" "$xl2tpd_conf"

    local local_ip remote_ip_start remote_ip_end
    config_get local_ip l2tpipsecserver local_ip
    config_get remote_ip_start l2tpipsecserver remote_ip_start
    config_get remote_ip_end l2tpipsecserver remote_ip_end

    # Our PPP IP address
    [ -n "$local_ip" ] && sed -i "/local ip/c\local ip = $local_ip" "$tmp_xl2tpd_conf"

    # IP Range for our PPP peers
    [ -n "$remote_ip_start" -a -n "$remote_ip_end" ] && sed -i "/ip range/c\ip range = $remote_ip_start-$remote_ip_end" "$tmp_xl2tpd_conf"

    # Name of provider (ourselves); used for chap authentication
    sed -i "/name =/c\name = $provider" "$tmp_xl2tpd_conf"
}

__setup_ppp_options() {
    mkdir -p "$(dirname $tmp_ppp_options)"
    cp -f "$ppp_options.template" "$tmp_ppp_options"
    [ -L "$ppp_options" ] || ln -snf "$tmp_ppp_options" "$ppp_options"

    local local_ip proxyarp
    config_get local_ip l2tpipsecserver local_ip
    config_get_bool proxyarp l2tpipsecserver proxyarp

    # advertise our server ip for DNS resolving
    [ -n "$local_ip" ] && sed -i "/ms-dns/c\ms-dns $local_ip" "$tmp_ppp_options"

    # Proxy-arping
    [ $proxyarp -eq 1 ] && echo proxyarp >> "$tmp_ppp_options"
}

# Helper function to set 'USERNAME, PROVIDER, PASSWORD, IPADDRESS' records to /etc/ppp/chap-secrets for the specified user
# Parameters: l2tp_upser UCI object
__install_chap_secret() {
    local user="$1"
    local username password
    config_get username "$user" name
    config_get password "$user" password

    [ -n "$username" -a -n "$password" ] || return

    # chap-secrets file has records in format:
    #           USERNAME  PROVIDER  PASSWORD  IPADDRESS
    local chap="$username $provider $password *"

    # Init or replace each (username, password, provider, IP address) entry
    grep -q "$username.*$provider" $chapsecrets && sed -i "s/.*$username.*$provider.*/$chap/" $chapsecrets || echo "$chap" >> $tmp_chapsecrets
}

# Clear and regenerate /etc/ppp/chap-secrets, depending on credentials specified in UCI
# Parameters: none
__setup_chap_secrets() {
    mkdir -p "$(dirname $chapsecrets)"
    [ -L "$chapsecrets" ] || ln -snf "$tmp_chapsecrets" "$chapsecrets"

    # Start from clean file to get rid of old accounts, if any
    echo "# USERNAME  PROVIDER  PASSWORD  IPADDRESS" > $tmp_chapsecrets

    config_foreach __install_chap_secret l2tp_user
}

setup() {
    config_load "$uci_config"

    __setup_xl2tpd_conf
    __setup_ppp_options
    __setup_chap_secrets
}

