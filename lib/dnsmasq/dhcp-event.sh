#!/bin/sh
. /usr/share/libubox/jshn.sh

device_event() {
    local action="$1"
    local mac="$2"
    local ipaddress="$3"
    local name="$4"

    # Validate input
    [ -z "$mac" -o -z "$ipaddress" -o -z "$DNSMASQ_INTERFACE" ] && return 1

    json_init
    json_add_string "mac-address" $mac
    [ -n "$name" ] && json_add_string "hostname" $name
    json_add_object "ipv4-address"
    json_add_string "address" $ipaddress
    json_close_object
    json_add_string "interface" $DNSMASQ_INTERFACE
    json_add_string "action" $action
    json_add_object "dhcp"
    [ -n "$DNSMASQ_TIME_REMAINING" ] && json_add_int "time-remaining" $DNSMASQ_TIME_REMAINING
    [ -n "$DNSMASQ_LEASE_LENGTH" ] && json_add_int "lease-length" $DNSMASQ_LEASE_LENGTH
    [ -n "$DNSMASQ_LEASE_EXPIRES" ] && json_add_int "lease-expires" $DNSMASQ_LEASE_EXPIRES
    [ -n "$DNSMASQ_DOMAIN" ] && json_add_string "domain" $DNSMASQ_DOMAIN
    [ -n "$DNSMASQ_CLIENT_ID" ] && json_add_string "client-id" $DNSMASQ_CLIENT_ID
    [ -n "$DNSMASQ_VENDOR_CLASS" ] && json_add_string "vendor-class" $DNSMASQ_VENDOR_CLASS
    [ -n "$DNSMASQ_CPEWAN_OUI" ] && json_add_string "manufacturer-oui" "$DNSMASQ_CPEWAN_OUI"
    [ -n "$DNSMASQ_CPEWAN_SERIAL" ] && json_add_string "serial-number" "$DNSMASQ_CPEWAN_SERIAL"
    [ -n "$DNSMASQ_CPEWAN_CLASS" ] && json_add_string "product-class" "$DNSMASQ_CPEWAN_CLASS"
    [ -n "$DNSMASQ_OLD_HOSTNAME" ] && json_add_string "old-hostname" $DNSMASQ_OLD_HOSTNAME
    [ -n "$DNSMASQ_RELAY_ADDRESS" ] && {
	json_add_object "relay-address"
	json_add_string "address" $DNSMASQ_RELAY_ADDRESS
	json_close_object
    }
    [ -n "$DNSMASQ_TAGS" ] && json_add_string "tags" "$DNSMASQ_TAGS"
    [ -n "$DNSMASQ_REQUESTED_OPTIONS" ] && json_add_string "requested-options" "$DNSMASQ_REQUESTED_OPTIONS"
    json_close_object

    ubus send network.neigh "$(json_dump)"
    return 0
}

case "$1" in
     add|old)
	device_event add $2 $3 $4
	;;

    del)
	device_event delete $2 $3 $4
	;;

     *)
	logger -t dnsmasq "unknown dhcp script command: $1"
	;;
esac
