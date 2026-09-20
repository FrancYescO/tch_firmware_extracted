#!/bin/sh
. /lib/functions.sh
. /lib/functions/functions-tch.sh
. /lib/functions/network.sh

EBT_WMM_CHAIN='wmm_mark'
CLASSGROUPS=
INTERFACES=
L2RULES=

QOS_MARK_MASK_BITS=15
QOS_MARK_SHIFT=0

val_shift_left QOS_MARK_MASK "$QOS_MARK_MASK_BITS" "$QOS_MARK_SHIFT"

[ -x /sbin/modprobe ] && {
	insmod="modprobe"
	rmmod="$insmod -r"
} || {
	insmod="insmod"
	rmmod="rmmod"
}

add_insmod() {
	eval "export isset=\${insmod_$1}"
	case "$isset" in
		1) ;;
		*) {
			[ "$2" ] && append INSMOD "$rmmod $1 >&- 2>&-" "$N"
			append INSMOD "$insmod $* >&- 2>&-" "$N"; export insmod_$1=1
		};;
	esac
}

LIST_WMM=
LIST_WL=

list_wl_add() {
	append LIST_WL $1
}

config_load wireless
config_foreach list_wl_add wifi-iface

LIST_BR=

list_bridge_add() {
	local type
	config_get type "$1" type
	[ "$type" == "bridge" ] && append LIST_BR $1
}

config_load network
config_foreach list_bridge_add interface

start_interface() {
	local iface="$1"
	local device="$2"
	local up

	config_get classgroup "$iface" classgroup
	[ -z "$classgroup" ] && return
	config_get_bool enabled "$iface" enabled 1
	[ 1 -eq "$enabled" ] || return

	if ! (iptables -t mangle -S | grep -q "^-A OUTPUT -o $device -j qos_${classgroup}"); then
		append up "iptables -t mangle -A OUTPUT -o $device -j qos_${classgroup}" "$N"
	fi

	if ! (iptables -t mangle -S | grep -q "^-A FORWARD -o $device -j qos_${classgroup}"); then
		append up "iptables -t mangle -A FORWARD -o $device -j qos_${classgroup}" "$N"
	fi

	if list_contains LIST_BR "$iface"; then
		if ! (ebtables -L OUTPUT | grep -q ".-logical-out $device .*-j qos_${classgroup}"); then
			append up "ebtables -I OUTPUT --logical-out $device --mark 0/$QOS_MARK_MASK -j qos_${classgroup}" "$N"
		fi

		if ! (ebtables -L FORWARD | grep -q ".-logical-out $device .*-j qos_${classgroup}"); then
			append up "ebtables -I FORWARD --logical-out $device --mark 0/$QOS_MARK_MASK -j qos_${classgroup}" "$N"
		fi
	fi

	[ -z "$up" ] && return

	cat <<EOF
$INSMOD
$up
EOF
	unset INSMOD
}

