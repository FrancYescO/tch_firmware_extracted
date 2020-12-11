#!/bin/sh

. /lib/functions/vpn_common_inc.sh

OPENVPN_DEV="$1"
ip_down_cb $OPENVPN_DEV client

exit 0
