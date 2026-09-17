#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh

NAME=ledfw

load_ledcontrol()
{
  local name="$1"
  enable=$(uci -q get ledfw.$name.enable)

  if [ ! -z "${enable}" ] && [ "${enable}" -eq "1" ]
  then
    if [ "$name" == "internalphy" ];
    then
      echo '255' | tee /sys/class/leds/NetLed*/brightness >/dev/null
    else
      reg=$(uci -q get ledfw.$name.phy_ledctl_reg)
      id=$(uci -q get ledfw.$name.phy_eth_id)
      dev=$(uci -q get ledfw.$name.phy_dev_ad)
      ledcfg_reg=$(uci -q get ledfw.$name.ledcfg_reg)
      mode=$(uci -q get ledfw.$name.led_enable_mode)
      if [ ! -z "${reg}" ] && [ ! -z "${mode}" ] && [ ! -z "${id}" ] && [ ! -z "${dev}" ];
      then
        echo write45 $id $dev $reg $mode > /proc/driver/phy/cmd
      fi
      if [ ! -z "$ledcfg_reg" ]; then
        i=1
	while [ "$i" -le "$ledcfg_reg" ];
	do
	  reg_var=$(printf 'ledfw.%s.phy_ledctl_reg_%d' $name $i)
	  data_var=$(printf 'ledfw.%s.phy_ledctl_data_%d' $name $i)
          reg=$(uci -q get "$reg_var")
          data=$(uci -q get "$data_var")
          echo write45 $id $dev $reg $data > /proc/driver/phy/cmd
          i=$(( i + 1 ))
	done
      fi
    fi
  else
    if [ "$name" == "internalphy" ];
    then
      echo '0' | tee /sys/class/leds/NetLed*/brightness >/dev/null
    else
      reg=$(uci -q get ledfw.$name.phy_ledctl_reg)
      id=$(uci -q get ledfw.$name.phy_eth_id)
      dev=$(uci -q get ledfw.$name.phy_dev_ad)
      mode=$(uci -q get ledfw.$name.led_disable_mode)
      if [ ! -z "${reg}" ] && [ ! -z "${mode}" ] && [ ! -z "${id}" ] && [ ! -z "${dev}" ];
      then
        echo write45 $id $dev $reg $mode > /proc/driver/phy/cmd
      fi
    fi
  fi
}

config_load "${NAME}"

config_foreach load_ledcontrol led_control

