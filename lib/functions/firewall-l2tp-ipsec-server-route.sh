#!/bin/sh
# Copyright (C) 2015 Technicolor Delivery Technologies, SAS

. $IPKG_INSTROOT/lib/functions.sh

local chain="zone_vpn_forward"
local targetchain="delegate_forward"
local tag="vpn_fwd"

# Helper function which deletes forwarding rule for specified device from the chain.
# If the specified device is the only one left that has rules in the chain, the chain will also be flused and deleted.
# Parameters: the device the ppp device name for which the route is to be deleted
__clean_chain() {
    if [ $# -eq 1 ]; then
        local device=$1

        # Search and delete all matching forward rules: use tag to grep the rules that belong to the specified device
        local pos=$(iptables -L ${chain} -n --line-number | grep "${tag} ${device}" | cut -f1 -d$' ' | tail -1)
        while [[ $pos ]]; do
            iptables -D ${chain} ${pos}
            pos=$(iptables -L ${chain} -n --line-number | grep "${tag} ${device}" | cut -f1 -d$' ' | tail -1)
        done

        # Now check if the rules for this device were the last ones; if so delete the chain
        local any=$(iptables -L ${chain} -n --line-number | grep "${tag}" | cut -f1 -d$' ')
        if [ -z "$any" ]; then
            # Silently delete from targetchain
            iptables -D ${targetchain} -j ${chain} 2>/dev/null
            # Then flush and delete chain itself
            iptables -F ${chain} 2>/dev/null
            iptables -X ${chain} 2>/dev/null
        fi
    fi
}

# Helper function which creates the chain and inserts it into the target chain, if it does not exist yet
# Parameters: none
__create_chain() {
    local pos=$(iptables -L ${targetchain} -n --line-number | grep -i ${chain} | cut -f1 -d$' ' | tail -1)

    if [ -z "$pos" ]; then
        iptables -N ${chain}

        # Insert our zone right in front of current last zone in list.
        # This just ensures that we keep zones grouped together in the chain; absolute order does not matter.
        # If no zones exist (yet), we may be first in the list (pos would be empty).
        local pos=$(iptables -L ${targetchain} -n --line-number | grep -i zone | cut -f1 -d$' ' | tail -1)
        iptables -I ${targetchain} ${pos} -j ${chain}
    fi
}

# Helper function which inserts the actual rules that are required to forward traffic from the tunnel to LAN or WAN
# Parameters: the ppp device name, the IP address of the ppp device
__insert_rules() {
    if [ $# -eq 2 ]; then
        local device=$1
        local ppp_ip=$2

        local ppp_netmask="255.255.255.0" # This is an appropriate netmask for the ppp interface's virtual network
        local ppp_nw=$(ipcalc.sh $ppp_ip $ppp_netmask | sed -n -e 's/NETWORK=//p')
        local ppp_pf=$(ipcalc.sh $ppp_ip $ppp_netmask | sed -n -e 's/PREFIX=//p')

        iptables -I ${chain} -i "$device" -s "$ppp_nw"/"$ppp_pf" -m comment --comment "${tag} ${device}" -j ACCEPT
    fi
}

# To be called from /etc/ppp/ip-up, which is automatically executed when ppp interfaces go up
# Parameters: the ppp device name, the IP address of the ppp device
setup() {
    __create_chain
    __insert_rules "$@"
}

# To be called from /etc/ppp/ip-down, which is automatically executed when ppp interfaces go down
# Parameters: the ppp device name for which the route is to be deleted
teardown() {
    __clean_chain "$@"
}

