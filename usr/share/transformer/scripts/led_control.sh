#!/bin/sh

reg=$(uci -q get ledfw.ethernet.phy_ledctl_reg)
id=$(uci -q get ledfw.ethernet.phy_eth_id)
dev=$(uci -q get ledfw.ethernet.phy_dev_ad)
enable=$(uci -q get ledfw.ethernet.enable)
ledcfg_reg=$(uci -q get ledfw.ethernet.ledcfg_reg)

if [ ! -z "${enable}" ] && [ "${enable}" -eq "1" ]
then
  echo '255' | tee /sys/class/leds/NetLed*/brightness >/dev/null
  mode=$(uci -q get ledfw.ethernet.led_enable_mode)
  if [ ! -z "${reg}" ] && [ ! -z "${mode}" ] && [ ! -z "${id}" ] && [ ! -z "${dev}" ];
  then
      echo write45 $id $dev $reg $mode > /proc/driver/phy/cmd
  fi
  if [ ! -z "$ledcfg_reg" ]; then
	i=1
	while [ "$i" -le "$ledcfg_reg" ];
	do
		reg_var=$(printf 'ledfw.ethernet.phy_ledctl_reg_%d' $i)
		data_var=$(printf 'ledfw.ethernet.phy_ledctl_data_%d' $i)
		reg=$(uci -q get "$reg_var")
		data=$(uci -q get "$data_var")
		echo write45 $id $dev $reg $data > /proc/driver/phy/cmd
		i=$(( i + 1 ))
	done
  fi
  ubus send led.night_mode '{"state":"off"}'
else
  echo '0' | tee /sys/class/leds/NetLed*/brightness >/dev/null
  mode=$(uci -q get ledfw.ethernet.led_disable_mode)
  if [ ! -z "${reg}" ] && [ ! -z "${mode}" ] && [ ! -z "${id}" ] && [ ! -z "${dev}" ];
  then
      echo write45 $id $dev $reg $mode > /proc/driver/phy/cmd
  fi
  ubus send led.night_mode '{"state":"on"}'
fi