parse_matching_rule() {
	local var="$1"
	local section="$2"
	local options="$3"
	local prefix="$4"
	local suffix="$5"
	local proto="$6"
	local mport=""
	local ports=""

	append "$var" "$prefix" "$N"
	for option in $options; do
		case "$option" in
			proto) config_get value "$section" proto; proto="${proto:-$value}";;
		esac
	done
	config_get type "$section" TYPE
	case "$type" in
		classify) unset pkt; append "$var" "-m mark --mark 0/$QOS_MARK_MASK";;
		default) pkt=1; append "$var" "-m mark --mark 0/$QOS_MARK_MASK";;
		reclassify) pkt=1;;
	esac
	append "$var" "${proto:+-p $proto}"
	for option in $options; do
		config_get value "$section" "$option"

		case "$pkt:$option" in
			*:srchost)
				append "$var" "-s $value"
			;;
			*:dsthost)
				append "$var" "-d $value"
			;;
			*:layer7)
				add_insmod ipt_layer7
				add_insmod xt_layer7
				append "$var" "-m layer7 --l7proto $value${pkt:+ --l7pkt}"
			;;
			*:ports|*:srcports|*:dstports)
				value="$(echo "$value" | sed -e 's,-,:,g')"
				lproto=${lproto:-tcp}
				case "$proto" in
					""|tcp|udp) append "$var" "-m ${proto:-tcp -p tcp} -m multiport";;
					*) unset "$var"; return 0;;
				esac
				case "$option" in
					ports)
						config_set "$section" srcports ""
						config_set "$section" dstports ""
						config_set "$section" portrange ""
						append "$var" "--ports $value"
					;;
					srcports)
						config_set "$section" ports ""
						config_set "$section" portrange ""
						append "$var" "--sports $value"
					;;
					dstports)
						config_set "$section" ports ""
						config_set "$section" portrange ""
						append "$var" "--dports $value"
					;;
				esac
				ports=1
			;;
			*:portrange)
				config_set "$section" ports ""
				config_set "$section" srcports ""
				config_set "$section" dstports ""
				value="$(echo "$value" | sed -e 's,-,:,g')"
				case "$proto" in
					""|tcp|udp) append "$var" "-m ${proto:-tcp -p tcp} --sport $value --dport $value";;
					*) unset "$var"; return 0;;
				esac
				ports=1
			;;
			*:connbytes)
				value="$(echo "$value" | sed -e 's,-,:,g')"
				add_insmod ipt_connbytes
				append "$var" "-m connbytes --connbytes $value --connbytes-dir both --connbytes-mode bytes"
			;;
			*:tos)
				add_insmod ipt_tos
				case "$value" in
					!*) append "$var" "-m tos ! --tos $value";;
					*) append "$var" "-m tos --tos $value"
				esac
			;;
			*:dscp)
				add_insmod ipt_dscp
				dscp_option="--dscp"
				[ -z "${value%%[EBCA]*}" ] && dscp_option="--dscp-class"
				case "$value" in
					!*) append "$var" "-m dscp ! $dscp_option $value";;
					*) append "$var" "-m dscp $dscp_option $value"
				esac
			;;
			*:direction)
				value="$(echo "$value" | sed -e 's,-,:,g')"
				if [ "$value" = "out" ]; then
					append "$var" "-o $device"
				elif [ "$value" = "in" ]; then
					append "$var" "-i $device"
				fi
			;;
			1:pktsize)
				value="$(echo "$value" | sed -e 's,-,:,g')"
				add_insmod ipt_length
				append "$var" "-m length --length $value"
			;;
			1:limit)
				add_insmod ipt_limit
				append "$var" "-m limit --limit $value"
			;;
			1:tcpflags)
				case "$proto" in
					tcp) append "$var" "-m tcp --tcp-flags ALL $value";;
					*) unset $var; return 0;;
				esac
			;;
			1:mark)
				config_get class "${value##!}" classnr
				[ -z "$class" ] && continue;
				case "$value" in
					!*) append "$var" "-m mark ! --mark $class/$QOS_MARK_MASK";;
					*) append "$var" "-m mark --mark $class/$QOS_MARK_MASK";;
				esac
			;;
			1:helper)
				add_insmod xt_helper
				append "$var" "-m helper --helper $value"
			;;
			1:TOS)
				add_insmod ipt_TOS
				config_get TOS "$rule" 'TOS'
				suffix="-j TOS --set-tos "${TOS:-"Normal-Service"}
			;;
			1:DSCP)
				add_insmod ipt_DSCP
				config_get DSCP "$rule" 'DSCP'
				[ -z "${DSCP%%[EBCA]*}" ] && set_value="--set-dscp-class $DSCP" \
				|| set_value="--set-dscp $DSCP"
				suffix="-j DSCP $set_value"
			;;
		esac
	done
	append "$var" "$suffix"
	case "$ports:$proto" in
		1:)	parse_matching_rule "$var" "$section" "$options" "$prefix" "$suffix" "udp";;
	esac
}

