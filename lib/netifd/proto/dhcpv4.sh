#!/bin/sh

[ -x /usr/sbin/odhcpc ] || exit 0

. /lib/functions.sh
. ../netifd-proto.sh
init_proto "$@"

proto_dhcp_init_config() {
	renew_handler=1

	proto_config_add_string 'ipaddr:ipaddr'
	proto_config_add_string 'netmask:netmask'
	proto_config_add_string 'ipaddr_bkup:ipaddr'
	proto_config_add_string 'netmask_bkup:netmask'
	proto_config_add_string 'hostname:hostname'
	proto_config_add_string clientid
	proto_config_add_string vendorid
	proto_config_add_boolean 'broadcast:bool'
	proto_config_add_boolean 'release:bool'
	proto_config_add_string 'reqopts:list(string)'
	proto_config_add_boolean 'defaultreqopts:bool'
	proto_config_add_string iface6rd
	proto_config_add_array 'sendopts:list(string)'
	proto_config_add_boolean delegate
	proto_config_add_string zone6rd
	proto_config_add_string zone
	proto_config_add_string mtu6rd
	proto_config_add_string customroutes
	proto_config_add_boolean 'arping:bool'
	proto_config_add_boolean 'initboot:bool'
	proto_config_add_boolean 'vendorinfolenfix:bool'
	proto_config_add_boolean 'noforcerenew:bool'
	proto_config_add_boolean classlessroute
}

proto_dhcp_add_sendopts() {
	[ -n "$1" ] && append "$3" "-x $1"
}

proto_dhcp_setup() {
	local config="$1"
	local iface="$2"

	local ipaddr ipaddr_bkup netmask_bkup hostname clientid vendorid broadcast release reqopts defaultreqopts iface6rd sendopts delegate zone6rd zone mtu6rd customroutes arping initboot vendorinfolenfix noforcerenew classlessroute
	json_get_vars ipaddr ipaddr_bkup netmask_bkup hostname clientid vendorid broadcast release reqopts defaultreqopts iface6rd delegate zone6rd zone mtu6rd customroutes arping initboot vendorinfolenfix noforcerenew classlessroute

	local opt dhcpopts
	for opt in $reqopts; do
		append dhcpopts "-O $opt"
	done

	json_for_each_item proto_dhcp_add_sendopts sendopts dhcpopts

	[ -z "$hostname" ] && hostname="$(cat /proc/sys/kernel/hostname)"
	[ "$defaultreqopts" = 0 ] && defaultreqopts="-o" || defaultreqopts=
	[ "$broadcast" = 1 ] && broadcast="-B" || broadcast=
	[ "$release" = 1 ] && release="-R" || release=
	[ -n "$clientid" ] && clientid="-x 0x3d:${clientid//:/}" || clientid="-C"
	[ -n "$iface6rd" ] && proto_export "IFACE6RD=$iface6rd"
	[ "$iface6rd" != 0 -a -f /lib/netifd/proto/6rd.sh ] && append dhcpopts "-O 212"
	[ -n "$zone6rd" ] && proto_export "ZONE6RD=$zone6rd"
	[ -n "$zone" ] && proto_export "ZONE=$zone"
	[ -n "$mtu6rd" ] && proto_export "MTU6RD=$mtu6rd"
	[ -n "$customroutes" ] && proto_export "CUSTOMROUTES=$customroutes"
	[ "$delegate" = "0" ] && proto_export "IFACE6RD_DELEGATE=0"
	[ "$arping" = 1 ] && arping="-a" || arping=
	[ "$initboot" = 1 ] && initboot="-I /etc/odhcpc-$iface.ip" || initboot=
	[ "$vendorinfolenfix" = 1 ] && vendorinfolenfix="-l" || vendorinfolenfix=
	[ "$noforcerenew" = 1 ] && noforcerenew="-N" || noforcerenew=
	# Request classless route option (see RFC 3442) by default
	[ "$classlessroute" = "0" ] || append dhcpopts "-O 121"

	proto_export "INTERFACE=$config"
	proto_run_command "$config" odhcpc \
		-p /var/run/odhcpc-$iface.pid \
		-s /lib/netifd/dhcp.script \
		-f -t 0 -i "$iface" \
		${ipaddr:+-r $ipaddr} \
		${ipaddr_bkup:+--dhcp_backup_ip $ipaddr_bkup} \
		${netmask_bkup:+--dhcp_backup_subnet $netmask_bkup} \
		${hostname:+-x "hostname:$hostname"} \
		${vendorid:+-V "$vendorid"} \
		$clientid $broadcast $release $dhcpopts \
		$arping $initboot $vendorinfolenfix $noforcerenew
}

proto_dhcp_renew() {
	local interface="$1"
	# SIGUSR1 forces odhcpc to renew its lease
	local sigusr1="$(kill -l SIGUSR1)"
	[ -n "$sigusr1" ] && proto_kill_command "$interface" $sigusr1
}

proto_dhcp_teardown() {
	local interface="$1"
	proto_kill_command "$interface"
}

add_protocol dhcp
