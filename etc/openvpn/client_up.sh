#!/bin/sh

. /lib/functions/vpn_common_inc.sh

OPENVPN_DEV="$1"
ip_up_cb openvpn $OPENVPN_DEV client

exit 0