parse_matching_l2rule() {
	local var="$1"
	local chain="$2"
	local section="$3"
	local options="$4"
	local target="$5"
	local out1 out2 out3 value

	for option in $options; do
		config_get value "$section" "$option"

		case "$option" in
			proto)
				append out1 "-p $value"
			;;
			ifsrc)
				append out1 "-i $value"
			;;
			ifdst)
				append out1 "-o $value"
			;;
			macsrc)
				append out1 "-s $value"
			;;
			macdst)
				append out1 "-d $value"
			;;
			ipsrc)
				append out2 "--ip-src $value"
			;;
			ipdst)
				append out2 "--ip-dst $value"
			;;
			iptos)
				append out2 "--ip-tos $value"
			;;
			ipproto)
				append out2 "--ip-proto $value"
			;;
			ipsrcports)
				append out3 "--ip-sport $value"
			;;
			ipdstports)
				append out3 "--ip-dport $value"
			;;
			ip6src)
				append out2 "--ip6-src $value"
			;;
			ip6dst)
				append out2 "--ip6-dst $value"
			;;
			ip6tclass)
				append out2 "--ip6-tclass $value"
			;;
			ip6proto)
				append out2 "--ip6-proto $value"
			;;
			ip6srcports)
				append out3 "--ip6-sport $value"
			;;
			ip6dstports)
				append out3 "--ip6-dport $value"
			;;
			limit)
				append out2 "--limit $value"
			;;
			limitburst)
				append out2 "--limit-burst $value"
			;;
			pkttype)
				append out2 "--pkttype-type $value"
			;;
			vlanid)
				append out2 "--vlan-id $value"
			;;
			vlanprio)
				append out2 "--vlan-prio $value"
			;;
			vlanencap)
				append out2 "--vlan-encap $value"
			;;
		esac
	done

	append "$var" "ebtables -A $chain $out1 $out2 $out3 -j mark --mark-or $target" "$N"
}

config_cb() {
	option_cb() {
		return 0
	}

	# Section start
	case "$1" in
		interface)
			config_set "$2" "classgroup" "Default"
		;;
		classify|default|reclassify|l2classify)
			option_cb() {
				append options "$1"
			}
		;;
	esac
        # Section end

	config_get TYPE "$CONFIG_SECTION" TYPE
	case "$TYPE" in
		interface)
			config_get classgroup "$CONFIG_SECTION" classgroup
			append INTERFACES "$CONFIG_SECTION"
		;;
		classgroup)
			append CLASSGROUPS "$CONFIG_SECTION"
		;;
		classify|default|reclassify)
			case "$TYPE" in
				classify) var="ctrules";;
				*) config_get helper "$CONFIG_SECTION" helper
				   [ -n "$helper" ] && var="hrules" || var="rules";;
			esac
			config_get target "$CONFIG_SECTION" target
			config_set "$CONFIG_SECTION" options "$options"
			append "$var" "$CONFIG_SECTION"
			unset options
		;;
		l2classify)
			config_set "$CONFIG_SECTION" options "$options"
			append L2RULES "$CONFIG_SECTION"
			unset options
		;;
	esac
}

enum_classes() {
	local c="0"
	config_get classes "$1" classes
	for class in $classes; do
		local classnr
		val_shift_left classnr "$c" "$QOS_MARK_SHIFT"
		config_set "${class}" classnr "$classnr"
		c="$(($c + 1))"
	done
}

add_rules() {
	local var="$1"
	local cg="$2"
	local rules="$3"
	local prefix="$4"

	for rule in $rules; do
		unset iptrule
		config_get target "$rule" target
		config_get classes "$cg" classes
		list_contains classes $target || continue
		config_get target "$target" classnr
		config_get options "$rule" options

		## If we want to override the TOS field, let's clear the DSCP field first.
		[ ! -z "$(echo $options | grep 'TOS')" ] && {
			s_options=${options%%TOS}
			add_insmod ipt_DSCP
			parse_matching_rule iptrule "$rule" "$s_options" "$prefix" "-j DSCP --set-dscp 0"
			append "$var" "$iptrule" "$N"
			unset iptrule
		}

		parse_matching_rule iptrule "$rule" "$options" "$prefix" "-j MARK --set-mark $target/$QOS_MARK_MASK"
		append "$var" "$iptrule" "$N"
	done
}

