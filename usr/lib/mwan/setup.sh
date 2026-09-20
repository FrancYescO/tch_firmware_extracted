#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/functions/network.sh
. $IPKG_INSTROOT/lib/network/config.sh
. $IPKG_INSTROOT/lib/functions/functions-tch.sh

#kernel support for string matching
XT_STRING_SUPPORT=0
#mwan mark mask bits
MWAN_MARK_MASK_BITS=15
#Shift size of the mark bits
MWAN_MARK_SHIFT=28
MWAN_NF_MASK=0xf0000000
MWAN_CT_MASK=$MWAN_NF_MASK

mwan_check_icmp_type6() {
	local _var="$1"
	local _type="$2"

	case "$_type" in
		![0-9]*) export -n -- "$_var=! --icmpv6-type ${_type#!}"; return 0 ;;
		[0-9]*)  export -n -- "$_var=--icmpv6-type $_type";       return 0 ;;
	esac

	[ -z "$FW_ICMP6_TYPES" ] && \
		export FW_ICMP6_TYPES=$(
			ip6tables -p icmpv6 -h 2>/dev/null | \
			sed -n -e '/^Valid ICMPv6 Types:/ {
				n; :r; s/[()]/ /g; s/[[:space:]]\+/\n/g; p; n; b r
			}' | sort -u
		)

	local _check
	for _check in $FW_ICMP6_TYPES; do
		if [ "$_check" = "${_type#!}" ]; then
			[ "${_type#!}" != "$_type" ] && \
				export -n -- "$_var=! --icmpv6-type ${_type#!}" || \
				export -n -- "$_var=--icmpv6-type $_type"
			return 0
		fi
	done

	export -n -- "$_var="
	return 1
}

mwan_check_icmp_type4() {
	local _var="$1"
	local _type="$2"

	case "$_type" in
		![0-9]*) export -n -- "$_var=! --icmp-type ${_type#!}"; return 0 ;;
		[0-9]*)  export -n -- "$_var=--icmp-type $_type";       return 0 ;;
	esac

	[ -z "$MWAN_ICMP4_TYPES" ] && \
		export MWAN_ICMP4_TYPES=$(
			iptables -p icmp -h 2>/dev/null | \
			sed -n -e '/^Valid ICMP Types:/ {
				n; :r; s/[()]/ /g; s/[[:space:]]\+/\n/g; p; n; b r
			}' | sort -u
		)

	local _check
	for _check in $MWAN_ICMP4_TYPES; do
		if [ "$_check" = "${_type#!}" ]; then
			[ "${_type#!}" != "$_type" ] && \
				export -n -- "$_var=! --icmp-type ${_type#!}" || \
				export -n -- "$_var=--icmp-type $_type"
			return 0
		fi
	done

	export -n -- "$_var="
	return 1
}

mwan_get_negation() {
	local _var="$1"
	local _flag="$2"
	local _value="$3"

	[ "${_value#!}" != "$_value" ] && \
		export -n -- "$_var=! $_flag ${_value#!}" || \
		export -n -- "$_var=${_value:+$_flag $_value}"
}

