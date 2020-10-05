#!/bin/sh

AH_NAME="DNSGlobal"

[ "$user" = "$AH_NAME" ] && exit 0

. /etc/ah/helper_serialize.sh && help_serialize
. /etc/ah/helper_ifname.sh

TCPCONF=/tmp/dns/tcpif
RCODECONF=/tmp/dns/rcodep
STRICTIPV=/tmp/dns/strict_ipv_mode
QIPVREDIRECT=/tmp/dns/redirect_qipv

manage_strict_ipversion() {
	[ "$newX_ADB_IPVersionRestricted" = "true" ] && echo "1" > $STRICTIPV || rm $STRICTIPV
}
manage_ipversion_on_redirect() {
	[ "$newX_ADB_ReqIPVersionOnRedirect" = "true" ] && echo "1" > $QIPVREDIRECT || rm $QIPVREDIRECT
}
manage_tcprestricted() {
	local obj ifl i
	if [ "$newX_ADB_TCPRestricted" = "true" ]; then
		set -f
		IFS=","
		set -- $newX_ADB_TCPAllowedIfaces
		unset IFS
		set +f
		for obj; do
			help_lowlayer_ifname_get "i" "$obj"
			ifl="${ifl},${i}"
		done
		ifl=${ifl#,}
		echo "${ifl}" > $TCPCONF
	elif [ "$changedX_ADB_TCPRestricted" = "1" ]; then
		rm $TCPCONF
	fi
}

manage_rcodes() {
	[ "$newX_ADB_NoFallbackRCODEs" ] && echo "$newX_ADB_NoFallbackRCODEs" > $RCODECONF || rm -f $RCODECONF
}

service_config() {
	[ "$changedX_ADB_TCPRestricted" = "1" -o "$changedX_ADB_TCPAllowedIfaces" = "1" ] && manage_tcprestricted
	[ "$changedX_ADB_NoFallbackRCODEs" = "1" ] && manage_rcodes
	[ "$changedX_ADB_IPVersionRestricted" = "1" ] && manage_strict_ipversion
	[ "$changedX_ADB_ReqIPVersionOnRedirect" = "1" ] && manage_ipversion_on_redirect
}

case "$op" in
	s)
		service_config
		;;
esac

exit 0