add_l2rules() {
	local var="$1"
	local cg="$2"
	local rules="$3"
	local rule options target

	for rule in $rules; do
		config_get target "$rule" target
		config_get classes "$cg" classes
		list_contains classes $target || continue
		config_get target "$target" classnr
		config_get options "$rule" options

		parse_matching_l2rule "$var" "qos_$cg" "$rule" "$options" "$target"
	done
}

start_cg() {
	local cg="$1"
	local iptrules
	local hlprules
	local pktrules
	local l2rules
	local up
	local l2rules_added=0

	enum_classes "$cg"
	add_rules iptrules "$cg" "$ctrules" "iptables -t mangle -A qos_${cg}_ct"
	add_rules hlprules "$cg" "$hrules" "iptables -t mangle -A qos_${cg}_hlp"
	add_rules pktrules "$cg" "$rules" "iptables -t mangle -A qos_${cg}"

	for iface in $INTERFACES; do
		config_get classgroup "$iface" classgroup
		[ "$cg" = "$classgroup" ] || continue
		if list_contains LIST_BR $iface; then
			if [ $l2rules_added -eq 0 ]; then
				append l2rules "ebtables -N qos_${cg} -P RETURN $N"
				add_l2rules l2rules "$cg" "$L2RULES"
				l2rules_added=1
			fi
		fi
		config_get_bool enabled "$iface" enabled 1
		[ 1 -eq "$enabled" ] || continue
		network_is_up "$iface" || continue
		network_get_device device "$iface"
		append up "iptables -t mangle -A OUTPUT -o $device -j qos_${cg}" "$N"
		append up "iptables -t mangle -A FORWARD -o $device -j qos_${cg}" "$N"
		if list_contains LIST_BR $iface; then
			append l2rules "ebtables -A OUTPUT --logical-out $device --mark 0/$QOS_MARK_MASK -j qos_${cg}" "$N"
			append l2rules "ebtables -A FORWARD --logical-out $device --mark 0/$QOS_MARK_MASK -j qos_${cg}" "$N"
		fi
	done
	cat <<EOF
$INSMOD
iptables -t mangle -N qos_${cg} >&- 2>&-
iptables -t mangle -N qos_${cg}_ct >&- 2>&-
iptables -t mangle -N qos_${cg}_hlp >&- 2>&-
${iptrules:+${iptrules}${N}iptables -t mangle -A qos_${cg}_ct -j CONNMARK --save-mark --mask $QOS_MARK_MASK}
iptables -t mangle -A qos_${cg} -j CONNMARK --restore-mark --mask $QOS_MARK_MASK
iptables -t mangle -A qos_${cg} -m mark --mark 0/$QOS_MARK_MASK -j qos_${cg}_ct
iptables -t mangle -A qos_${cg} -j qos_${cg}_hlp
$hlprules
$pktrules
$up
$l2rules
EOF
	unset INSMOD
}

