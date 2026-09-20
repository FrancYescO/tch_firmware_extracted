#!/bin/sh

#Syntax: wireless_get_radio_type.sh <radio>
#Note: this script can only handle the combinations that are on the current platfor

RADIO=$1

#Default
RADIO_TYPE=broadcom

#Detect Atheros
if [ -e "/proc/athversion" ] ; then
  RADIO_TYPE=atheros
fi

#Detect Quantenna
if [ "$RADIO" = "radio_5G" ] && [ -e "/qtn/qtn-linux.lzma" ] ; then
  RADIO_TYPE=quantenna
fi

echo "$RADIO_TYPE"
