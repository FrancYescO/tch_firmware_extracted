#!/bin/sh

# To parse ubus output
. /usr/share/libubox/jshn.sh

get_state()
{
	obj=$1
	name=$2
	json_init

	UBUS_CMD="ubus -S call wireless.$obj get '$(json_dump)'"
	OUTPUT=$(eval $UBUS_CMD)
	json_load "$OUTPUT"
	json_select "$name"
	json_get_vars admin_state
	json_get_vars oper_state
	echo $admin_state/$oper_state
}

get_cap_from_radio ()
{
	radio=$1
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
	radio=$1
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
	ssid=$1
	json_init

	UBUS_CMD="ubus -S call wireless.ssid get '$(json_dump)'"
	OUTPUT=$(eval $UBUS_CMD)
	json_load "$OUTPUT"
	json_select "$ssid"
	json_get_vars radio
	echo $radio
}

get_ssid_from_ssid ()
{
	ssid=$1
	json_init

	UBUS_CMD="ubus -S call wireless.ssid get '$(json_dump)'"
	OUTPUT=$(eval $UBUS_CMD)
	json_load "$OUTPUT"
	json_select "$ssid"
	json_get_vars ssid
	echo $ssid
}

get_ba_fr_from_ssid ()
{
	ssid=$1
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
	ssid=$1
	json_init

	UBUS_CMD="ubus -S call wireless.ssid get '$(json_dump)'"
	OUTPUT=$(eval $UBUS_CMD)
	json_load "$OUTPUT"
	json_select "$ssid"
	json_get_vars mode
	echo $mode
}

echo -e  "\nOverview APs"
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
		ssid_str=$(get_ssid_from_ssid $ssid)

		column1="$ap, $ap_state_str"
		column2="$ssid, $ssid_state_str, $mode, $ssid_ba_fr_str, $ssid_str"
		column3="$radio, $radio_state_str, $radio_channel, $radio_cap"
		printf "%-15s | %-50s | %-50s\n" "$column1" "$column2" "$column3"
	fi
done

echo -e  "\nOverview STAs"
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
		ssid_state_str=$(get_state ssid $ssid)
		radio_state_str=$(get_state radio $radio)

		echo "$ssid($ssid_state_str) ($mode) - $radio($radio_state_str) ==$radio_cap=="
	fi
done
