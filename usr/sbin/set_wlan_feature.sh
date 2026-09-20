#!/bin/sh

FEAT=$1

FILE=/etc/wlan_feature

OK_FEAT=error

if [ "$FEAT" = "" ] || [ "$FEAT" = "0x00" ] ; then
  OK_FEAT=
fi

if [ "$FEAT" = "DHD_NIC_ENABLE" ] || [ "$FEAT" = "0x01" ] ; then
  OK_FEAT=DHD_NIC_ENABLE
fi

if [ "$FEAT" = "DHD_MFG_ENABLE" ] || [ "$FEAT" = "0x02" ] ; then
  OK_FEAT=DHD_MFG_ENABLE
fi

if [ "$OK_FEAT" = "error" ] ; then
  echo "Invalid feature".
  echo "Valid features: <empty> (0x00), DHD_NIC_ENABLE (0x01), DHD_MFG_ENABLE (0x02)".
  exit 1
fi

if [ "$OK_FEAT" = "" ] ; then
  rm -f $FILE
else
  echo $OK_FEAT > $FILE
fi    