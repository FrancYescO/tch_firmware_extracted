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

#Fix skbFreeTask to CPU0 if 11AC is using regular driver
PID=`pidof wl1-kthrd`
if [ "$?" = "0" ] ; then
   PID=`pidof skbFreeTask`
   taskset -p 1 $PID
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

#Set phycal_tempdelta for 63168/6362 to 30 (CS3661509)
#If 0xff in SROM, the default would be 40
CHIP_TYPE=`wl -i wl0 revinfo | grep chipnum | cut -d ' ' -f 2`
if [ "$CHIP_TYPE" == "0x6362" ]; then
  wl -i wl0 phycal_tempdelta 30
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
	wl -i wl1 up
	wl -i wl1 radarthrs 0x6A8 0x30 0x6A8 0x30 0x6A8 0x30 0x6A8 0x30 0x6A8 0x30 0x6A8 0x30
	wl -i wl1 down
fi

if [ "$BOARD" = "GANT-1" ] ; then
	echo "EXECUTING BOARD SPECIFIC CONFIG FOR $BOARD" > /dev/console
	wl -i wl1 up
	wl -i wl1 radarthrs 0x690 0x18 0x690 0x18 0x690 0x18 0x690 0x18 0x690 0x18 0x690 0x18
	wl -i wl1 down
fi

if [ "$BOARD" = "GANT-2" -o "$BOARD" = "GANT-8" ] ; then
	echo "EXECUTING BOARD SPECIFIC CONFIG FOR $BOARD" > /dev/console
	wl -i wl1 up
	wl -i wl1 radarargs 2 5 45616 6 690 0x680 0x18 0x6419 0x7f09 7 600 2000 244 63568 2000 3000000 0x1e 0x8190 30528 65282 33860 5 5 0x0 128 20000000 70000000 3 12 0xa800
	wl -i wl1 radarthrs 0x690 0x18 0x68a 0x18 0x680 0x18 0x690 0x18 0x680 0x18 0x680 0x18
	wl -i wl1 down
fi

if [ "$BOARD" = "GANT-N" ] ; then
	echo "EXECUTING BOARD SPECIFIC WIFI CONFIG FOR $BOARD" > /dev/console
	wl -i wl1 up
	wl -i wl1 radarargs 2 5 45616 6 690 0x6ac 0x30 0x6419 0x7f09 6 500 2000 244 63568 2000 3000000 0x1e 0x8190 30528 65282 33860 5 5 0x31 128 20000000 70000000 5 12 0xb000
	wl -i wl1 radarthrs 0x682 0x30 0x688 0x30 0x690 0x30 0x69a 0x30 0x6a0 0x30 0x6a0 0x30
	wl -i wl1 down
fi

if [ "$BOARD" = "GANT-5" ] ; then
	echo "EXECUTING BOARD SPECIFIC WIFI CONFIG FOR $BOARD" > /dev/console
	wl -i wl1 up
	wl -i wl1 radarargs 2 5 45616 6 690 0x6ac 0x30 0x6419 0x7f09 6 500 2000 244 63568 2000 3000000 0x1e 0x8190 30528 65282 33860 5 5 0x31 128 20000000 70000000 5 12 0xa800
	wl -i wl1 radarthrs 0x682 0x30 0x688 0x30 0x690 0x30 0x69a 0x30 0x6a0 0x30 0x6a0 0x30
	wl -i wl1 down
fi

if [ "$BOARD" = "VANT-7" -o "$BOARD" = "VBNT-T" ] ; then
	echo "EXECUTING BOARD SPECIFIC WIFI CONFIG FOR $BOARD" > /dev/console
	wl -i wl1 up
	wl -i wl1 radarthrs 0x6a0 0x18 0x6a8 0x18 0x6a0 0x18 0x6a0 0x18 0x6a8 0x18 0x6a0 0x18
	wl -i wl1 down
fi

if [ "$BOARD" = "VANT-Y" ] ; then
	echo "EXECUTING BOARD SPECIFIC WIFI CONFIG FOR $BOARD" > /dev/console
	wl -i wl1 up
	wl -i wl1 radarthrs 0x6ac 0x30 0x6ac 0x30 0x6ac 0x30 0x6b4 0x30 0x6b4 0x30 0x6b4 0x30 0x6ac 0x30 0x6b4 0x30
	wl -i wl1 down
fi

if [ "$BOARD" = "VBNT-J" ] ; then
	echo "EXECUTING BOARD SPECIFIC WIFI CONFIG FOR $BOARD" > /dev/console
	wl -i wl1 up
	wl -i wl1 radarthrs 0x6ac 0x30 0x6ac 0x30 0x6ac 0x30 0x6ac 0x30 0x6ac 0x30 0x6ac 0x30 0x6ac 0x30 0x6ac 0x30
	wl -i wl1 down
fi

if [ "$BOARD" = "VBNT-R" ] ; then
        echo "EXECUTING BOARD SPECIFIC WIFI CONFIG FOR $BOARD" > /dev/console
        wl -i wl1 up
        wl -i wl1 radarthrs 0x698 0x30 0x698 0x30 0x698 0x30 0x698 0x30 0x698 0x30 0x698 0x30
        wl -i wl1 down           
fi

#Disable DHD logging (cannot be disabled with wl msglevel)
dhdctl -i wl0 dconpoll 0 &> /dev/null
dhdctl -i wl1 dconpoll 0 &> /dev/null

exit 0
