#!/bin/sh

mkdir -p /tmp/dnsmasq.d /etc/dhcpopassthru.d
echo "dhcp-optsfile=/etc/dhcpopassthru.d" > "/tmp/dnsmasq.d/dhcpopassthrud.conf"
