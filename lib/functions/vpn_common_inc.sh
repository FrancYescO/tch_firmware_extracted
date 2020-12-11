#!/bin/sh

comment_prefix="VPN_COMMON"
vpn_intf_list_file="/var/vpn_conn_list"
vpn_intf_list_file_tmp="${vpn_intf_list_file}_tmp"

proto_list="pptp l2tp openvpn"

field_seq="=="


# proto handler script should be like /lib/functions/vpn_${proto}.sh
# check proto value in proto_list
proto_handler_prefix="/lib/functions/vpn"
proto_handler_postfix=".sh"



# insert rule in given chain beside the LAN or WAN interface rule
# zone = lan/wan
# chain = input/output/forward
get_rule_pos_in_chain()
{
	local zone=$1
	local chain=$2
	local table=$3
	local intf

	. $IPKG_INSTROOT/lib/functions/network.sh

	[ -z "$zone" -o -z "$chain" ] && return

	network_get_device intf $zone

	[ -z "$intf" ] && return

	local t=$(iptables -t $table -L delegate_$chain  -v -n --line-number | grep $intf)
	t="${t/\*/--}"
	[ -z "$t" ] && return
	local pos=$(echo $t | cut -f1 -d$' ')

	local in_out=$(echo $t | awk '{print $7}')
	[ "$in_out" == "$intf" ] && { echo $((pos+1)) "i"; return; }

	in_out=$(echo $t | awk '{print $8}')
	[ "$in_out" == "$intf" ] && { echo $((pos+1)) "o"; return; }
}

# insert rule in given chain beside the LAN or WAN interface rule
# zone = lan/wan
# chain = input/output/forward
# intf
ins_rule_in_chain()
{
	local zone=$1
	local chain=$2
	local intf=$3
	local table=$4

	[ -z "$table" ] && table="filter"

	local t=$(get_rule_pos_in_chain $zone $chain $table)

	local pos=$(__get_first_in_line $t)
	local in_out=$(echo $t | awk '{print $2}')

	[ -z "$pos" -o -z "$in_out" ] && return

	iptables -t $table -I delegate_$chain $pos -m comment --comment ${comment_prefix}_${zone}_${intf} -${in_out} $intf -j zone_${zone}_${chain}
}

rm_rule_in_chain()
{
	local zone=$1
	local chain=$2
	local intf=$3
	local table=$4

	[ -z "$table" ] && table="filter"

	iptables-save -t $table | grep ${comment_prefix}_${zone}_${intf} | grep zone_${zone}_${chain}  | while read LINE
	do
		# skip -A
		t=${LINE:2}

		iptables -t $table -D $t   2>/dev/null
	done
}

# ins_ipt_filter_zone_intf_rules zone intf {chain_names}
ins_ipt_filter_zone_intf_rules()
{
	local zone=$1
	local intf=$2

	[ -z "$intf" -o -z "$zone" ] && return

	# remove $1 and $2, and keep chain names in $@
	shift 2

	for t in $@
	do
		[ "$t" == "input" ] && ins_rule_in_chain $zone input $intf
		[ "$t" == "output" ] && ins_rule_in_chain $zone output $intf
		[ "$t" == "forward" ] && ins_rule_in_chain $zone forward $intf
	done
	iptables -I zone_${zone}_dest_ACCEPT  -m comment --comment ${comment_prefix}_${zone}_${intf} -o $intf -j ACCEPT

	if [ "$zone" == "wan" ]
	then
		iptables -I zone_wan_dest_DROP  -m comment --comment ${comment_prefix}_${zone}_${intf} -o $intf -j DROP
		iptables -I zone_wan_src_DROP -m comment --comment ${comment_prefix}_${zone}_${intf} -i $intf -j DROP
	elif [ "$zone" ==  "lan" ]
	then
		iptables -I zone_lan_src_ACCEPT  -m comment --comment ${comment_prefix}_${zone}_${intf} -i $intf -j ACCEPT
	fi
}

# rm_ipt_filter_zone_intf_rules zone intf {chain_names}
rm_ipt_filter_zone_intf_rules()
{
	local zone=$1
	local intf=$2

	[ -z "$intf" -o -z "$zone" ] && return

	# remove $1 and $2, and keep chain names in $@
	shift 2

	for t in $@
	do
		[ "$t" == "input" ] && rm_rule_in_chain $zone input $intf
		[ "$t" == "output" ] && rm_rule_in_chain $zone output $intf
		[ "$t" == "forward" ] && rm_rule_in_chain $zone forward $intf
	done
	rm_rule_in_chain $zone dest_ACCEPT $intf

	if [ "$zone" == "wan" ]
	then
		rm_rule_in_chain $zone dest_DROP $intf
		rm_rule_in_chain $zone src_DROP $intf
	elif [ "$zone" ==  "lan" ]
	then
		rm_rule_in_chain $zone src_ACCEPT $intf
	fi
}


rm_ipt_nat_zone_intf_rules()
{
	local zone=$1
	local intf=$2

	[ -z "$intf" -o -z "$zone" ] && return

	# remove $1 and $2, and keep chain names in $@
	shift 2

	for t in $@
	do
		[ "$zone" == "lan" ] && [ "$t" == "prert" ] && rm_rule_in_chain $zone prerouting $intf nat
		[ "$t" == "postrt" ] && rm_rule_in_chain $zone postrouting $intf nat
	done
}


ins_ipt_nat_zone_intf_rules()
{
	local zone=$1
	local intf=$2

	[ -z "$intf" -o -z "$zone" ] && return

	# remove $1 and $2, and keep chain names in $@
	shift 2

	for t in $@
	do
		[ "$zone" == "lan" ] && [ "$t" == "prert" ] && ins_rule_in_chain $zone prerouting $intf nat
		[ "$t" == "postrt" ] && ins_rule_in_chain $zone postrouting $intf nat
	done
}