mwan_get_port_range() {
	local _var=$1
	local _ports=$2
	local _delim=${3:-:}
	if [ "$4" ]; then
		fw_get_port_range $_var "${_ports}-${4}" $_delim
		return
	fi

	local _first=${_ports%[-:]*}
	local _last=${_ports#*[-:]}
	if [ "${_first#!}" != "${_last#!}" ]; then
		export -- "$_var=$_first$_delim${_last#!}"
	else
		export -- "$_var=$_first"
	fi
}

#   ext_string
#         The netfilter string modules  matches a given string by using some
#         pattern matching strategy. It requires a linux kernel >= 2.6.14.
#        --algo  bm|kmp
#              Select the pattern matching strategy.
#              (bm = Boyer-Moore, kmp = Knuth-Pratt-Morris)
#              By default the bm algo is selected
#              (the most performant algorith in most cases)
#
#        --from offset
#              Set the offset from which it starts looking for any matching.
#              If not passed, default is 0.
#
#        --to offset
#              Set the offset to which it starts looking for any
#              matching. If not passed, default  is  the packet size.
#        --icase
#              Ignore the case during pattern matching
#              By default case sensitive matching is performed
#
#        [!]--string pattern
#              Matches the given pattern.
#              String can not be used together with hex-string
#        [!]--hex-string pattern
#              Matches the given pattern in hex notation.
#              hex-string can not be used together with string
#              e.g. "|0A 0B|"
mwan_get_ext_string() {
	local _cfg=$1
	local _rule_string=$2
	local from
	local to
	local algo
	local icase
	local stringpat
	local hexstringpat

	#mwan.rule[].string
	config_get stringpat $_cfg string
	[ -n "$stringpat" ] && mwan_get_negation stringpat '--string' "$stringpat"
	#mwan.rule[].hexstring
	config_get hexstringpat $_cfg hexstring
	[ -n "$hexstringpat" ] && mwan_get_negation hexstringpat '--hex-string' "$hexstringpat"

	#string and hexstring are mutual exclusive
	#if both are set in the configuration, the string stuff is taken
	stringpat=${stringpat:-$hexstringpat}

	#no need to continue processing if no stringpattern is defined
	[ -z "$stringpat" ] && return 0

	#mwan.rule[].from_offset
	config_get from $_cfg from_offset
	#mwan.rule[].to_offset
	config_get to $_cfg to_offset
	#mwan.rule[].algo
	config_get algo $_cfg algo "bm"
	[ ${algo} != "bm" ] && [ ${algo} != "kmp" ] && algo="bm"
	#mwan.rule[].icase
	config_get_bool icase $_cfg icase 0
	[ "${icase}" = 0 ] && icase=""

	#return the command string in the first argument
	if  [ -n "${stringpat}" ] ; then
	    export -- $_rule_string="-m string ${stringpat} --algo ${algo} ${from:+--from $from} ${to:+--to $to} ${icase:+--icase}"
	else
	    export -- $_rule_string=""
	fi
}

#cmd fam chain target pos { rules }
mwan_iptables_mangle() {
	local cmd fam chain target pos
	local i

	for i in cmd fam chain target pos; do
		if [ "$1" -a "$1" != '{' ]; then
			eval "$i='$1'"
			shift
		else
			eval "$i=-"
		fi
	done

	local app
	case $fam in
		*4) app=iptables ;;
		*6) app=ip6tables ;;
		*) app=iptables ;;
	esac

	case "$cmd:$chain:$target:$pos" in
		add:*:-:*) cmd=new-chain ;;
		add:*:*:-) cmd=append ;;
		add:*:*:*) cmd=insert ;;
		del:-:*:*) cmd=delete-chain; mwan_iptables_mangle flush $fam ;;
		del:*:-:*) cmd=delete-chain; mwan_iptables_mangle flush $fam $chain ;;
		del:*:*:*) cmd=delete ;;
		flush:*) ;;
		rename:*) cmd=rename-chain ;;
		list:*) cmd="numeric --verbose --$cmd" ;;
		*) return 254 ;;
	esac

	case "$chain" in
		-) chain= ;;
	esac

	case "$target" in
		-) target= ;;
	esac

	local rule_offset
	case "$pos" in
		^) pos=1 ;;
		-) pos= ;;
		%) pos= ;;
	        +) rule_offset=$(($($app -L $chain -t mangle -n | wc -l)-1)) ;;
	esac

	if [ $# -gt 0 ]; then
		shift
		if [ $cmd == delete ]; then
			pos=
		fi
	fi

	local cmdline="$app -t mangle --${cmd} $chain ${rule_offset:-${pos}} ${target:+--jump "$target"}"

	while [ $# -gt 1 ]; do
		# special parameter handling
		case "$1:$2" in
			-p:icmp*|-p:1|-p:58)
				[ "$app" = ip6tables ] && \
					cmdline="$cmdline -p icmpv6" || \
					cmdline="$cmdline -p icmp"
				shift
			;;

			--icmp-type:*|--icmpv6-type:*)
				local icmp_type
				if [ "$app" = ip6tables ] && mwan_check_icmp_type6 icmp_type "$2"; then
					cmdline="$cmdline $icmp_type"
				elif [ "$app" = iptables ] && mwan_check_icmp_type4 icmp_type "$2"; then
					cmdline="$cmdline $icmp_type"
				else
					local fam=IPv4; [ "$app" = ip6tables ] && fam=IPv6
					logger -t mwan "ICMP type '$2' is not valid for $fam address family, skipping rule"
					return 1
				fi
				shift
			;;

			*) cmdline="$cmdline $1"
			   ;;
		esac
		shift
	done

	$cmdline

	return $?
}

