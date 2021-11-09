#!/bin/sh

# To parse ubus output
. /usr/share/libubox/jshn.sh

get_state()
{
	local obj=$1
	local name=$2
	json_init

	UBUS_CMD="ubus -S call wireless.$obj get '$(json_dump)'"
	OUTPUT=$(eval $UBUS_CMD)
	json_load "$OUTPUT"
	json_select "$name"
	json_get_vars admin_state
	json_get_vars oper_state
	echo $admin_state/$oper_state
}

is_brcm_radio()
{
	local interface=$1

	wl -i $interface status &> /dev/null
	if [ "$?" -eq 0 ]; then
		echo "1"
	else
		echo "0"
 	fi
}

cac_remain_timing()
{
	local interface=$1

        dfs_status=`wl -i $interface dfs_status | grep 'Channel Availability Check'`
        if [ ! -z "$dfs_status" ]; then
		remaining_time=`echo $dfs_status | sed 's/^.*elapsed//' | sed 's/ms.*//' | cut -f 2 -d" "`
		echo $((60 - remaining_time/1000))
	else
		echo ""
	fi
}

get_cap_from_radio ()
{
	local radio=$1
	json_init

	UBUS_CMD="ubus -S call wireless.radio get '$(json_dump)'"
	OUTPUT=$(eval $UBUS_CMD)
	json_load "$OUTPUT"
	json_select "$radio"
	json_get_vars capabilities
	echo $capabilities
}

get_chan_from_radio ()
{
	local radio=$1
	json_init

	UBUS_CMD="ubus -S call wireless.radio get '$(json_dump)'"
	OUTPUT=$(eval $UBUS_CMD)
	json_load "$OUTPUT"
	json_select "$radio"
	json_get_vars channel
	echo $channel
}

get_radio_from_ssid ()
{
	local ssid=$1
	json_init

	UBUS_CMD="ubus -S call wireless.ssid get '$(json_dump)'"
	OUTPUT=$(eval $UBUS_CMD)
	json_load "$OUTPUT"
	json_select "$ssid"
	json_get_vars radio
	echo $radio
}

get_iface_from_ssid ()
{
	local ssid=$1
	json_init

	UBUS_CMD="ubus -S call wireless.ssid get '$(json_dump)'"
	OUTPUT=$(eval $UBUS_CMD)
	json_load "$OUTPUT"
	json_select "$ssid"
	json_get_vars ssid
	echo $ssid
}

get_mac_addr_from_ssid()
{
        local ssid=$1                                            
        json_init                                                                                         
                                                                 
        UBUS_CMD="ubus -S call wireless.ssid get '$(json_dump)'"                                          
        OUTPUT=$(eval $UBUS_CMD)                                 
        json_load "$OUTPUT"                                                                               
        json_select "$ssid"                                      
        json_get_vars mac_address
        echo $mac_address
}

get_ssid_from_ep () {

	local ep=$1
	json_init

	UBUS_CMD="ubus -S call wireless.endpoint get '$(json_dump)'"
	OUTPUT=$(eval $UBUS_CMD)
	json_load "$OUTPUT"
	json_select "$ep"
	json_get_vars ssid
	echo $ssid
}

get_ep_from_ssid ()
{                    
        local ssid=$1                                            
        json_init               
        UBUS_CMD="ubus -S call wireless.endpoint get '$(json_dump)'"
        OUTPUT=$(eval $UBUS_CMD)

        json_load "$OUTPUT" 2> /dev/null
        json_get_keys keys 2> /dev/null
        for k in $keys; do    
        	json_get_var v "$k"  
		temp=$(get_ssid_from_ep $k)
		if [ "$temp" == "$ssid" ]; then
			echo "$k"
			return
		fi
	
        done               
        echo ""
} 

get_ba_fr_from_ssid ()
{
	local ssid=$1
	json_init

	UBUS_CMD="ubus -S call wireless.ssid get '$(json_dump)'"
	OUTPUT=$(eval $UBUS_CMD)
	json_load "$OUTPUT"
	json_select "$ssid"
	json_get_vars backhaul
	json_get_vars fronthaul
	if [ "$backhaul" == "1" ]; then
		echo -n "B"
	fi
	if [ "$fronthaul" == "1" ]; then
		echo -n "F"
	fi
}

get_mode_from_ssid ()
{
	local ssid=$1
	json_init

	UBUS_CMD="ubus -S call wireless.ssid get '$(json_dump)'"
	OUTPUT=$(eval $UBUS_CMD)
	json_load "$OUTPUT"
	json_select "$ssid"
	json_get_vars mode
	echo $mode
}

for i in $(seq 0 15); do
	ap="ap$i"
	json_init

	UBUS_CMD="ubus -S call wireless.accesspoint get '$(json_dump)'"
	OUTPUT=$(eval $UBUS_CMD)
	json_load "$OUTPUT" &> /dev/null
	json_select "$ap" &> /dev/null
	json_get_vars ssid &> /dev/null
	if [ "$?" -eq 0 ]; then
		radio=$(get_radio_from_ssid $ssid)
		mode=$(get_mode_from_ssid $ssid)
		radio_cap=$(get_cap_from_radio $radio)

		ap_state_str=$(get_state accesspoint $ap)
		ssid_state_str=$(get_state ssid $ssid)
		radio_state_str=$(get_state radio $radio)
		radio_channel=$(get_chan_from_radio $radio)

		ssid_ba_fr_str=$(get_ba_fr_from_ssid $ssid)		
		iface_str=$(get_iface_from_ssid $ssid)

                if [ "$(is_brcm_radio $ssid)" == "1" ]; then
			brcm_state=" `wl -i $ssid bss` $(cac_remain_timing $ssid)"
		else
			brcm_state=""
		fi
                mac_addr=$(get_mac_addr_from_ssid $ssid)
		column1="$ap, $ap_state_str $mac_addr $brcm_state"
		column2="$ssid, $ssid_state_str, $mode, $ssid_ba_fr_str, $iface_str"
		column3="$radio, $radio_state_str, $radio_channel, $radio_cap"
		printf "%-35s | %-40s | %-50s\n" "$column1" "$column2" "$column3"
	fi
done

for i in $(seq 0 15); do
	ssid="wl$i"
	json_init

	UBUS_CMD="ubus -S call wireless.ssid get '$(json_dump)'"
	OUTPUT=$(eval $UBUS_CMD)
	json_load "$OUTPUT" &> /dev/null
	json_select "$ssid" &> /dev/null
	json_get_vars mode &> /dev/null
	if [ "$?" -eq 0  ] && [ "$mode" == "sta" ]; then
		radio_cap=$(get_cap_from_radio $radio)
		radio_state_str=$(get_state radio $radio)
		ssid_state_str=$(get_state ssid $ssid)
		ep=$(get_ep_from_ssid $ssid)
		if [ ! -z $ep ]; then
			ep_state_str=", $(get_state endpoint $ep)"
		else
			ep_state_str=""
		fi
                mac_addr=$(get_mac_addr_from_ssid $ssid)
		column1="$ep$ep_state_str $mac_addr"
		column2="$ssid, $ssid_state_str, sta"
		column3="$radio, $radio_state_str $radio_cap"
		printf "%-35s | %-40s | %-50s\n" "$column1" "$column2" "$column3"
	fi
done
