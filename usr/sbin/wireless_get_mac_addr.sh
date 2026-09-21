#!/bin/sh

# print the base mac addr per radio
# only valid for Broadcom

radio="$1"

function get_mac_addr()
{	
	local radio="$1"
	local UNIQUE_MAC="$2"

        # convert unique wifi mac to local wifi mac addr
        L_WL_MAC="$(printf "%02X" $((0x${UNIQUE_MAC:0:2} | 0x02)))${UNIQUE_MAC:2}"

        # obtain last 2 digits
        B5=${L_WL_MAC:10:2}

        # calculate offsets 0, 1 and 2
        OFFSET0=$(printf '%X' $((0x$B5 % 16)))
        OFFSET1=$(printf '%X' $(((0x$B5 + 1) % 16)))
        OFFSET2=$(printf '%X' $(((0x$B5 + 2) % 16)))
        #echo "B5=$B5 OFFSET0=$OFFSET0 OFFSET1=$OFFSET1 OFFSET2=$OFFSET2"

        # calculate B4u
        B4U=`echo "$(printf '%X' $((0x${L_WL_MAC:8:1})))"`

        XOFFSET0=`echo "$(printf '%X' $((0x${B4U} ^ 0x$OFFSET0)))" | tr [a-z] [A-Z]`
        XOFFSET1=`echo "$(printf '%X' $((0x${B4U} ^ 0x$OFFSET1)))" | tr [a-z] [A-Z]`
        XOFFSET2=`echo "$(printf '%X' $((0x${B4U} ^ 0x$OFFSET2)))" | tr [a-z] [A-Z]`
        #echo "B4U=$B4U XOFFSET0=$XOFFSET0 XOFFSET1=$XOFFSET1 XOFFSET2=$XOFFSET2"

        WL1_B5=$(printf '%X' $(((0x$B5 + 8) % 256)))
        WL2_B5=$(printf '%X' $(((0x$B5 + 16) % 256)))
        #echo "WL1_B5=$WL1_B5 WL2_B5=$WL2_B5"

        WL0_B4=${XOFFSET0}${UNIQUE_MAC:9:1}
        WL1_B4=${XOFFSET0}${UNIQUE_MAC:9:1}
        WL2_B4=${XOFFSET1}${UNIQUE_MAC:9:1}
        #echo "WL0_B4=$WL0_B4 WL1_B4=$WL1_B4 WL2_B4=$WL2_B4"

        # Calculate base mac addr for each radio
        WL0_MAC="${L_WL_MAC:0:8}${WL0_B4}${B5}"
        WL1_MAC="${L_WL_MAC:0:8}${WL1_B4}${WL1_B5}"
        WL2_MAC="${L_WL_MAC:0:8}${WL2_B4}${WL2_B5}"
        #echo "WL0_MAC=$WL0_MAC  WL1_MAC=$WL1_MAC WL2_MAC=$WL2_MAC"

        # Convert to correct format
        if [ "$radio" == "radio2" ]; then
		echo $WL2_MAC
	elif [ "$radio" == "radio_5G" ]; then
		echo $WL1_MAC
	else
		echo $WL0_MAC
	fi
}

# obtain unique wifi mac and remove : and convert to uppercase
wifi_mac_rip=`uci get env.rip.wifi_mac | sed 's/://g' | awk '{print toupper($0)}'`
radio_mac=$(get_mac_addr $radio $wifi_mac_rip)

echo $radio_mac
	
