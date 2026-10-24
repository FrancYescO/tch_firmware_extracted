#!/bin/sh

#input env vars:
# RA_NAME : the name of the remote assistant (usually 'remote')
# ENABLED : if '1' assistance is enabled, otherwise disabled
# IFNAME : the name of the wan interface to use
# WAN_IP : the IP address on the wan interface
# WAN_PORT : the port number on the wan side
# LAN_PORT : the port the nginx server listens on for https traffic

# this script will not be called with either IFNAME or WAN_IP empty
. $IPKG_INSTROOT/lib/functions.sh

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

config_load ipset

trusted_ips=""
trusted_port="443"
count="0"
get_trusted_ips() {
  local cfg="$1"
  config_get ipset_type "$cfg" ipset
  if [ "$ipset_type" == "trusted_network" ]; then
    config_get ip "$cfg" ip
    count=$(( $count + 1 ))
    if [ $count -eq 1 ]; then
      trusted_ips="-s $ip"
    else
      trusted_ips="$trusted_ips,$ip"
    fi
  fi
}

config_foreach get_trusted_ips ipset_entry

FWD_RULE="-t nat $ACT prerouting_rule ! -i br-lan -m tcp -p tcp --dst $WAN_IP --dport $WAN_PORT -j REDIRECT --to-ports $LAN_PORT"
if [ "$WAN_PORT" != "$trusted_port" ]; then
  FWD_RULE_443="-t nat $ACT prerouting_rule ! -i br-lan -m tcp -p tcp $trusted_ips --dst $WAN_IP --dport $trusted_port -j REDIRECT --to-ports $LAN_PORT"
fi
ACCEPT_RULE="-t filter $ACT input_rule ! -i br-lan -p tcp --dst $WAN_IP --dport $LAN_PORT -j ACCEPT"

if [ "$WAN_PORT" != "$trusted_port" ] && [ "$LAN_PORT" != "$trusted_port" ]; then
  apply "$FWD_RULE_443"
fi
if [ "$LAN_PORT" != "$WAN_PORT" ]; then
  apply "$FWD_RULE"
fi
if [ "$WAN_PORT" != "$trusted_port" ] && [ "$LAN_PORT" != "$trusted_port" ] || [ "$LAN_PORT" != "$WAN_PORT" ]; then
  apply "$FWD_NULL"
fi
apply "$ACCEPT_RULE"
