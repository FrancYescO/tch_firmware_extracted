#!/bin/sh

bin=${0##*/}
program="$1"
cmd="$2"
iface="$3"
ssid="$4"

#logger "[$bin]: program='$program' cmd='$cmd' iface='$iface' ssid='$ssid'"

exec_wl_cmd()
{
	local cmd="$1"
	logger "[$bin][TEST] $cmd"
	eval "$cmd"
}

he_ap_config_commit()
{
	iface=$2
	ssid=$3
	logger "[$bin][ap_config_commit] $iface $ssid"

	exec_wl_cmd "wl -i $iface mpc 0"
	exec_wl_cmd "wl -i $iface atf 1"
	exec_wl_cmd "wl -i $iface he dynfrag 0"

	# UL OFDMA fixes
	FEATURES=`wl -i $iface he features`
	if [ $(($FEATURES & 0x8 )) -gt 0  ]; then
		exec_wl_cmd "wl -i $iface umsched always_admit 1"
		#exec_wl_cmd "wl -i $iface umsched start 1"
		exec_wl_cmd "wl -i $iface msched mindlusers 4"
	# DL OFDMA fixes
        elif [ $(($FEATURES & 0x4 )) -gt 0  ]; then
	        exec_wl_cmd "wl -i $iface msched mindlusers 4"
	fi

	# 4.30.1
	if [ -z "${ssid##HE-4.30.1*}" ]; then
		if [ "wl0" = "$iface" ]; then
			#exec_wl_cmd "wl -i $iface down"
			#exec_wl_cmd "wl -i $iface vht_features 7"
			#exec_wl_cmd "wl -i $iface msched snd 0"
			#exec_wl_cmd "wl -i $iface he features 7"
			#exec_wl_cmd "wl -i $iface up"
			exec_wl_cmd "wl -i $iface msched mindlusers 2"
		else
			exec_wl_cmd "wl -i $iface msched mindlusers 2"
		fi
	fi

	# 4.40.x
	if [ -z "${ssid##HE-4.40*}" ]; then
		# Disable UL OFDMA trigger frames, started with set_rf_feature
		exec_wl_cmd "wl -i $iface umsched start 0"
	fi

	# 4.44.1
	if [ -z "${ssid##HE-4.44*}" ] ;then
		exec_wl_cmd "wl -i $iface down"
		exec_wl_cmd "wl -i $iface mu_features 0"
		exec_wl_cmd "wl -i $iface up"
	fi

	# TWT fixes
	if [ -z "${ssid##HE-4.56*}" ] ;then
		exec_wl_cmd "wl -i $iface umsched always_admit 2"
		#exec_wl_cmd "wl -i $iface umsched mcs 7"
		#exec_wl_cmd "wl -i $iface umsched nss 1"
		#exec_wl_cmd "wl -i $iface ampdu_mpdu 10"
		exec_wl_cmd "wl -i $iface twt_prestrt 100"
		exec_wl_cmd "wl -i $iface twt_prestop 0x1000"
		exec_wl_cmd "wl -i $iface umsched start 1"
	fi

	# DL20in80 fixes
        if [ -z "${ssid##HE-4.69*}" ] ;then
                exec_wl_cmd "wl -i $iface sgi_tx 5"
		exec_wl_cmd "wl -i $iface frameburst 1"
                exec_wl_cmd "/data/ofdma.sh -i $iface -u 0 -b 80 &"
        fi

        # TxBF
        exec_wl_cmd "wl -i $iface txbf_rateset -v fff fff fff fff"
        exec_wl_cmd "wl -i $iface txbf_rateset -b -v fff fff fff fff"

        # hammer mvl sta into submission
        exec_wl_cmd "wl -i $iface macmode 0"
        exec_wl_cmd "wl -i $iface probresp_mac_filter 0"
        exec_wl_cmd "wl -i $iface txbf_mutimer 0"
}

he_ap_set_rfeature()
{
	iface=$2
	ssid=$3
	logger "[$bin][ap_set_rfeature] $iface $ssid $cmd"

	# reset stats collection for debugging
        exec_wl_cmd "wl -i $iface dump_clear msched"
        exec_wl_cmd "wl -i $iface dump_clear umsched"
        exec_wl_cmd "wl -i $iface dump_clear ampdu"

	if [ -z "${cmd%%*type,HE,DisableTriggerType,0}" ]; then
		exec_wl_cmd "wl -i $iface pkteng_cmd -k txtrig_cnt 0"
	fi

	# UL OFMDA type,HE,TriggerType,0,ACKType,M-BA
	# TC 4.41 and 4.46
	if [ -z "${cmd%%*type,HE,TriggerType,0,ACKType,M-BA}" ]; then
		exec_wl_cmd "wl -i $iface umsched csthr0 1"
		exec_wl_cmd "wl -i $iface umsched csthr1 1"
		exec_wl_cmd "wl -i $iface umsched minulusers 1"
		exec_wl_cmd "wl -i $iface umsched maxtw -1"
		exec_wl_cmd "wl -i $iface umsched burst -1"
		exec_wl_cmd "wl -i $iface umsched interval 0"
		exec_wl_cmd "wl -i $iface umsched trssi 55"
		exec_wl_cmd "wl -i $iface umsched start 1"

		# UL OFDMA fixes TriggerType,0 AckPolicy,4
		# TC 4.62
	elif [ -z "${cmd%%*type,HE,AckPolicy,4,TriggerType,0}" ]; then
		exec_wl_cmd "wl -i $iface msched ackpolicy 1"

		# UL OFDMA fixes TriggerType,0 ACKType not set
		# TC 4.40, 4.60, 4.63 and 4.64 EXCEPT 4.58.1 per BRCM sigma
	elif [ -z "${cmd%%*type,HE,TriggerType,0}" ] ||
		[ -z "${cmd%%*type,HE,TriggerType,0,PPDUTxType,legacy}" ]; then
		if [ -z "${ssid##HE-4.58.1*}" ] ;then
			exec_wl_cmd "wl -i $iface umsched minulusers 1"
		elif [ "wl0" = "$iface" ]; then
			exec_wl_cmd "wl -i $iface umsched maxtw 10"
			exec_wl_cmd "wl -i $iface umsched burst 10"
			exec_wl_cmd "wl -i $iface umsched interval -1"
			exec_wl_cmd "wl -i $iface umsched trssi 65"
			#TBD stoptrigger script
		else
			exec_wl_cmd "wl -i $iface umsched maxtw -1"
			exec_wl_cmd "wl -i $iface umsched burst -1"
			exec_wl_cmd "wl -i $iface umsched interval 0"
			exec_wl_cmd "wl -i $iface umsched trssi 50"
		fi
                exec_wl_cmd "wl -i $iface umsched minulusers 1"
		#exec_wl_cmd "wl -i $iface umsched start 1"
		# WFA testbed starts sniffer and then configures traffic on STA
		# sniffer only analyzes first 1000 trigger frames, so we delay trigger frame start with 2s
                logger "[$bin][TEST][DELAY 2s] wl -i $iface umsched start 1"
                sleep 2 && wl -i $iface umsched start 1 &

		# UL-OFDMA TriggerType,1
		# TC 4.53
	elif [ -z "${cmd%%*type,HE,TriggerType,1}" ]; then
		exec_wl_cmd "wl -i $iface txbf_mutimer 50"
		exec_wl_cmd "wl -i $iface reinit"

		# UL-OFDMA AckPolicy,3,TriggerType,2
		# TC 4.45
	elif [ -z "${cmd%%*type,HE,AckPolicy,3,TriggerType,2}" ]; then
		# AckPolicy 4 = Trigger in ampdu Do it with msched. Skip umsched
		exec_wl_cmd "wl -i $iface msched ackpolicy 2"

		# UL-OFDMA TriggerType,3
	elif [ -z "${cmd%%*type,HE,TriggerType,3}" ]; then
		exec_wl_cmd "wl -i $iface msched murts 1"
		exec_wl_cmd "wl -i $iface msched mindlusers 1"

		# UL-OFDMA TriggerType,4
	elif [ -z "${cmd%%*type,HE,TriggerType,4}" ]; then
		exec_wl_cmd "wl -i $iface  umsched minulusers 1"
		exec_wl_cmd "wl -i $iface  umsched burst 1"
		exec_wl_cmd "wl -i $iface  umsched maxtw 20"
		exec_wl_cmd "wl -i $iface  umsched interval 5000"
		exec_wl_cmd "wl -i $iface  umsched mctl 0x1420"
		exec_wl_cmd "wl -i $iface  umsched start 1"
	else
                logger "[$bin][TEST] parse failure"
	fi

}

he_ap_reset_default()
{
	iface=$2
	ssid=$3
	logger "[$bin][ap_reset_default] $iface $ssid $cmd"

	# load board id to determine which WAR for the platform
        BOARDID=$(cat /proc/nvram/boardid)
        if [ "$BOARDID" = "GBNT-R" ]; then
		if [[ ! -f /etc/dhd_runner_keys ]]; then
			echo "dhd0_rnr_rxoffl=1" > /etc/dhd_runner_keys
			echo "dhd0_rnr_txoffl=0" >> /etc/dhd_runner_keys
			echo "dhd1_rnr_rxoffl=1" >> /etc/dhd_runner_keys
			echo "dhd1_rnr_txoffl=0" >> /etc/dhd_runner_keys
			uci commit
			reboot -d 1 &
			exit
		fi
	fi


	# cleanup of 4.68
	# terminate ofdma.sh
	ps | grep /data/ofdma.sh | xargs kill > /dev/null 2>&1
        if [ "wl1" = "$iface" ]; then
                mschedfixed=`wl -i wl1 msched  | grep -c FIXED`
                if [ "$mschedfixed" = "1" ]; then
                       logger "[$bin][TEST] $iface hard reset (REBOOT)"
                       uci commit
                       reboot -d 1 &
                       exit
                fi
        fi
        logger "[$bin][TEST] $iface soft reset"

	# cleanup of 4.44.1
        mufeat=`wl -i $iface mu_features`
        if [ "0" = "$mufeat" ]; then
                exec_wl_cmd "wl -i $iface down"
                exec_wl_cmd "wl -i $iface mu_features 1"
                exec_wl_cmd "wl -i $iface up"
        fi

	# reset settings
	exec_wl_cmd "wl -i $iface msched ackpolicy 0"
	exec_wl_cmd "wl -i $iface ampdu_mpdu -1"
        exec_wl_cmd "wl -i $iface sgi_tx -1"

	# reset umsched
	exec_wl_cmd "wl -i $iface umsched minulusers 2"
	exec_wl_cmd "wl -i $iface umsched always_admit 0"
	exec_wl_cmd "wl -i $iface umsched csthr0 76"
	exec_wl_cmd "wl -i $iface umsched csthr1 418"
	exec_wl_cmd "wl -i $iface umsched burst 2"
	exec_wl_cmd "wl -i $iface umsched maxtw 5"
        #exec_wl_cmd "wl -i $iface umsched start 0"

	#exec_wl_cmd "wl -i $iface dynfrag 0"
	#exec_wl_cmd "wl -i $iface umsched interval -1"
	#exec_wl_cmd "wl -i $iface umsched mctl 0x0020"
}

#logger "[$bin][DBG] $program $ssid $cmd $iface"
if [ "$program" = "he" ] ; then

	if [ -z "${cmd##ap_reset_default*}" ]; then
		he_ap_reset_default $cmd $iface $ssid;
	fi

	# Skip unconfigured interface
	if [ -z "${ssid##TNCAP*}" ]; then
		exit
	fi

	# Match command to function
	if [ -z "${cmd##ap_set_rfeature*}" ]; then
		he_ap_set_rfeature $cmd $iface $ssid;
	fi
	if [ -z "${cmd##ap_config_commit*}" ]; then
		he_ap_config_commit $cmd $iface $ssid;
	fi
fi

