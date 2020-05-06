#!/bin/sh

# when the nginx .pem file is provisioned we can enable the firewall ipset rule

uci set firewall.wanapi_ipset.enabled=1
uci commit firewall

/etc/init.d/firewall reload
