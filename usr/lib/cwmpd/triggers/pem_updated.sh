#!/bin/sh

# when the nginx .pem file is provisioned we can enable the firewall ipset rule

uci set firewall.wanapi_ipset.enabled=1
uci commit firewall

/etc/init.d/firewall reload

# notify ADB agent when pem file provisioned.
var=100; while true; do ps | grep -v grep | grep lighttpd > /dev/null && curl http://localhost:8889/accesscontrolchange && break; var=$((var - 1)); [ $var = 0 ] && break; sleep 5; done &
