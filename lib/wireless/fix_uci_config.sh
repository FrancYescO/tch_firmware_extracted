#!/bin/sh

# UCI fixes

need_commit=0

# 1) Make sure the wifi-iface object has a mode parameter

check_mode_parameter()
{
    iface=$1

    uci get wireless.$iface > /dev/null 2> /dev/null

    if [ "$?" = "0" ] ; then

        uci get wireless.$iface.mode > /dev/null 2> /dev/null
        if [ "$?" != "0" ] ; then
            uci set wireless.$iface.mode=ap
            need_commit=1    
        fi
    fi
}

for iface in wl0 wl0_1 wl0_2 wl0_3 wl1 wl1_1 wl1_2 wl1_3 wl2 wl2_1 wl2_2 wl2_3
do
    check_mode_parameter $iface
done


check_wep_key()
{
    ap=$1

    key_ok=0

    key=`uci get wireless.$ap.wep_key 2> /dev/null`
    if [ "$?" != "0" ] ; then
        return
    fi

    len=${#key}

    if [ "$len" == "5" ] || [ "$len" == "13" ]; then
        #ASCII  
        key_ok=1
    fi

    if [ "$len" == "10" ] || [ "$len" == "26" ]; then
        #HEX -> check chars
        TEST=`echo $key | tr '0123456789ABCDEFabcdef' '0'`

        if [ "$TEST" = "0000000000" ] || [ "$TEST" = "00000000000000000000000000" ]; then
            key_ok=1
        fi
    fi

    if [ "$key_ok" = "0" ]; then
        new_key=`uci get env.var.default_wep_key_r0_s0`
        echo "$0: Invalid wep key $key for $ap, replacing." > /dev/console
        uci set wireless.$ap.wep_key=$new_key
        need_commit=1
    fi
}

# 2) Make sure wep is valid (on boards where CWAPL does not contain valid WEP key). Limit to generic (ap0+1)
for ap in ap0 ap1
do 
    check_wep_key $ap
done

# 3) Temporarily fix radio type for MDM9x07 (first boot script can't detect radio type yet because wlan driver not yet loaded)
RADIO_TYPE=`wireless_get_radio_type.sh radio_2G`
if [ "$RADIO_TYPE" = "qcacld" ] ; then
  echo "$0: set radio type to qcacld" > /dev/console
  uci set wireless.radio_2G.type=qcacld
  need_commit=1
fi

# Commit if needed
if [ "$need_commit" = "1" ]; then
    echo "Fixed wireless uci config" > /dev/console
    uci commit wireless
fi