add_wmm() {
	local wmm="$1"
	local var="$2"

	append LIST_WMM $wmm

	config_get mark_ipv4 "$wmm" mark_ipv4 dscp
	config_get mark_ipv6 "$wmm" mark_ipv6 dscp
	config_get mark_802_1q "$wmm" mark_802_1q vlan

	append "$var" "ebtables -N wmm_$wmm -P RETURN" "$N"

	case "$mark_ipv4" in
	"dscp")
		append "$var" "ebtables -A wmm_$wmm -p IPV4 -j wmm-mark --wmm-marktag $mark_ipv4" "$N"
	;;
	"class")
		append "$var" "ebtables -A wmm_$wmm -p IPV4 -j wmm-classmap" "$N"
	;;
	*)
	;;
	esac

	case "$mark_ipv6" in
	"dscp")
		append "$var" "ebtables -A wmm_$wmm -p IPV6 -j wmm-mark --wmm-marktag $mark_ipv6" "$N"
	;;
	"class")
		append "$var" "ebtables -A wmm_$wmm -p IPV6 -j wmm-classmap" "$N"
	;;
	*)
	;;
	esac


	case "$mark_802_1q" in
	"vlan")
		append "$var" "ebtables -A wmm_$wmm -p 802_1Q -j wmm-mark --wmm-marktag $mark_802_1q" "$N"
	;;
	"class")
		append "$var" "ebtables -A wmm_$wmm -p 802_1Q -j wmm-classmap" "$N"
	;;
	*)
	;;
	esac
}

add_wmm_device_rule() {
	local var="$1"
	local device="$2"
	local wmm="$3"

	append "$var" "ebtables -A $EBT_WMM_CHAIN -o $device -j wmm_$wmm" "$N"
}

add_wmm_device() {
	local device="$1"
	local var="$2"
	local enable wmm

	list_contains LIST_WL $device || return
	list_remove LIST_WL $device

	config_get_bool enable $device enable 0
	[ $enable == 1 ] || return
	config_get wmm $device wmm
	[ -n "$wmm" ] || return

	add_wmm_device_rule "$var" "$device" "$wmm"
}

start_wmm() {
	local up device

	config_foreach add_wmm wmm up
	list_contains LIST_WMM default || add_wmm default up

	config_foreach add_wmm_device device up
	for device in $LIST_WL; do
		 add_wmm_device_rule up "$device" default
	done

	cat <<EOF
ebtables -N $EBT_WMM_CHAIN -P RETURN
ebtables -A OUTPUT -j $EBT_WMM_CHAIN
ebtables -A FORWARD -j $EBT_WMM_CHAIN
$up
EOF
}

start_firewall() {
	add_insmod ipt_multiport
	add_insmod ipt_CONNMARK
	stop_firewall
	for group in $CLASSGROUPS; do
		start_cg $group
	done

	start_wmm
}

ebtables_flush() {
	ebtables -L --Lx |
		# Find rules for the qos_* and wmm_* chains
		grep ' -[Nj] \(qos\|wmm\)_' |
		# Exclude inter-qos_* and wmm_* references
		grep -v ' -A \(qos\|wmm\)_' |
		# Replace -N with -X and hold, with -F and print
		# Replace -A with -D
		# Print held lines at the end (note leading newline)
		sed -e '/ -N /{s/ -N / -X /;H;s/ -X / -F /}' \
			-e 's/ -A / -D /' \
			-e '${p;g}'
}

stop_firewall() {
	# Builds up a list of iptables commands to flush the qos_* chains,
	# remove rules referring to them, then delete them

	# Print rules in the mangle table, like iptables-save
	iptables -t mangle -S |
		# Find rules for the qos_* chains
		grep '^-N qos_\|-j qos_' |
		# Exclude rules in qos_* chains (inter-qos_* refs)
		grep -v '^-A qos_' |
		# Replace -N with -X and hold, with -F and print
		# Replace -A with -D
		# Print held lines at the end (note leading newline)
		sed -e '/^-N/{s/^-N/-X/;H;s/^-X/-F/}' \
			-e 's/^-A/-D/' \
			-e '${p;g}' |
		# Make into proper iptables calls
		# Note:  awkward in previous call due to hold space usage
		sed -n -e 's/^./iptables -t mangle &/p'

	ebtables_flush
}

[ -e ./qos.conf ] && {
	. ./qos.conf
	config_cb
} || config_load qos

case "$1" in
	interface)
		start_interface "$2" "$3"
	;;
	firewall)
		case "$2" in
			stop)
				stop_firewall
			;;
			start|"")
				start_firewall
			;;
		esac
	;;
esac
