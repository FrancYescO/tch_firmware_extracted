#!/bin/sh

mkdir -p /tmp/dnsmasq.d /tmp/dhcpopassthru.d
echo "dhcp-optsfile=/tmp/dhcpopassthru.d" > "/tmp/dnsmasq.d/dhcpopassthrud.conf"
