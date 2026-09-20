#!/bin/sh

#Check wlan feature (dhd driver)
WLAN_FEATURE=`get_wlan_feature.sh`
if [ "$WLAN_FEATURE" != "" ] ; then
  echo "############################################################################" > /dev/console
  echo "### WARNING. WLAN_FEATURE IS SET TO <$WLAN_FEATURE>" > /dev/console
  echo "### PLEASE CLEAR WLAN FEATURE FOR NORMAL OPERATION" > /dev/console
  echo "############################################################################" > /dev/console
fi  

#Create device node for wl events
BRCM_WL_EVENT_MAJOR=229
mknod /dev/wl_event c $BRCM_WL_EVENT_MAJOR 0

BRCM_DHD_EVENT_MAJOR=230
mknod /dev/dhd_event c $BRCM_DHD_EVENT_MAJOR 0

#Disable NAR
wl -i wl0 nar 0
wl -i wl1 nar 0

#Set phycal_tempdelta for 4360 to 40 (CSP 811163)
PHY=`wl -i wl0 phylist`
if [ "${PHY:0:1}" = "v" ] && [ "`wl -i wl0 phycal_tempdelta`" = "0" ] ; then
  wl -i wl0 phycal_tempdelta 40
fi 

PHY=`wl -i wl1 phylist`
if [ "${PHY:0:1}" = "v" ] && [ "`wl -i wl1 phycal_tempdelta`" = "0" ] ; then
  wl -i wl1 phycal_tempdelta 40
fi 

#Board specific config
BOARD=`uci get env.rip.board_mnemonic`

if [ "$BOARD" = "GANT-H" ] ; then
	echo "EXECUTING BOARD SPECIFIC CONFIG FOR $BOARD" > /dev/console
	wl -i wl1 up
	wl -i wl1 radarthrs 0x685 0x30 0x685 0x30 0x689 0x30 0x685 0x30 0x685 0x30 0x689 0x30
	wl radarargs 2 5 37411 6 690 0x6a0 0x30 0x6419 0x7f09 6 500 2000 25 63568 2000 3000000 0x1e 0x1591 31552 4098 33860 5 5 0x11 128 20000000 70000000 5 12 0xa800
	wl -i wl1 down
fi

if [ "$BOARD" = "GANT-U" ] ; then
	echo "EXECUTING BOARD SPECIFIC CONFIG FOR $BOARD" > /dev/console
	wl -i wl1 phy_ed_thresh -77
	wl -i wl1 up
	wl -i wl1 radarthrs 0x699 0x30 0x699 0x30 0x699 0x30 0x699 0x30 0x699 0x30 0x699 0x30
	wl -i wl1 down
fi

if [ "$BOARD" = "GANT-1" ] ; then
	echo "EXECUTING BOARD SPECIFIC CONFIG FOR $BOARD" > /dev/console
	wl -i wl1 up
	wl -i wl1 radarthrs 0x6a8 0x30 0x6a8 0x30 0x6a8 0x30 0x6b0 0x30 0x6b0 0x30 0x6b0 0x30
	wl -i wl1 down
fi
