#!/bin/sh

#get all config instances for a given config type
#$1 config Example: "wireless"
#$2 config_type Example: "wifi-ap"
_get_instance_name(){
	local config="$1"
	local type="$2"
	local tmp_config=`uci show $1 | grep $2`
	local instance=""

	for i in $tmp_config
	do
		cut_conf=`echo $i | cut -d= -f2`
		if [ "$cut_conf" == "$type" ]
		then
			get_instance=`echo $i | cut -d. -f2 | cut -d= -f1`
			#echo $get_instance
			if [ -z "$instance" ]
			then
				instance="$get_instance"
			else
				instance="$instance $get_instance"
			fi

		fi
	done

	echo "$instance"
}

#can be used only for instances which will be counted up. For example ap0 ap1 ap2 or wl0 wl1 or wl0_1 wl0_2
#The function will then return the first free instance name
#$1 from where to start iteration (number), iterate from 1
#$2 end value (upper ceiling) (number), iterate to 10 (10 will be included)
#$3 for which prefix need to be searched, example wl0_X, the wl0_ is the prefix
#$4 a string containing all existing instances, separated by a space
_get_next_free(){
	local start=$1
	local stop=$2
	local search_string="$3"
	local all_instances="$4"
	local found="0"
	local candidate=""

	while [[ $start -le $stop ]]
	do
		found="0"
		for h in $all_instances
		do
			if [ "$h" == "$search_string$start" ]
			then
				found="1"
				break
			fi
		done

		if [ "$found" == "0" ]
		then
			candidate="$search_string$start"
			break
		fi
		let start=start+1
	done

	echo "$candidate"
}

#This function will check, if the backhaul for the specific radio exist
#$1 radio (radio_5G, radio_2G or radio2)
#return:
#0 0 -> no backhaul, no instance
#1 $i -> backhaul=1,instance of backhaul
#2 $i -> backhaul=1 and fraunthaul=1, instance of backhaul
_check_backhaul_value(){
	local config="wireless"
	local type="wifi-iface"
	local radio="$1"
	local wl_conf=""
	local return="0 0"

	if [ "$radio" == "radio_2G" ]
	then
		wl_conf="wl0"
	elif [ "$radio" == "radio_5G" ]
	then
		wl_conf="wl1"
	elif [ "$radio" == "radio2" ]
	then
		wl_conf="wl2"
	fi

	local instances=$(_get_instance_name "$config" "$type")

	for i in $instances
	do
		local tmp_inst=$(echo $i | grep $wl_conf)
		if [ ! -z "$tmp_inst" ]
		then
			local tmp_backhaul=`uci -q get $config.$i.backhaul`
			if [ "$tmp_backhaul" == "1" ]
			then
				local tmp_fronthaul=`uci -q get $config.$i.fronthaul`
				if [ "$tmp_fronthaul" == "1" ]
				then
					return="2 $i"
				else
					return="1 $i"
				fi
			fi
		fi
	done

	echo "$return"
}

#iterate over an string and add postfix
#$1 string Example: "$(uci get -q network.lan.ifname)" or direct the content "eth0 eth1 eth2"
#$2 string which is the postfix that should be added
_add_postfix(){
  local string="$1"
  local mod="$2"
  local result=""

  for i in $string
  do
    if [ "$result" == "" ]
    then
      result="$i$mod"
    else
      result="$result $i$mod"
    fi
  done

  echo "$result"
}

#iterate over string and return only matched filter entry
#$1 string which is the filter Example: "eth[0-2]" return everything with eth0, eth1 and eth2
#$2 string Example: "$(uci get -q network.lan.ifname)" or direct the content "eth0 eth1 eth2"
_filter_for(){
  local filter="$1"
  local string="$2"
  local result=""

  for i in $string
  do
    local tmp_val=$(echo $i | grep $filter)
    if [ ! -z "$tmp_val" ]
		then
      if [ "$result" == "" ]
      then
        result="$i$mod"
      else
        result="$result $i$mod"
      fi
    fi
  done

  echo $result
}
