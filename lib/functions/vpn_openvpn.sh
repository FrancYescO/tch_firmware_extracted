#!/bin/sh

. /lib/functions/vpn_common_inc.sh

act=$1

# parameters like: $intf $table 10.8.0.21 dev tun_c proto kernel scope link src 10.8.0.22
create_route_rule_in_table()
{
	local intf=$1
	local table=$2
	local via=$3
	local dev=$5
	local src=${11}

	[ "$intf" != "$dev" ] && return

	# this routing rule would be removed automatically once the interface is down
	ip route add default dev $dev via $via src $src table $table
}

each_openvpn_client()
{
	local name=$1
	local table=
	local enable=

	config_get enabled $name enabled "0"
	[ "$enabled" == "0" ] && return

	config_get table $name ip4table ""
	[ -z "$table" ] && return

	[ -z "$(cat /etc/iproute2/rt_tables | grep $table)" ] && return
	
	local t=$(ip route show | grep $intf)
	create_route_rule_in_table $intf $table $t

	ip route add default dev $intf 
}

handle_ssid_ass_openvpn_intf()
{
	local intf=$1

	. $IPKG_INSTROOT/lib/functions.sh

	config_load openvpn

	config_foreach each_openvpn_client openvpn
}

openvpn_intf_up()
{
	local intf=$1
        local type=$2
	[ "$(find_item_by_intf_in_list_file $intf)" == "1" ] && return

	if [ $type == "client" ]; then

		handle_ssid_ass_openvpn_intf $intf
		ins_ipt_wan_intf_rules $intf
	elif [ $type == "server" ]; then
		ins_ipt_lan_intf_rules $intf
	fi
	add_conn_to_list_file openvpn $type $@
}

openvpn_intf_down()
{
	local intf=$1
	local type=$2

	[ "$(find_item_by_intf_in_list_file $intf)" == "1" ] || return

	if [ $type == "client" ]; then
		rm_ipt_wan_intf_rules $intf
	elif [ $type == "server" ]; then
		rm_ipt_lan_intf_rules $intf
	fi
	rm_conn_by_intf_from_list_file $intf
}

openvpn_fw_reload()
{
	local intf=$(get_intf_in_item $@)
	local type=$(get_info_in_item $@)
	if [ $type == "client" ]; then
		ins_ipt_wan_intf_rules $intf
	elif [ $type == "server" ]; then
		ins_ipt_lan_intf_rules $intf
	fi
}

shift 1

[ "$act" == "IP_UP" ] && openvpn_intf_up $@
[ "$act" == "IP_DOWN" ] && openvpn_intf_down $@
[ "$act" == "FW_RELOAD" ] && openvpn_fw_reload $@

