#!/bin/sh

#input env vars:
# RA_NAME : the name of the remote assistant (usually 'remote')
# ENABLED : if '1' assistance is enabled, otherwise disabled
# IFNAME : the name of the wan interface to use
# WAN_IP : the IP address on the wan interface
# WAN_PORT : the port number on the wan side
# LAN_PORT : the port the nginx server listens on for https traffic

# this script will not be called with either IFNAME or WAN_IP empty

apply()
{
  local RULE=$1
  logger -t assist.$RA_NAME -- $RULE
  iptables $RULE
}

if [ "$ENABLED" = "1" ]; then
  ACT="-I"
else
  ACT="-D"
fi

local FWD_RULE="-t nat $ACT prerouting_rule -m tcp -p tcp --dst $WAN_IP --dport $WAN_PORT -j REDIRECT --to-ports $LAN_PORT"
local FWD_NULL="-t nat $ACT prerouting_rule -p tcp --dst $WAN_IP --dport $LAN_PORT -j REDIRECT --to-port 65535"
local ACCEPT_RULE="-t filter $ACT input_rule -p tcp --dst $WAN_IP --dport $LAN_PORT -j ACCEPT"

if [ "$LAN_PORT" != "$WAN_PORT" ]; then
  apply "$FWD_RULE"
  apply "$FWD_NULL"
fi
apply "$ACCEPT_RULE"
