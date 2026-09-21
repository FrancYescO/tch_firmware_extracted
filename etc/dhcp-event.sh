#!/bin/sh
. /usr/share/libubox/jshn.sh



#method is used to determine based on the VCI if the host connecting is a STB(substring match)
isSTB() {

local vendorclass=$1
local s1="ARRIS_VIP"
local s2="Motorola_VIP"

for i in $s1 $s2
do
	echo $vendorclass | grep $i > /dev/null && return 0
done

return 1
}

#Method to create the actual port forwarding rule in the firewall through UCI
create_firewall_rule(){
local ipaddress="$1"
logger -t dnsmasq "DEBUG: starting creation of firewall rules..."

#port calculation according to TEO specification
port_ssh=$((64000+`echo $ipaddress| cut -d"." -f4`))
port_log=$((65000+`echo $ipaddress| cut -d"." -f4`))

#if ports already exist (in case of a renewal) we dont do anything and exit
#uci show firewall | grep $port_ssh > /dev/null && return 0
#improvement form Kestutis (TEO  1/09/2015)
#if [ $(uci show firewall | grep STB_LOG_$port_log | wc -l) -gt 0 ] && [ $(uci show firewall | grep STB_SSH_$port_ssh | wc -l) -gt 0 ]; then return 0;fi

if [ $(uci show firewall | grep STB_LOG_$port_log | wc -l) -eq 0 ];
	then 
		#Creation of port forward for LOG
		#logger -t dnsmasq "DEBUG: LOG ENTRY MISSING, let's create"
		uci add firewall redirect
		uci set firewall.@redirect[-1]=redirect
		uci set firewall.@redirect[-1].dest_port=19999
		uci set firewall.@redirect[-1].dest='lan'
		uci set firewall.@redirect[-1].src='iptv'
		uci set firewall.@redirect[-1].proto='tcp'
		uci set firewall.@redirect[-1].enabled='1'
		uci set firewall.@redirect[-1].name="STB_LOG_$port_log"
		uci set firewall.@redirect[-1].src_dport=$port_log
		uci set firewall.@redirect[-1].family='ipv4'
		uci set firewall.@redirect[-1].target='DNAT'
		uci set firewall.@redirect[-1].dest_ip=$ipaddress
fi

if [ $(uci show firewall | grep STB_SSH_$port_ssh | wc -l) -eq 0 ];
			then
			#Creation of port forward for SSH
			#logger -t dnsmasq "DEBUG: SSH ENTRY MISSING, let's create"
			uci add firewall redirect
			uci set firewall.@redirect[-1]=redirect
			uci set firewall.@redirect[-1].dest_port=22
			uci set firewall.@redirect[-1].dest='lan'
			uci set firewall.@redirect[-1].src='iptv'
			uci set firewall.@redirect[-1].proto='tcp'
			uci set firewall.@redirect[-1].enabled='1'
			uci set firewall.@redirect[-1].name="STB_SSH_$port_ssh"
			uci set firewall.@redirect[-1].src_dport=$port_ssh
			uci set firewall.@redirect[-1].family='ipv4'
			uci set firewall.@redirect[-1].target='DNAT'
			uci set firewall.@redirect[-1].dest_ip=$ipaddress
fi

#Commit and apply changes
uci commit firewall
/etc/init.d/firewall reload

return 0

}

delete_firewall_rule(){
local ipaddress="$1"
logger -t dnsmasq "DEBUG: Deleting firewall rules..."

#port calculation according to TEO specification
port_ssh=$((64000+`echo $ipaddress| cut -d"." -f4`))
port_log=$((65000+`echo $ipaddress| cut -d"." -f4`))

#if for some reason ports are not present we do nothing
#uci show firewall | grep $port_ssh > /dev/null && logger -t dnsmasq "DEBUG: Deleting firewall rules starts now" || return 0

#delete the actual rules

if [ $(uci show firewall | grep STB_LOG_$port_log | wc -l) -gt 0 ];
	then
		uci del firewall.@redirect[`uci show firewall | grep "STB_LOG_$port_log" | sed 's:^.*\[::;s:\].*$::'`]
fi

if [ $(uci show firewall | grep STB_SSH_$port_ssh | wc -l) -gt 0 ];
	then 
		uci del firewall.@redirect[`uci show firewall | grep "STB_SSH_$port_ssh" | sed 's:^.*\[::;s:\].*$::'`]
fi

#Commit and apply changes
uci commit firewall
/etc/init.d/firewall reload

return 0

}

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
	
	if isSTB $DNSMASQ_VENDOR_CLASS; then logger -t dnsmasq "DEBUG: STB Detected. Start creating firewall rules."; else logger -t dnsmasq "DEBUG: Not a STB; not doing anything special";fi

	if isSTB $DNSMASQ_VENDOR_CLASS; then create_firewall_rule $3; else echo "Not a STB; not doing anything special";fi

    return 0
}

logger -t dnsmasq "DEBUG: Start of the DHCP event handler"

case "$1" in
    add|old)
		device_event add $2 $3 $4
		;;
    del)
		device_event delete $2 $3 $4
		delete_firewall_rule $3
		;;
	 *)
		isSTB $3
		logger -t dnsmasq "unknown dhcp script command: $1"
		;;
esac

logger -t dnsmasq "DEBUG: End of the DHCP event handler"