mwan_parse_rule() {
	local policy
	config_get policy $1 policy

	local nfmark=$(uci_get_state mwan "$policy" nfmark)
	[ -n "$nfmark" ] || exit 0

	local rule_src
	config_get rule_src $1 src
	[ -n "$rule_src" ] && {
		local device

		if network_get_device device "${rule_src#!}"; then
			[ ${rule_src#!} != $rule_src ] && \
			device="!$device"
			mwan_get_negation rule_src '-i' "$device"
		else
			rule_src=""
		fi
	}

	local rule_proto
	config_get rule_proto $1 proto "tcpudp"
	[ "$rule_proto" == "tcpudp" ] && rule_proto="tcp udp"

	local rule_src_ip
	config_get rule_src_ip $1 src_ip 0.0.0.0/0
	mwan_get_negation rule_src_ip '-s' "$rule_src_ip"

	local rule_dest_ip
	config_get rule_dest_ip $1 dest_ip 0.0.0.0/0
	mwan_get_negation rule_dest_ip '-d' "$rule_dest_ip"

	local rule_src_ports
	config_get rule_src_ports $1 src_port "0-65535"
	mwan_get_port_range rule_src_ports "$rule_src_ports"
	mwan_get_negation rule_src_ports '--sport' "$rule_src_ports"

	local rule_dest_ports
	config_get rule_dest_ports $1 dest_port "0-65535"
	mwan_get_port_range rule_dest_ports "$rule_dest_ports"
	mwan_get_negation rule_dest_ports '--dport' "$rule_dest_ports"

	local rule_icmp_types
	config_get rule_icmp_types $1 icmp_type ""

	local rule_string=""
	[ $XT_STRING_SUPPORT = 1 ] && mwan_get_ext_string $1 rule_string

	local pr; for pr in ${rule_proto}; do
		case "${pr#!}" in
			0)
				rule_src_ports=""
				rule_dest_ports=""
			;;

			icmp|icmpv6|1|58)
				if [ "${pr#!}" != "$pr" ]; then
					rule_icmp_types=""
				else
					rule_src_ports=""; rule_dest_ports=""
				fi
			;;

			tcp|udp|6|17)
				if [ "${pr#!}" != "$pr" ]; then
					rule_src_ports=""
					rule_dest_ports=""
				fi
				rule_icmp_types=""
			;;

			*)
				rule_icmp_types=""
				rule_src_ports=""
				rule_dest_ports=""
			;;
		esac

		mwan_get_negation pr '-p' "$pr"

		local rule_icmp_type; for rule_icmp_type in ${rule_icmp_types:-""}; do

			mwan_get_negation rule_icmp_type '--icmp-type' "$rule_icmp_type"

			mwan_iptables_mangle "add" "ipv4" "new_mwan_rules" "MARK" \
					{ $rule_src $rule_src_ip $rule_dest_ip \
					  $pr $rule_src_ports $rule_dest_ports \
					  $rule_icmp_type $rule_string "-m mark" "--mark 0x0/$MWAN_NF_MASK" \
					  "--set-xmark $nfmark/$MWAN_NF_MASK" }
		done
	done
}

