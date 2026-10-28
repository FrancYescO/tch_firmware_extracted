#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh
NAME=ledfw

led_update_brightness() {
	local section="$1"
	local color="$2"
	config_get name $section name
	config_get brightness $section $color
	if [ -n "$brightness" ]; then
		local currentbright=$(cat /sys/class/leds/${name}\:${color}/brightness)
		if [ "$currentbright" != "0" -a "$currentbright" != "$brightness" ]; then
			echo $brightness > /sys/class/leds/${name}\:${color}/brightness
		fi
	fi
}

leds_update_brightness() {
	led_update_brightness "$1" "red"
	led_update_brightness "$1" "green"
	led_update_brightness "$1" "blue"
	led_update_brightness "$1" "orange"
	led_update_brightness "$1" "magenta"
	led_update_brightness "$1" "cyan"
	led_update_brightness "$1" "white"
}

config_load "${NAME}"

config_foreach leds_update_brightness brightness

ubus send led.brightness '{"updated":"1"}'
