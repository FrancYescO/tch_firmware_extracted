#!/bin/sh
# Copyright (c) 2017 Technicolor
# remoteaccess integration for firewall3

. $IPKG_INSTROOT/lib/functions.sh

local DMZ_state
local state
local interface
local zone
local HTTP_port
local NGINX_port

#pseudo constants
local DMZ_HTTP_PORT="8080"

config_load "firewall"
config_get DMZ_state dmzredirects enabled 0

#check if service is enabled, if not skip
config_get state Allow_HTTP_Vodafone_wan target 'DROP'
if [ "$state" == 'ACCEPT' ];
then
   config_get interface Allow_HTTP_Vodafone_wan src 'wan'
   zone=$(fw3 -q network "$interface")
   config_get NGINX_port Allow_HTTP_Vodafone_wan dest_port 80
   if [ "$DMZ_state" -eq 1 ];
   then
      # Translate ports
      iptables -t nat -D zone_${zone}_prerouting -p tcp -m tcp -m set --match-set trusted_network src --dport $DMZ_HTTP_PORT -j REDIRECT --to-ports $NGINX_port -m comment --comment "Redirect_HTTP_DMZ"
      iptables -t nat -I zone_${zone}_prerouting 1 -p tcp -m tcp -m set --match-set trusted_network src --dport $DMZ_HTTP_PORT -j REDIRECT --to-ports $NGINX_port -m comment --comment "Redirect_HTTP_DMZ"
   fi
else
    echo -e "\e[31m HTTP not enabled on WAN $state \e[0m"
fi

