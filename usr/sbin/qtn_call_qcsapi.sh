#!/bin/sh

ETH_TYPE="88b6"
# To parse ubus output
. /usr/share/libubox/jshn.sh

# Include qtn config file
. /tmp/qtn/qtn_prod.env

#Create ubus command
json_init
json_add_string name "$RADIO"
if [ ! -z $PARAM ] ; then
  json_add_string param "$PARAM"
fi

UBUS_CMD="ubus -S call wireless.radio.remote get"
OUTPUT=$(eval $UBUS_CMD)
if [ "$?" != "0" ] ; then
  echo Syntax error
  exit 1
fi

#get remote radio name
json_load "$OUTPUT"
json_get_keys OUTPUT 
RADIO=`echo $OUTPUT`

#Get mac address
json_select "$RADIO" 
json_get_var MAC_ADDR macaddr
json_get_var INTF ifname

#Get call_qcsapi command
CMD="$@"

if [ "$L2_USE_LAN_SCOPE_MCAST" = "1" ] ; then
  qtn_qcsapi_eth ${INTF}:0180C200000E:${ETH_TYPE} "$CMD"
else
  qtn_qcsapi_eth br-lan:${MAC_ADDR//:}:${ETH_TYPE} "$CMD" 
fi