mwan_update_rules() {
	mwan_iptables_mangle add "ipv4" "new_mwan_rules"
	mwan_iptables_mangle add "ipv4" "mwan_rules_hook" "new_mwan_rules"
	config_foreach mwan_parse_rule rule
	if mwan_iptables_mangle "del" "ipv4" "mwan_rules_hook" "mwan_rules" &> /dev/null; then
		mwan_iptables_mangle "del" "ipv4" "mwan_rules"
	fi

	mwan_iptables_mangle rename "ipv4" "new_mwan_rules" { "mwan_rules" }
}

mwan_setup_basic_iptables_rules() {
	if ! mwan_iptables_mangle list "ipv4" "mwan_rules_hook" &> /dev/null; then
		mwan_iptables_mangle add "ipv4" "mwan_rules_hook"
	fi

	if ! mwan_iptables_mangle list "ipv4" "mwan_default_hook" &> /dev/null; then
		mwan_iptables_mangle add "ipv4" "mwan_default_hook"
		mwan_default_iptables_rules
	fi

	if ! mwan_iptables_mangle list "ipv4" "mwan_pre" &> /dev/null; then
		mwan_iptables_mangle add "ipv4" "mwan_pre"
	fi

	if ! mwan_iptables_mangle list "ipv4" "mwan_output" &> /dev/null; then
		mwan_iptables_mangle add "ipv4" "mwan_output"
	fi

	if ! mwan_iptables_mangle list "ipv4" "mwan_post" &> /dev/null; then
		mwan_iptables_mangle add "ipv4" "mwan_post"
	fi

	if ! mwan_iptables_mangle list "ipv4" "mwan_pre" | grep "CONNMARK restore mask"; then
		mwan_iptables_mangle flush "ipv4" "mwan_pre"
		mwan_iptables_mangle add "ipv4" "mwan_pre" "CONNMARK" \
				{ "--restore-mark --nfmask $MWAN_NF_MASK --ctmask $MWAN_CT_MASK" }
		mwan_iptables_mangle add "ipv4" "mwan_pre" "mwan_default_hook" \
				{ "-m mark --mark 0x0/$MWAN_NF_MASK" }
		mwan_iptables_mangle add "ipv4" "mwan_pre" "mwan_rules_hook" \
				{ "-m mark --mark 0x0/$MWAN_NF_MASK" }
	fi

	if ! mwan_iptables_mangle list "ipv4" "mwan_post" | grep "CONNMARK save mask"; then
		mwan_iptables_mangle flush "ipv4" "mwan_post"
		mwan_iptables_mangle add "ipv4" "mwan_post" "CONNMARK" \
				{ "-m mark ! --mark 0x0/$MWAN_NF_MASK --save-mark \
				  --nfmask $MWAN_NF_MASK --ctmask $MWAN_CT_MASK" }
	fi

	if ! mwan_iptables_mangle list "ipv4" "PREROUTING" | grep mwan_pre; then
		mwan_iptables_mangle add "ipv4" "PREROUTING" "mwan_pre"
	fi

	if ! mwan_iptables_mangle list "ipv4" "OUTPUT" | grep mwan_output; then
		mwan_iptables_mangle add "ipv4" "OUTPUT" "mwan_output"
	fi

	if ! mwan_iptables_mangle list "ipv4" "mwan_output" | grep "CONNMARK restore mask"; then
		mwan_iptables_mangle flush "ipv4" "mwan_output"
		mwan_iptables_mangle add "ipv4" "mwan_output" "CONNMARK" \
				{ "-m conntrack --ctdir ORIGINAL -m connmark ! --mark 0x0/$MWAN_CT_MASK \
				  --restore-mark --nfmask $MWAN_NF_MASK --ctmask $MWAN_CT_MASK" }
		mwan_iptables_mangle add "ipv4" "mwan_output" "mwan_default_hook" \
				{ "-m mark --mark 0x0/$MWAN_NF_MASK" }
		mwan_iptables_mangle add "ipv4" "mwan_output" "mwan_rules_hook" \
				{ "-m mark  --mark 0x0/$MWAN_NF_MASK" }
	fi

	if ! mwan_iptables_mangle list "ipv4" "INPUT" | grep mwan_post &> /dev/null; then
		mwan_iptables_mangle add "ipv4" "INPUT" "mwan_post"
	fi

	if ! mwan_iptables_mangle list "ipv4" "POSTROUTING" | grep mwan_post &> /dev/null; then
		mwan_iptables_mangle add "ipv4" "POSTROUTING" "mwan_post"
	fi
}

