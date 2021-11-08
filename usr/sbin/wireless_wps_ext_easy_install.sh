#!/bin/sh

DRYRUN=0

# To parse ubus output
. /usr/share/libubox/jshn.sh

bin=${0##*/}

#all aps defined in UCI
aps=""

mode=""
role="" #ap/repeater
ep_profile=""
policy="2"

echo_with_logging()
{
	logger "[$bin]: $@"
	echo "[$bin]: $@"
}

print_help()
{
        echo "Easy install logic"
        echo "  Legacy mode  : copy wifi credentials from given EP profile to fronthaul APs"
        echo "  Easymesh mode: enable EM Agent"
        echo "Usage:"
        echo "  $bin -m <mode>  -r <role> -e <epX_profileY>'"

	exit 1
}

check_obj_exists()
{
	local obj=$1
	
	uci get wireless.$obj &> /dev/null

	if [ $? -eq 0 ]; then
		echo "1"
	else
		echo "0"
	fi
}

get_iface_from_ap()
{
	local ap=$1

	iface=$(uci get wireless.$ap.iface 2> /dev/null)
	if [ $? -eq 0 ]; then
		echo "$iface"
	else
		echo ""
	fi
}

get_radio_from_iface()
{
	local iface=$1

	radio=$(uci get wireless.$iface.device 2> /dev/null)
	if [ $? -eq 0 ]; then
		echo "$radio"
	else
		echo ""
	fi
}

is_security_method_supported()
{
	local ap=$1
	local security_method="$2"
	local supported_security_methodes=$(uci get wireless.$ap.supported_security_modes 2> /dev/null)
        
	for mode in ${supported_security_methodes}; do
		if [ "$security_method" == "$mode" ]; then
			echo "1"
			return
		fi
	done
	
	echo "0"
}

set_security_method()
{
	local ap=$1 #ap or cred
	local is_cred=$2
	local security_method="$3"

	if [ "$is_cred" == "1" ]; then
		# cred mode
		
		echo_with_logging "Configure security method=$security_method for $ap"
		uci set multiap.${ap}.security_mode="$security_method"
	else
		# ap mode

		if [ $(is_security_method_supported $ap $security_method) == 0 ]; then
			echo_with_logging "$ap doesn't support '$security_method' => disabling AP"
			uci set wireless.$ap.state=0
			uci set wireless.$ap.security_mode="wpa2-psk"
		else
			uci set wireless.$ap.security_mode="$security_method"
		fi
	fi
}

read_ep_profile()
{
	local ep=$1
	local param=$2

	local value=$(uci get wireless.$ep.$param 2> /dev/null)
	if [ $? -eq 0 ]; then
		echo "$value"
	else
		echo ""
	fi
}

get_device_role()
{
        json_init

        UBUS_CMD="ubus -S call wireless.supplicant get '$(json_dump)'"
        OUTPUT=$(eval $UBUS_CMD)
        json_load "$OUTPUT"
        json_get_vars role
        echo $role
}

configure_ap_security()
{
	local ap="$1" # can be apX or credX
	local is_cred="$2"
	local security_mode="$3"
	local bssid_cap="$4"

        if [ "$security_mode" == "none" ]; then
                set_security_method $ap $is_cred "none"
        elif [ "$security_mode" == "wpa-wpa2-psk" ]; then
                # wpa2 psk or wpa wpa2 psk

                # get passphrase
                wpa_psk_key=$(read_ep_profile $ep wpa_psk_key)

		# set passphrase
		if [ "$is_cred" == "1" ]; then
			uci set multiap.$ap.wpa_psk_key="$wpa_psk_key"
		else
	                uci set wireless.$ap.wpa_psk_key="$wpa_psk_key"
		fi

                #set security method
                if [ -z "${bssid_cap##*SAE*}" ]; then
                        #WPA3

                        set_security_method $ap $is_cred "wpa2-wpa3-psk"
			if [ "$is_cred" == "0" ]; then
	                        cred_profile="${ap}_credential0"
	                        uci set wireless.${cred_profile}=wifi-ap-credential
	                        uci set wireless.${cred_profile}.passphrase="$wpa_psk_key"
        	                uci set wireless.${cred_profile}.state=1
			fi
                elif [ -z "${bssid_cap##*WPA-PSK-TKIP*}" ]; then
                        #WPA WPA2 PSK
			if [ "$is_cred" == "0" ]; then
	                        # check if security method supported
        	                if [ $(is_security_method_supported $ap $security_mode) == 0 ]; then
                	                security_mode="wpa2-psk"
	                        fi
			fi
 			set_security_method $ap $is_cred "$security_mode"
                else
                        #WPA2 PSK
	                set_security_method $ap $is_cred "wpa2-psk"
                fi

                # configure pmf
		if [ "$is_cred" == "0" ]; then
	                configure_ap_pmf $ap "$bssid_cap"
		fi
		return 0
        else
                return 1
        fi
}

configure_ap_pmf()
{
	local ap="$1"
	local bssid_cap="$2"
	
	# config pmf
	if [ -z "${bssid_cap##*PMF-REQUIRED*}" ]; then
		uci set wireless.${ap}.pmf=required;
	elif [ -z "${bssid_cap##*PMF-ENABLED*}" ]; then
		uci set wireless.${ap}.pmf=enabled;
	else
		uci set wireless.${ap}.pmf=disabled;
	fi
}

configure_ap()
{
	local ap=$1 #apX or credX
	local ep=$2
	local is_cred=0
	local iface=""

       if [ ! -z "${ap##*ap*}" ]; then
                # cred mode
		is_cred=1
	fi

        if [ "$is_cred" == "0" ]; then
		# check if ap contains a valid ssid and radio uci obj
		iface=$(get_iface_from_ap $ap)
		if [ "$iface" == "" ]; then
			return 1
		fi

		if [ $(check_obj_exists $iface) == "0" ]; then
			return 1
		fi

		local radio=$(get_radio_from_iface $iface)
		if [ $(check_obj_exists $radio) == "0" ]; then
			return 1
		fi
	fi
	
	echo_with_logging "Configure ap=$ap ep=$ep is_cred=$is_cred iface=$iface"

	# read security mode
	security_mode=$(read_ep_profile $ep security_mode)

	# read ssid
	ssid=$(read_ep_profile $ep ssid)

	# set ssid
	echo_with_logging "Configure ssid=$ssid"
	if [ "$is_cred" == "0" ]; then
		uci set wireless.$iface.ssid="$ssid"
	else
		uci set multiap.${ap}.ssid="$ssid"
	fi

	# obtain bssid cap
        bssid=$(wpa_cli status | grep ^bssid= | cut -f 2 -d=)
        bssid_cap=`wpa_cli scan_results | grep "^$bssid"  | awk '{print $4}'`

	configure_ap_security $ap $is_cred "$security_mode" "$security_mode"
	ret=$?

	if [ "$is_cred" == "0" ]; then
		if [ "$ret" -eq 0 ]; then
		        wl -i $iface bss up
		else
			# error -> disable $iface
			echo_with_logging "error while configuring $iface -> bringing it down"
			wl -i $iface bss down
		fi
	fi

	return 0
}

wifi_ap_parse() {
	local ap=`echo ${1}`

	if [ "$aps" == "" ]; then
		aps="${ap}"
	else
		aps="${aps} ${ap}"
	fi
}

get_all_aps() {

	. /lib/functions.sh

	config_load wireless
	config_get iface "$config" ifname
	config_foreach wifi_ap_parse wifi-ap
}

set_operation() {
	local set1="$1"
	local set2="$2"
	local is_intersection="$3"
	local result=""

	for s1 in ${set1}; do
		found=0
		for s2 in ${set2}; do
			if [ "$s1" == "$s2" ]; then
				found=1
			fi	
		done
		
		if [ "${found}" == "${is_intersection}" ]; then
			result="$result $s1"
		fi
	done

	echo $result
}

set_intersection() {
	local set1="$1"
	local set2="$2"
	local result=$(set_operation "${set1}" "${set2}" 1)

	echo $result
}

set_complement() {
	local set1="$1"
	local set2="$2"
	local result=$(set_operation "${set1}" "${set2}" 0)

	echo $result
}

get_home_ap_list(){
	if [ "`uci get wireless.wl1.mode 2>/dev/null `" == "sta" ]; then
		# 2band ext
		home_ap_list="ap0 ap1"
	else
		# 3band ext
		home_ap_list="ap0 ap1 ap2"
	fi

	echo $home_ap_list
}

copy_config_unmanaged() 
{
	local ep_profile="$1"
	local role="$2"

	ap_list=${aps}
	home_ap_list=$(get_home_ap_list)

	# Copy config for home aps
	for ap in $(set_intersection "${ap_list}" "${home_ap_list}"); do
		configure_ap ${ap} ${ep_profile}
		uci set wireless.${ap}.state=1
	done

	# Config cred0 and cred1
	for cred in cred0 cred1; do
		uci get multiap.${cred}.state &> /dev/null
		if [ "$?" -eq 0 ]; then
			echo_with_logging "Configuring ap=${cred} ep_profile=$ep_profile"
			configure_ap ${cred} ${ep_profile}

			# enable cred
			uci set multiap.${cred}.state=1
		fi
	done

	# Disable all other aps
	for ap in $(set_complement "${ap_list}" "${home_ap_list}"); do
		echo_with_logging "disable non-home ap ${ap}"
		uci set wireless.${ap}.state=0
	done

	# disable FH / BH
	for ap in $ap_list; do
		iface=$(get_iface_from_ap $ap)
       		if [ "$iface" != "" ]; then
			uci set wireless.${iface}.backhaul=0
			uci set wireless.${iface}.fronthaul=0
	        fi
	done
}

copy_config_easymesh() 
{
	local ep_profile="$1"
	local role="$2"

	ap_list=${aps}
	home_ap_list=$(get_home_ap_list)

	# Copy config for home aps
	for ap in $(set_intersection "${ap_list}" "${home_ap_list}"); do
		echo_with_logging "Configuring ap=${ap} ep_profile=$ep_profile"

		iface=$(get_iface_from_ap $ap)
       		if [ "$iface" != "" ]; then
			uci set wireless.${iface}.state=1
	        fi
		configure_ap ${ap} ${ep_profile}
		uci set wireless.${ap}.state=1
	done

	# Config cred0 and cred1
	for cred in cred0 cred1; do
		uci get multiap.${cred}.state &> /dev/null
		if [ "$?" -eq 0 ]; then
			echo_with_logging "Configuring ap=${cred} ep_profile=$ep_profile"
			configure_ap ${cred} ${ep_profile}

			# enable cred
			uci set multiap.${cred}.state=1
		fi
	done

	# Enable all none-home aps
	for ap in $(set_complement "${ap_list}" "${home_ap_list}"); do
		echo_with_logging "enable non-home ap ${ap}"
		uci set wireless.${ap}.state=1
	done
}

for i in x x x # at most 3 '-' type arguments
do
	case "$1" in
		-h) print_help
			shift;;
		-e) ep_profile="$2"
			shift;
			shift;;
		-r) role="$2"
			shift;
			shift;;
		-m) mode="$2"
			shift;
			shift;;
		-*) print_help;;
	esac
