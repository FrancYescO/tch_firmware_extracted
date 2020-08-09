#!/bin/sh

# (C) 2016 NETDUMA Software <iainf@netduma.com>
#
# For all intensive purposes user chains are owned by AA R-App. So
# the term user-chain is interchangealbe with AA chain.
#
# fw3 purpose is to apply zone policy and integrate with UCI. Zones
# don't have any mangling needs so there are no user mangle chains.
# 
# This script adds any custom chains and links them to the appriopiate
# table and hook. Note that AA will also create the chains as it 
# may have requests to populate them. But AA will never jump to the chain
# that is the purpose of this script. 

# create the chains, ignore errors as could have been created by this
# script earlier on or by AA.

# create all user chains
iptables -w -t mangle -N prerouting_mangle
iptables -w -t mangle -N forward_mangle
iptables -w -t mangle -N postrouting_mangle
iptables -w -t mangle -N input_mangle
iptables -w -t mangle -N output_mangle
iptables -w -t nat -N prerouting_rule
iptables -w -t nat -N postrouting_rule
iptables -w -t filter -N input_rule
iptables -w -t filter -N forwarding_rule
iptables -w -t filter -N output_rule

# Jump to userchains. Delete first to avoid ever having duplicates
iptables -w -t mangle -D FORWARD -j forward_mangle
iptables -w -t mangle -I FORWARD 1 -j forward_mangle
iptables -w -t mangle -D POSTROUTING -j postrouting_mangle
iptables -w -t mangle -I POSTROUTING 1 -j postrouting_mangle
iptables -w -t mangle -D PREROUTING -j prerouting_mangle
iptables -w -t mangle -I PREROUTING 1 -j prerouting_mangle

# This will cause deadlock see comment in on_firewall_restart
#ubus send firewall_restart '{}'

# if rules already exist it is still a success to us
exit 0
