#!/bin/sh
# Copyright (c) 2016 Technicolor
# WAN to LAN access manager

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/functions/network.sh

ct_base_name=ct_dmz_portmap
mark_value_bit_base=0x100000   # from bit 20 on
mark_value_bit_width=5    # bit 24 - 20, up to 14 services and one DMZ
nf_conn_list_file=/proc/net/nf_conntrack


ct_mark_chain_name=${ct_base_name}_mark
ct_check_chain_name=${ct_base_name}_check
access_list_file=/var/${ct_base_name}_list

tmp=$((mark_value_bit_width-1))
tmp=$((1<<tmp))
dmz_mark_value=$((tmp*mark_value_bit_base))


tmp=$((1<<mark_value_bit_width))
tmp=$((tmp-1))
mark_mask_value=$((tmp*mark_value_bit_base))     # this highest bit of these bits is the DMZ mark bit

mark_value_start=1
last_mark_value=$((mark_value_start-1))

tmp=$((mark_value_bit_width-1))
tmp=$((1<<tmp))
mark_value_end=$((tmp-1))

portmap_mark_mask_value=$((mark_mask_value^dmz_mark_value))     # the rest bits for port mappings


mark_value_list_tmp=
mark_value_list=
black_list=
dmz_enabled=0
userredirect_enabled=0

arg_redir_each_dest_port=
arg_redir_each_dest_ip=
arg_mark_value=

wan_intf=

insert_service_rules () {
	local lan_host=$1
	local lan_port=$2
	local proto=$3
	local mark_value=$4

	lan_port=${lan_port/-/:}

	iptables -t mangle -A $ct_mark_chain_name -p $proto -d $lan_host --dport $lan_port -j CONNMARK --set-xmark ${mark_value}/$mark_mask_value

	iptables -t mangle -A $ct_check_chain_name -m connmark --mark ${mark_value}/$portmap_mark_mask_value -d $lan_host -j ACCEPT
	iptables -t mangle -A $ct_check_chain_name -m connmark --mark ${mark_value}/$portmap_mark_mask_value -s $lan_host -j ACCEPT
}

# check dmzredirect
dmzredirect_each () {
	local cfg="$1"
	local name=
	local dmz_host=

	config_get name "$cfg" name
	if [ "DMZ rule" = "$name" ]; then
		config_get dmz_host "$cfg" dest_ip

		iptables -t mangle -A $ct_mark_chain_name -d $dmz_host -j CONNMARK --set-xmark ${dmz_mark_value}/${dmz_mark_value}

		iptables -t mangle -A $ct_check_chain_name -m connmark --mark ${dmz_mark_value}/$dmz_mark_value -d $dmz_host -j ACCEPT
		iptables -t mangle -A $ct_check_chain_name -m connmark --mark ${dmz_mark_value}/$dmz_mark_value -s $dmz_host -j ACCEPT
	fi

	echo [DMZ]"$(get_portmap_keyword $dmz_host)"$((dmz_mark_value/mark_value_bit_base)) >> $access_list_file
}

userredirect_each_proto () {
	local proto=$1

	if [ "$proto" == "tcpudp" -o "$proto" == "tcp" ]
	then
		insert_service_rules $arg_redir_each_dest_ip $arg_redir_each_dest_port tcp $arg_mark_value
	fi

	if [ "$proto" == "tcpudp" -o "$proto" == "udp" ]
	then
		insert_service_rules $arg_redir_each_dest_ip $arg_redir_each_dest_port udp $arg_mark_value
	fi
}

get_new_mark_value () {
	local keyword=$1
	local mark_value=

	# check if pre-assigned for this service, use same mark value as before
	mark_value=$(get_mark_value_in_mark_value_list $keyword)

	[ -n "$mark_value" ] && { echo $mark_value $last_mark_value; return; }

	last_mark_value=$((last_mark_value+1))
	while [ $last_mark_value -le $mark_value_end ]
	do
		# check if this mark value in black list
		find_mark_value_in_black_list $last_mark_value && { last_mark_value=$((last_mark_value+1)); continue; }

		# check if this mark value in pre-assign list
		find_mark_value_in_list $last_mark_value && { last_mark_value=$((last_mark_value+1)); continue; }

		echo $last_mark_value $last_mark_value
		return
	done

	# no avaliable mark value found when reach here
	echo 0 $last_mark_value
}

split_mark_values () {
	mark_value=$1
	last_mark_value=$2
}