mwan_update_ip_rules() {
	local interface
	config_get interface $1 interface
	[ $interface = $INTERFACE ] || return

	local policy_number=$(uci_get_state mwan "$1" id)
	[ -n "$policy_number" ] || exit 0
	[ "$policy_number" -lt "$MWAN_MARK_MASK_BITS" ] || exit 0
	local wan_rule_pref=$(($policy_number+1015))
	local policy_rule_pref=$(($policy_number+2015))

	local nfmark=$(uci_get_state mwan "$1" nfmark)

	local table_id=$(uci get network.$interface.ip4table)
	[ -z "$table_id" ] && table_id=main

	ip -f inet rule del pref ${wan_rule_pref} &> /dev/null

	for c in $(ip -f inet rule list | grep "fwmark" | \
		awk '($1 == ( "'${policy_rule_pref}:'" )) || ($7 == ( "'$table_id'" ))' | \
		awk '{split($5,a,"/"); if (a[1] == "'$nfmark'") print $1}'); do
		ip -f inet rule del pref ${c%:}
	done

	[ $ACTION = "ifup" -a -n "$DEVICE" ] && {
		ip -f inet rule add pref ${wan_rule_pref} iif $DEVICE table main &> /dev/null
		ip -f inet rule add pref ${policy_rule_pref} fwmark $nfmark/$MWAN_NF_MASK table $table_id &> /dev/null
	}

	local last_resort
	local last_resort_pref=$(($policy_number+3015))
	config_get last_resort $1 last_resort
	ip -f inet rule del pref ${last_resort_pref} &> /dev/null
	case "$last_resort" in
		blackhole)
			ip -f inet rule add pref ${last_resort_pref} fwmark $nfmark/$MWAN_NF_MASK blackhole
		;;
		continue)
		;;
		*)
			ip -f inet rule add pref ${last_resort_pref} fwmark $nfmark/$MWAN_NF_MASK unreachable
		;;
	esac
}

mwan_default_iptables_rules() {
	mwan_iptables_mangle add "ipv4" "mwan_default_hook" "MARK" \
			{ "-d 224.0.0.0/3" "-m mark" "--mark 0x0/$MWAN_NF_MASK" \
			  "--set-xmark $MWAN_NF_MASK/$MWAN_NF_MASK" }
}

mwan_set_state() {
	mwan_set_policy_state() {
		local _cfg="$1"

		i=$(($i+1))
		uci_toggle_state mwan "$_cfg" id "$i"

		local _nfmark
		val_shift_left "_nfmark" "$i" "$MWAN_MARK_SHIFT"
		_nfmark=0x$(printf %x $_nfmark)
		uci_toggle_state mwan "$_cfg" nfmark "$_nfmark"
	}
	local i=0

	uci_toggle_state mwan globals nfmask "$MWAN_NF_MASK"
	config_foreach mwan_set_policy_state policy
}