done

if [ -z "$ep_profile" ] || [ -z "$role" ] || [ -z "$mode" ]; then
	echo_with_logging "Missing arguments"
	print_help
fi

if [ "$mode" != "wet" ] && [ "$mode" != "map" ]; then
	echo_with_logging "wrong arguments for mode: <map|wet>"
	print_help
fi

if [ "$role" != "ap" ] && [ "$role" != "repeater" ]; then
	echo_with_logging "wrong arguments for role:  <repeater|ap>"
	print_help
fi

# fetch all aps
get_all_aps

# policy is optional
policy=`uci get wireless.supplicant.easy_install_policy 2> /dev/null`
if [ "$policy" != "1" ] && [ "$policy" != "2" ]; then
	policy=2
fi

ep=`echo $ep_profile | cut -f 1 -d_`

#save ep mode
echo_with_logging "configuring ep_profile=${ep_profile} ep=${ep} mode=${mode} role=${role} policy=${policy}"
uci set wireless.${ep}.mode=${mode}

if [ "$policy" == "1" ]; then
	# policy 1
	if [ "$mode" == "map" ]; then
		# [MAP] EM agent enabled and controller disabled

		uci set multiap.agent.enabled=1
		uci set multiap.controller.enabled=0
		uci set ledfw.easymesh_status.enable='1'
		uci commit

		if [ "$DRYRUN" == "0" ]; then
		        /etc/init.d/ledfw restart &
		        /etc/init.d/multiap_controller stop &
		        /etc/init.d/multiap_agent restart &
		fi
	elif [ "$role" == "ap" ]; then
		# [WET + ETH BH] EM agent enabled and controller enabled

		# copy ep0 profile config to home APs + disable other APs
		copy_config_easymesh ${ep_profile} ${role}
	
		# start EM agent and controller
		uci set multiap.agent.enabled=1
		uci set multiap.controller.enabled=1
		uci set ledfw.easymesh_status.enable='1'
		uci commit

		if [ "$DRYRUN" == "0" ]; then
			/etc/init.d/ledfw restart &
			/etc/init.d/multiap_controller restart &
			/etc/init.d/multiap_agent restart &
		fi
	else
		# [WET + WLAN BH] EM agent disabled and controller disabled

		# disable EM agent and controller
		uci set multiap.agent.enabled=0
		uci set multiap.controller.enabled=0
		uci set ledfw.easymesh_status.enable='0'
		uci commit

		if [ "$DRYRUN" == "0" ]; then
			/etc/init.d/ledfw restart &
			/etc/init.d/multiap_controller stop &
			/etc/init.d/multiap_agent stop &
		fi

		# copy ep0 profile config to home APs + disable other APs
		copy_config_unmanaged ${ep_profile} ${role}

		uci commit
		echo_with_logging "reloading"
		ubus call wireless reload
	fi
else
	# policy 2
	if [ "$mode" == "map" ]; then
		# [MAP] EM agent enabled and controller disabled

		uci set multiap.agent.enabled=1
		uci set multiap.controller.enabled=0
		uci set ledfw.easymesh_status.enable='1'
		uci commit

		if [ "$DRYRUN" == "0" ]; then
		        /etc/init.d/ledfw restart &
		        /etc/init.d/multiap_controller stop &
		        /etc/init.d/multiap_agent restart &
		fi
	else
		# [WET + ETH BH]  or [WET + WLAN BH] EM agent disabled and controller disabled

		# disable EM agent and controller
		uci set multiap.agent.enabled=0
		uci set multiap.controller.enabled=0
		uci set ledfw.easymesh_status.enable='0'
		uci commit

		if [ "$DRYRUN" == "0" ]; then
			/etc/init.d/ledfw restart &
			/etc/init.d/multiap_controller stop &
			/etc/init.d/multiap_agent stop &
		fi

		# copy ep0 profile config to home APs + disable other APs
		copy_config_unmanaged ${ep_profile} ${role}

		uci commit
		echo_with_logging "reloading"
		ubus call wireless reload
	fi
fi
