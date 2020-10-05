#!/bin/sh

AH_NAME="DNSBlackHole"
[ "$user" = "${AH_NAME}" ] && exit 0

DNSFILE="/tmp/dns/${obj}_bh"

. /etc/ah/helper_serialize.sh && help_serialize
. /etc/ah/helper_ifname.sh

service_config() {

	local idx=0 dom_inst="" prio=255 timeout=0 qrysrc="" intf=""

	case "$obj" in
		Device.DNS.Relay.X_ADB_DynamicForwardingRule.*)
			[ ${#newX_ADB_InboundInterface} -ne 0 ] && help_lowlayer_ifname_get qrysrc "$newX_ADB_InboundInterface"
			: ${qrysrc:="*"}
			;;
		Device.DNS.Client.X_ADB_DynamicServerRule.*)
			qrysrc="lo"
			;;
	esac

	# Retrieve DROP priority (prio) and out Interface (intf)
	[ ${#newX_ADB_PrioDrop} -ne 0 ] && prio=$newX_ADB_PrioDrop
	[ ${#newX_ADB_Timeout} -ne 0 ] && timeout=$newX_ADB_Timeout
	[ ${#newInterface} -ne 0 ] && help_lowlayer_ifname_get intf "$newInterface"
	: ${intf:="*"}

	set -f
	IFS=","
	set -- $newX_ADB_DomainFiltering
	unset IFS
	set +f
	for dom_inst; do
		[ "$dom_inst" != "*" -a "${dom_inst#.}" = "$dom_inst" ] && dom_inst=".$dom_inst"
		echo "$prio $dom_inst drop $timeout $qrysrc $intf" > ${DNSFILE}_${idx}
		idx=$((idx+1))
	done
}

case "$op" in
	s)
		rm -f ${DNSFILE}_*
		[ "$newEnable" = "true" -a -n "$newX_ADB_DomainFiltering" -a "$newX_ADB_ForceDrop" = "true" ] || exit 0
		service_config
		;;
	d)
		rm -f ${DNSFILE}_*
		;;
	*)
		;;
esac

exit 0
