#!/bin/sh

#Syntax: wireless_get_radio_type.sh <radio>
#Note: this script can only handle the combinations that are on the current platfor

RADIO=$1

#Default
RADIO_TYPE=broadcom

#Detect Atheros
if [ -e "/proc/athversion" ]; then
  RADIO_TYPE=atheros
fi

#Detect intel (for now assume all intel in that case)
if [ -d "/opt/lantiq" ]; then
  RADIO_TYPE=intel
fi

#Detect Quantenna
#QSR10G: assuming both 2.4G and 5G
if [ -d "/sys/module/qsr10g_pcie" ]; then
  RADIO_TYPE=quantenna
fi
#XTREAM: only 5G
if [ "$RADIO" = "radio_5G" ] && [ -e "/qtn/qtn-linux.lzma" ]; then
  RADIO_TYPE=quantenna
fi

#NL80211 (qcacld)
DUMMY=`iw dev 2> /dev/null`
if [ "$?" == "0" ]; then
  FIRST_IFACE=`iw dev | grep Interface | cut -d ' '  -f 2 | head -n 1`

  #QCACLD
  DUMMY=`iwpriv $FIRST_IFACE version 2> /dev/null | grep QCA`
  if [ "$?" == "0" ] ; then
    RADIO_TYPE=qcacld
  fi
fi

#For a USB wireless dongle
if [ -d "/sys/module/ath9k_htc" ]; then
  RADIO_TYPE=qcacld
fi

echo "$RADIO_TYPE"