# check userredirect
userredirect_each () {
	local cfg="$1"
	local enabled=
	local name=
	local proto=
	local keyword=
	local mark_value=

	config_get enabled "$cfg" enabled "1"
	[ "$enabled" -eq "1" ] || return

	config_get name "$cfg" name

	config_get arg_redir_each_dest_ip "$cfg" dest_ip
	config_get arg_redir_each_dest_port "$cfg" dest_port
	config_get proto "$cfg" proto

	keyword=$(get_portmap_keyword $arg_redir_each_dest_ip $proto $arg_redir_each_dest_port)
	split_mark_values $(get_new_mark_value $keyword)

	[ "$mark_value" == "0" ] && return    # no mark value available, skip this service

	arg_mark_value=$((mark_value*mark_value_bit_base))
	config_list_foreach "$cfg" "proto" userredirect_each_proto

	echo [$name]${keyword}${mark_value} >> $access_list_file
}

# records in list file are like below:
# [name]+host+proto+port+mark_value
load_list_file () {
	[ ! -f $access_list_file ] && return

	mark_value_list=$(cat $access_list_file)
	> $access_list_file
}

get_rec_in_mark_value_list () {
	local keyword=$1
	local t=

	for t in $mark_value_list
	do
		if [ "${t/$keyword//}" != $t ]
		then
			# matched
			echo $t
			return
		fi
	done
}

get_mark_value_in_mark_value_list () {
	local keyword=$1
	local rec=$(get_rec_in_mark_value_list $keyword)

	[ -n "$rec" ] && echo $(echo $rec | awk -F "+" '{print $5}')
}

find_mark_value_in_list () {
	local t=
	local mark_value=$1
	local value=

	for t in $mark_value_list
	do
		value=$(echo $t | awk -F "+" '{print $5}')
		[ "$value" == "$mark_value" ] && return 0
	done
	return 1
}

get_portmap_keyword () {
	local host=$1
        local proto=$2
        local port=$3

	echo "+${host}+${proto}+${port}+"
}

get_portmap_keyword_by_name () {
        local cfg=$1
	local host=
	local proto=
	local port=

	config_get port "$cfg" dest_port
	config_get host "$cfg" dest_ip
	config_get proto "$cfg" proto

        get_portmap_keyword $host $proto $port
}

pre_userredirect_each () {
        local cfg="$1"
	local keyword=
	local name=
	local mark_value=

        config_get enabled "$cfg" enabled "1"
        [ "$enabled" -eq "1" ] || return

	config_get name "$cfg" name
	keyword=$(get_portmap_keyword_by_name "$cfg")
	mark_value=$(get_mark_value_in_mark_value_list $keyword)

	[ -z "$mark_value" ] && return

	mark_value_list_tmp="[${name}]${keyword}${mark_value} $mark_value_list_tmp"
}


pre_upd_mark_value_list () {
	[ "$userredirect_enabled" -eq 0 ] && return

	config_foreach pre_userredirect_each userredirect
	mark_value_list=$mark_value_list_tmp    # all port mappings are in this list, which is enabled before and after firewall reload
	mark_value_list_tmp=
}



# the mark values in black list are:
# 1. the connection not end yet
# 2. with mark bit set by this module
# 3. the correspending service is stopped already/not enabled right now
load_black_list () {
	local t=
	local mark_list=
	local mark_value=

	t=$(cat $nf_conn_list_file | sed -n 's/.*mark=\([0-9]*\).*/\1/p')
	for mark_value in $t
	do
		mark_value=$((mark_value&portmap_mark_mask_value))
		[ $mark_value -eq 0 ] && continue
		mark_value=$((mark_value/mark_value_bit_base))

		find_mark_value_in_list $mark_value || echo $mark_value
	done
}

find_mark_value_in_black_list () {
	local mark_value=$1
	local t=

	for t in $black_list
	do
		[ $t -eq $mark_value ] && return 0
	done
	return 1
}

config_load "firewall"

network_get_device  wan_intf wan
[ -z "$wan_intf" ] && exit 0

config_get dmz_enabled dmzredirects enabled 0
config_get userredirect_enabled userredirects enabled 0

# load the service/mark value list file of the last config to mark value list
load_list_file

# update the mark value list to remove already disabled service
pre_upd_mark_value_list

black_list=$(load_black_list)

if iptables -t mangle -N $ct_check_chain_name 2>/dev/null
then
	iptables -t mangle -I FORWARD -m connmark ! --mark 0x0/$mark_mask_value -j $ct_check_chain_name
else
	iptables -t mangle -F $ct_check_chain_name
fi


if iptables -t mangle -N $ct_mark_chain_name 2>/dev/null
then
	iptables -t mangle -I FORWARD -m connmark --mark 0x0/$mark_mask_value -i $wan_intf -m state --state NEW -j $ct_mark_chain_name
else
	iptables -t mangle -F $ct_mark_chain_name
fi

[ "$userredirect_enabled" -eq 0 ] || config_foreach userredirect_each userredirect
[ "$dmz_enabled" -eq 0 ] || config_foreach dmzredirect_each dmzredirect

iptables -t mangle -A $ct_check_chain_name -j DROP

# force all packets in existing connections to go through check chain
fcctl  flush --if $wan_intf

exit 0

