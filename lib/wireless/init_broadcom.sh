#!/bin/sh

mapped_wl_if()
{
    #wlif is the wl interface defined by hostapd
    #bcmif is the wl interface defined by Broadcom device driver
    wlidx=$2  # Start of the wl index
    i=0
    while [ "$wlidx" -lt 3 ]; do
        #bcmif="wl$i"
        wlif="wl$wlidx"
        while [ "$i" -lt 3 ];
        do
            bcmif="wl$i"
            if [ $1 = "NIC" ]; then
                dhd -i $bcmif msglevel
                if [ "$?" = "1" ]; then
                    echo "NIC wl: $wlif mapped to bcm: $bcmif"
                    echo $bcmif >/tmp/$wlif
                    wlidx=`expr $wlidx + 1` #switch to next wl idx
                    i=`expr $i + 1`
                    break 1;
                fi
            else
                dhd -i $bcmif msglevel
                if [ "$?" = "0" ]; then
                    echo "DHD wl: $wlif mapped to bcm: $bcmif"
                    echo $bcmif >/tmp/$wlif
                    wlidx=`expr $wlidx + 1` #switch to next wl idx
                    i=`expr $i + 1`
                    break 1;
                fi
            fi
            i=`expr $i + 1`
       done
       if [ "$i" -ge 3 ]; then
           break 1
       fi
   done
}

check_country_codes()
{
  ifname=$1
  [ -e /tmp/$1 ] && ifname=`cat /tmp/$1`

  echo "wl ifname $1 mapped to $ifname"

  echo "Checking country codes in $2 ($ifname)" | tee /dev/console

  ORIG_CCODE=`wl -i $ifname country|cut -d ' ' -f 2|tr '(' ' '|tr ')' ' '`

  wl -i $ifname down

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

    wl -i $ifname country $CCODE/$CREV &> /dev/null

    if [ "$?" = "0" ]; then
      echo OK | tee /dev/console
    else
      COUNTRY_CODE_FAIL=1
      echo NOK | tee /dev/console
    fi           
           
  done < $2

  #Restore original code
  wl -i $ifname country $ORIG_CCODE
  #Setting country brings interface up, continue with interface down
  wl -i $ifname down

}

#Mapped wl ifname with brcm driver ifname, if possible
if [ -f "/usr/bin/dhd" ]; then
    for i in 0 1 2
    do
        rm -f /tmp/wl$i
    done
    # Search interface in NIC mode
    mapped_wl_if "NIC" 0

    # Search for the missing interface
    for i in 0 1 2
    do
        bcmif="wl$i"
        if [ ! -f "/tmp/$bcmif" ]; then
            mapped_wl_if "DHD" $i
            break 1
        fi
    done
fi

#Check country codes and stop if they are wrong
COUNTRY_CODE_FAIL=0
if [ -f "/etc/wlan/brcm_country_map_2G" ]; then
  check_country_codes wl0 /etc/wlan/brcm_country_map_2G
fi

if [ -f "/etc/wlan/brcm_country_map_5G" ]; then
  check_country_codes wl1 /etc/wlan/brcm_country_map_5G
fi

if [ -f "/etc/wlan/brcm_country_map_radio2" ]; then
  check_country_codes wl2 /etc/wlan/brcm_country_map_radio2
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
wl -i wl2 nar 0

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

#PHYREG
if [ -f "/etc/wlan/brcm_phy_cfg" ]; then
  . /etc/wlan/brcm_phy_cfg

  if [ -n "$WL1_PHYREG_ARGS" ]; then
    wl -i wl1 up
    echo "Updating wl1 PHYREG args" > /dev/console
    wl -i wl1 phyreg $WL1_PHYREG_ARGS
    wl -i wl1 down
  fi
  if [ -n "$WL2_PHYREG_ARGS" ]; then
    wl -i wl2 up
    echo "Updating wl2 PHYREG args" > /dev/console
    wl -i wl2 phyreg $WL2_PHYREG_ARGS
    wl -i wl2 down
  fi
fi

#DFS (radar) thresholds and args
if [ -f "/etc/wlan/brcm_dfs_cfg" ]; then
  . /etc/wlan/brcm_dfs_cfg

  if [ -n "$WL1_RADAR_ARGS" ] || [ -n "$WL1_RADAR_THRS" ]; then
    wl -i wl1 up

    if [ -n "$WL1_RADAR_ARGS" ]; then
        echo "Updating wl1 radar args" > /dev/console
        wl -i wl1 radarargs $WL1_RADAR_ARGS
    fi

    if [ -n "$WL1_RADAR_THRS" ]; then
        echo "Updating wl1 radar thresholds" > /dev/console
        wl -i wl1 radarthrs $WL1_RADAR_THRS
    fi

    wl -i wl1 down
  fi
  if [ -n "$WL2_RADAR_ARGS" ] || [ -n "$WL2_RADAR_THRS" ]; then
    wl -i wl2 up

    if [ -n "$WL2_RADAR_ARGS" ]; then
        echo "Updating wl2 radar args" > /dev/console
        wl -i wl2 radarargs $WL2_RADAR_ARGS
    fi

    if [ -n "$WL2_RADAR_THRS" ]; then
        echo "Updating wl2 radar thresholds" > /dev/console
        wl -i wl2 radarthrs $WL2_RADAR_THRS
    fi

    wl -i wl2 down
  fi
fi

#Setting watchdog timeout to 70s
nvram set watchdog=70000
nvram commit

#Disable DHD logging (cannot be disabled with wl msglevel)
dhdctl -i wl0 dconpoll 0 &> /dev/null
dhdctl -i wl1 dconpoll 0 &> /dev/null
dhdctl -i wl2 dconpoll 0 &> /dev/null

exit 0
