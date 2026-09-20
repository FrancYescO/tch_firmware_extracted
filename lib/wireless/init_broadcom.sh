#!/bin/sh

check_country_codes()
{
  echo "Checking country codes in $2 ($1)" | tee /dev/console

  ORIG_CCODE=`wl -i $1 country|cut -d ' ' -f 2|tr '(' ' '|tr ')' ' '`

  while read line; do

    #Skip empty lines
    if [ "$line" = "" ]; then
      continue
    fi

    #Skip comments
    COMMENT=`echo $line | grep "#"`
    if [ "$COMMENT" != "" ]; then
       continue
    fi

    CCODE=`echo $line |cut -d ' ' -f 2`
    CREV=`echo $line |cut -d ' ' -f 3`
    echo -n "Checking $CCODE/$CREV --> " | tee /dev/console

    wl -i $1 country $CCODE/$CREV &> /dev/null

    if [ "$?" = "0" ]; then
      echo OK | tee /dev/console
    else
      COUNTRY_CODE_FAIL=1
      echo NOK | tee /dev/console
    fi           
           
  done < $2

  #Restore original code
  wl -i $1 country $ORIG_CCODE

}

#Check country codes and stop if they are wrong
COUNTRY_CODE_FAIL=0
if [ -f "/etc/wlan/brcm_country_map_2G" ]; then
  check_country_codes wl0 /etc/wlan/brcm_country_map_2G
  #Setting country brings interface up, continue with interface down
  wl -i wl0 down
fi

if [ -f "/etc/wlan/brcm_country_map_5G" ]; then
  check_country_codes wl1 /etc/wlan/brcm_country_map_5G
  #Setting country brings interface up, continue with interface down
  wl -i wl1 down
fi

if [ "$COUNTRY_CODE_FAIL" = "1" ]; then
  echo "############################################################################" | tee /dev/console
  echo "### ERROR. WLAN COUNTRY MAP FILES NOT CORRECT" | tee /dev/console
  echo "### --> DISABLING WLAN" | tee /dev/console
  echo "############################################################################" | tee /dev/console
  exit 1
fi

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
if [ "${PHY:0:1}" = "v" ] && [ "`wl -i wl0 phycal_tempdelta`" = "0" ]; then
  wl -i wl0 phycal_tempdelta 40
fi 

PHY=`wl -i wl1 phylist`
if [ "${PHY:0:1}" = "v" ] && [ "`wl -i wl1 phycal_tempdelta`" = "0" ]; then
  wl -i wl1 phycal_tempdelta 40
fi 

#Set phycal_tempdelta for 63168/6362 to 30 (CS3661509)
#If 0xff in SROM, the default would be 40
CHIP_TYPE=`wl -i wl0 revinfo | grep chipnum | cut -d ' ' -f 2`
if [ "$CHIP_TYPE" == "0x6362" ]; then
  wl -i wl0 phycal_tempdelta 30
fi

#Board specific config
BOARD=`uci get env.rip.board_mnemonic`

if [ "$BOARD" = "GANT-U" ] ; then
	echo "EXECUTING BOARD SPECIFIC CONFIG FOR $BOARD" > /dev/console
	wl -i wl1 phy_ed_thresh -77
fi

#DFS (radar) thresholds and args
if [ -f "/etc/wlan/brcm_dfs_cfg" ]; then
  . /etc/wlan/brcm_dfs_cfg

  if [ -n "$WL1_RADAR_ARGS" ] || [ -n "$WL1_RADAR_THRS" ]; then
    wl -i wl1 up

    if [ -n "$WL1_RADAR_ARGS" ]; then
        echo "Updating radar args" > /dev/console
        wl -i wl1 radarargs $WL1_RADAR_ARGS
    fi

    if [ -n "$WL1_RADAR_THRS" ]; then
        echo "Updating radar thresholds" > /dev/console
        wl -i wl1 radarthrs $WL1_RADAR_THRS
    fi

    wl -i wl1 down
  fi
fi

#Disable DHD logging (cannot be disabled with wl msglevel)
dhdctl -i wl0 dconpoll 0 &> /dev/null
dhdctl -i wl1 dconpoll 0 &> /dev/null

exit 0
