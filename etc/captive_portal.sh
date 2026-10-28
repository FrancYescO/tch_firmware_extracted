#!/bin/sh
# Copyright (c) 2017 Technicolor

# get helper functions (config_*)
. $IPKG_INSTROOT/lib/functions.sh

# define constants
CAPPORT_CHAIN=CapPort
LAN_ZONE_PRE=zone_lan_prerouting
LAN_ZONE_FWD=zone_lan_forward
LAN_ZONE_INP=zone_lan_input
HTTP_PORT=80
HTTPS_PORT=443
DEFAULT_HTTP_REDIRECT_PORT=8086
DEFAULT_HTTPS_REDIRECT_PORT=8087
DEFAULT_REDIRECT_URL="http://localhost"

#define variables
local httpRedirectPort
local httpsRedirectPort
local gatewayIP
local captivePortalEnabled

doIp4Tables()
{
  iptables $* -m comment --comment "!fw3: Captive Portal"
}

doIp6Tables()
{
  ip6tables $* -m comment --comment "!fw3: Captive Portal"
}

doIpTables()
{
  doIp4Tables $*
  doIp6Tables $*
}

# $1 is zone, $2 is port(s)
openPorts()
{
  doIp4Tables -A $1 -j ACCEPT -p tcp -m tcp --dport $2
}

# $1 is zone, $2 is port(s)
closePorts()
{
  doIp4Tables -A $1 -j REJECT --reject-with tcp-reset -p tcp -m state --state NEW,ESTABLISHED --dport $2
}

# $1 is zone, $2 is port(s)
flushPorts()
{
  doIp4Tables -D $1 -j ACCEPT -p tcp -m tcp --dport $2 2>/dev/null
  doIp4Tables -D $1 -j REJECT --reject-with tcp-reset -p tcp -m state --state NEW,ESTABLISHED --dport $2 2>/dev/null
}

# $1 is input zone, $2 is port(s)
cleanChains()
{
  # delete(-D) references to the chains
  doIpTables  -t filter -D ${LAN_ZONE_FWD} -j ${CAPPORT_CHAIN} 2>/dev/null
  doIp4Tables -t nat    -D ${LAN_ZONE_PRE} -j ${CAPPORT_CHAIN} 2>/dev/null

  # flush(-F) and delete(-X) the chains
  doIpTables  -t filter -F ${CAPPORT_CHAIN} 2>/dev/null
  doIpTables  -t filter -X ${CAPPORT_CHAIN} 2>/dev/null
  doIp4Tables -t nat    -F ${CAPPORT_CHAIN} 2>/dev/null
  doIp4Tables -t nat    -X ${CAPPORT_CHAIN} 2>/dev/null
}

# create and link the chains
createChains()
{
  # create(-N) the chains
  doIpTables  -t filter -N ${CAPPORT_CHAIN}
  doIp4Tables -t nat    -N ${CAPPORT_CHAIN}

  # insert(-I) links(-j) to the chains into zones
  doIpTables  -t filter -I ${LAN_ZONE_FWD} -j ${CAPPORT_CHAIN}
  doIp4Tables -t nat    -I ${LAN_ZONE_PRE} -j ${CAPPORT_CHAIN}
}

#
# main()
#

# load captive_portal UCI configuration
config_load captive_portal

# get the enable attribute
config_get captivePortalEnabled global enable "0"

# if the captive portal is not enabled, then just return (do nothing)
if [ "${captivePortalEnabled}" != "1" ]; then
    echo "CaptivePortal not enabled, ignoring"
    flushPorts ${LAN_ZONE_INP} "${httpRedirectPort}:${httpsRedirectPort}"
    closePorts ${LAN_ZONE_INP} "${httpRedirectPort}:${httpsRedirectPort}"
    cleanChains
    return
fi

# get other captive portal attributes
config_get httpRedirectPort  global http_redirect_port  ${DEFAULT_HTTP_REDIRECT_PORT}
config_get httpsRedirectPort global https_redirect_port ${DEFAULT_HTTPS_REDIRECT_PORT}
config_get redirectURL       global redirect_url        ${DEFAULT_REDIRECT_URL}

# clean the chains.. This is not strictly neccesary since the chains are not present
# when called from firewall, but enables the script to be called in other contexts
flushPorts ${LAN_ZONE_INP} "${httpRedirectPort}:${httpsRedirectPort}"
closePorts ${LAN_ZONE_INP} "${httpRedirectPort}:${httpsRedirectPort}"

cleanChains

# create the chains.  This will create the CapPort chains on the nat and filter tables and create
# the links to them from the zone_lan_prerouting and zone_lan_forward zones, respectively.
createChains

# allow the dnat'd packets to get to local http server
openPorts ${LAN_ZONE_INP} "${httpRedirectPort}:${httpsRedirectPort}"

# allow all packets for allowed IPs to be processed as normal
allowIP()
{
  doIpTables  -t filter -A ${CAPPORT_CHAIN} --dest $1 -j RETURN
  doIp4Tables -t nat    -A ${CAPPORT_CHAIN} --dest $1 -j RETURN
}
config_list_foreach global allowed_ip allowIP

# get the ip address of the LAN from the network UCI config
config_load network
config_get gatewayIP lan ipaddr "192.168.0.1"

# allow packets destined to the gateway using ipv4 to pass, drop all others
doIp4Tables -t filter -A ${CAPPORT_CHAIN} --dest ${gatewayIP} -j RETURN
doIpTables  -t filter -A ${CAPPORT_CHAIN} -j DROP

# allow packets destined to the gateway to pass, DNAT HTTP and HTTPS ports
doIp4Tables -t nat -A ${CAPPORT_CHAIN} --dest ${gatewayIP} -j RETURN
doIp4Tables -t nat -A ${CAPPORT_CHAIN} -p tcp --dport ${HTTP_PORT}  -j DNAT --to-destination ${gatewayIP}:${httpRedirectPort}
doIp4Tables -t nat -A ${CAPPORT_CHAIN} -p tcp --dport ${HTTPS_PORT} -j DNAT --to-destination ${gatewayIP}:${httpsRedirectPort}