mwan_parse_host() {
	local policy
	config_get policy $1 policy

	local path
	config_get path $1 path

	local arg
	config_get arg $1 arg

	local interface
	config_get interface $policy interface
	local table_id=$(uci get network.$interface.ip4table)

	[ -n "$table_id" ] && {
		local nfmark=$(uci_get_state mwan "$policy" nfmark)
		[ -n "$nfmark" ] || exit 0

		for p in $path; do
			echo "$p $nfmark $arg" >>/var/etc/mwan.config.$$
		done
	}
}

mwan_flush_iptables() {
	# Flush the mwan "root" chains as we don't want
	# to flush the iptables root chains
	mwan_iptables_mangle "del" "ipv4" "PREROUTING" "mwan_pre"
	mwan_iptables_mangle "del" "ipv4" "INPUT" "mwan_post"
	mwan_iptables_mangle "del" "ipv4" "OUTPUT" "mwan_output"
	mwan_iptables_mangle "del" "ipv4" "POSTROUTING" "mwan_post"

	mwan_iptables_mangle "del" "ipv4" "mwan_pre"
	mwan_iptables_mangle "del" "ipv4" "mwan_output"
	mwan_iptables_mangle "del" "ipv4" "mwan_post"

	# Delete the mwan subchains
	mwan_iptables_mangle "del" "ipv4" "mwan_default_hook"
	mwan_iptables_mangle "del" "ipv4" "mwan_rules_hook"
	mwan_iptables_mangle "del" "ipv4" "mwan_rules"
}

mwan_flush_ip_rules() {
	for c in $(ip -f inet rule list | grep "fwmark" | awk '{split($5,a,"/"); \
		    if (a[2] == "$MWAN_NF_MASK") print $1}'); do
		ip -f inet rule del pref ${c%:}
	done
}

mwan_handle_ifaction() {
	ACTION="$1"
	INTERFACE="$2"
	DEVICE="$3"

	if [ -d /sys/module/xt_string ]; then
	    XT_STRING_SUPPORT=1
	    logger -t mwan "$ACTION interface $INTERFACE ($DEVICE) <string_matching_support enabled>"
	else
	    XT_STRING_SUPPORT=0
	    logger -t mwan "$ACTION interface $INTERFACE ($DEVICE) <string_matching_support disabled>"
	fi


	mwan_setup_basic_iptables_rules
	config_foreach mwan_update_ip_rules policy
	mwan_update_rules
	touch /var/etc/mwan.config.$$
	config_foreach mwan_parse_host host
	mv -f /var/etc/mwan.config.$$ /var/etc/mwan.config 2>/dev/null
}

mwan_policy_cb() {
	local interface
	config_get interface $1 interface

	local action="ifdown"
	local device
	network_is_up $interface && {
		action="ifup"
		network_get_device device $interface
	}

	mwan_handle_ifaction $action $interface $device
}

mwan_boot() {
	logger -t mwan "Booting mwan"

	mkdir -p /var/etc

	config_load mwan
	mwan_set_state

	touch /var/etc/mwan.config.$$
	config_foreach mwan_parse_host host
	mv -f /var/etc/mwan.config.$$ /var/etc/mwan.config 2>/dev/null
}

mwan_start() {
	logger -t mwan "Starting mwan"

	config_load mwan
	mwan_set_state
	config_foreach mwan_policy_cb policy
}

mwan_stop() {
	logger -t mwan "Stopping mwan"

	mwan_flush_iptables
	mwan_flush_ip_rules

	rm -f /var/etc/mwan.config
}

mwan_ifupdown() {
	config_load mwan

	mwan_set_state
	mwan_handle_ifaction "$@"
}

mwan_unlock() {
	lock -u /var/lock/LCK.mwan
}

lock /var/lock/LCK.mwan

trap mwan_unlock EXIT

case "$1" in
	boot)
		mwan_boot
	;;

	start)
		mwan_start
	;;

	stop)
		mwan_stop
	;;

	ifup|ifdown)
		mwan_ifupdown "$@"
	;;
esac
