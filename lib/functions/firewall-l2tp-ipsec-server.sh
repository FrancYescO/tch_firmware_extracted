#!/bin/sh
# Copyright (C) 2015 Technicolor Delivery Technologies, SAS

. $IPKG_INSTROOT/lib/functions.sh

local chain="l2tp_ipsec"
local targetchain="zone_wan_input"

# Helper function which deletes and flushes all of our chains
__clean_chain() {
    # Silently delete from targetchain
    iptables -D ${targetchain} -j ${chain} 2>/dev/null

    # Then flush and delete chain itself
    iptables -F ${chain} 2>/dev/null
    iptables -X ${chain} 2>/dev/null
}


# Helper function which creates the chain and inserts it into the target chain
__create_chain() {
    iptables -N ${chain}
    iptables -I ${targetchain} -j ${chain}
}

# Helper function which inserts the actual rules that are required to be able to establish the L2TP/IPSec connection
__insert_rules() {
    # Observe order of following 2 rules to guarantee acceptance of encrypted l2tp traffic
    iptables -I $chain -p udp --dport 1701 -m comment --comment "Deny unencrypted L2TP traffic" -j "DROP"
    iptables -I $chain -p udp -m policy --dir in --pol ipsec -m udp --dport 1701 -m comment --comment "Allow encrypted L2TP traffic" -j "ACCEPT"

    iptables -I $chain -p udp --dport 500 -m comment --comment "IPSec IKE" -j "ACCEPT"
    iptables -I $chain -p udp --dport 4500 -m comment --comment "IPSec NAT-T" -j "ACCEPT"

    iptables -I $chain -p esp -m comment --comment "IPSec ESP" -j "ACCEPT"
}

# Entry point function which calls the helpers and sets up the firewall according to 'enabled' flag of the l2tpipsecserver
# Ports must only be open if the server is enabled.
setup() {
    __clean_chain

    if [ "$(uci_get_state vpn state l2tpipsecserver_active 0)" == 1 ]; then
        __create_chain
        __insert_rules
    fi
}

setup