# iptables rule operation functions
# ins_ipt_lan_intf_rules intf forward inout output
ins_ipt_lan_intf_rules()
{
	ins_ipt_filter_zone_intf_rules lan $@ input output forward
	ins_ipt_nat_zone_intf_rules lan $@ prert postrt
}

rm_ipt_lan_intf_rules()
{
	rm_ipt_filter_zone_intf_rules lan $@ input output forward
	rm_ipt_nat_zone_intf_rules lan $@ prert postrt
}

ins_ipt_wan_intf_rules()
{
	ins_ipt_filter_zone_intf_rules wan $@ input output forward
	ins_ipt_nat_zone_intf_rules wan $@ prert postrt
}

rm_ipt_wan_intf_rules()
{
	rm_ipt_filter_zone_intf_rules wan $@ input output forward
	rm_ipt_nat_zone_intf_rules wan $@ prert postrt
}

create_list_file()
{
	[ -f $vpn_intf_list_file ] && return

	touch $vpn_intf_list_file
	chmod 644 $vpn_intf_list_file
}

# conn list filer operation functions
add_conn_to_list_file()
{
	local proto=$1
	local info=$2
	local intf=$3
	local tty_dev=$4
	local speed=$5
	local local_ip=$6
	local remote_ip=$7
	local ipparam=$8

	[ "$(find_item_by_intf_in_list_file $intf)" == "1" ] && rm_item_by_intf_in_list_file $intf

	create_list_file
	# template of each line is $proto == $info == $intf $tty_dev $speed $local_ip $remote_ip $ipparam
	echo $proto == $info == $intf $tty_dev $speed $local_ip $remote_ip $ipparam  >> $vpn_intf_list_file
}


get_proto_in_item()
{
	echo $1
}

get_info_in_item()
{
	echo $@ | awk -F "$field_seq"  '{print $2}'
}

__get_first_in_line()
{
	echo $1
}

get_params_in_item()
{
	echo $@ | awk -F "$field_seq" '{print $3}'
}

get_intf_in_item()
{
	local params=$(echo $@ | awk -F "$field_seq" '{print $3}')
	__get_first_in_line $params
}

find_item_by_intf_in_list_file()
{
	local intf=$1

	local item=$(get_item_by_intf_in_list_file $intf)

	[ -n "$item" ] && { echo 1; return; }
	echo 0
}

get_item_by_intf_in_list_file()
{
	local intf=$1

	[ -f $vpn_intf_list_file ] || return

	cat $vpn_intf_list_file | while read LINE
	do
		[ "$(get_intf_in_item $LINE)" == "$intf" ] && { echo $LINE; return; }
	done
}

rm_conn_by_intf_from_list_file()
{
	local intf=$1

	[ -f $vpn_intf_list_file ] || return

	mv $vpn_intf_list_file $vpn_intf_list_file_tmp
	create_list_file

	cat $vpn_intf_list_file_tmp | while read LINE
	do
		[ "$(get_intf_in_item $LINE)" != "$intf" ] && echo $LINE >> $vpn_intf_list_file
	done

	rm $vpn_intf_list_file_tmp
}

call_handler()
{
	local proto=$1

	for t in $proto_list
	do
		if [ "$t" == "$proto" -a -f ${proto_handler_prefix}_${proto}${proto_handler_postfix} ]
		then
			shift 1
			${proto_handler_prefix}_${proto}${proto_handler_postfix} $@
			return
		fi
	done
}

find_proto()
{
	local proto=$1

	for t in $proto_list
	do
		[ "$t" == "$proto" -a -f ${proto_handler_prefix}_${proto}${proto_handler_postfix} ] && { echo $proto; return; }
	done
}

firewall_reload_cb()
{
	local proto

	[ -f $vpn_intf_list_file ] || return

	cat $vpn_intf_list_file | while read LINE
	do
		proto=$(get_proto_in_item $LINE)
		# remove "proto" and "==" in item string
		call_handler $proto FW_RELOAD $LINE
	done
}


ip_up_cb()
{
	local proto=$1

	shift 1

	call_handler $proto IP_UP $@
}

ip_down_cb()
{
	local intf=$1
	local item=$(get_item_by_intf_in_list_file $intf)

	[ -z "$item" ] && return

	local proto=$(get_proto_in_item $item)

	call_handler $proto IP_DOWN $@
}

each_network_intf()
{
	name=$1

	config_get proto "$name" proto ""

	if [ "$proto" == "pptp" -o "$proto" == "l2tp" ]
	then
		config_get auto "$name" auto "1"
		[ "$auto" == "1" ] && return

		. $IPKG_INSTROOT/lib/functions/network.sh

		network_is_up $name && ifdown $name
	fi
}

check_vpn_intf_before_network_ca()
{
	. $IPKG_INSTROOT/lib/functions.sh

	config_load network

	config_foreach each_network_intf interface
}

reset_def_route_as_wan()
{
	local vpn_intf=$1
	local waniface="wan"
	local cur_dev
	local device
	local gateway

	. $IPKG_INSTROOT/lib/functions/network.sh

	network_get_device device $vpn_intf
	cur_dev=$(ip -4 route |grep ^default | awk '{print $5}')
	[ -z "$cur_dev" ] && return
	[ "$cur_dev" != "$device" ] && return

	network_get_gateway gateway $waniface
	network_get_device device $waniface
	[ -n "$gateway" ] && [ -n "$device" ] && route add default gw $gateway dev $device
}

