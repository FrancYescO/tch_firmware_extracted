#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh

QOS_VLAN_FILE="/var/.vlan_flush_log"
# get last logs of vlanctl to file
Qos_vlanLastDmesg () {
	QOS_DMESG_FILE=`mktemp`

	dmesg > $QOS_DMESG_FILE
	lfirst=`grep -rins "VLAN Rule Table : $lowerifname" $QOS_DMESG_FILE | tail -1 | cut -d ':' -f1`
	llast=`wc -l $QOS_DMESG_FILE |awk '{print $1}'`
	let "lnumber=$llast-$lfirst+1"
	tail -$lnumber $QOS_DMESG_FILE > $QOS_VLAN_FILE
	rm -rf $QOS_DMESG_FILE
}

gpon_vlan_set_default_action() {
	local vlandev="$1"
	local tags="0 1 2 3 4"

	for i in $tags ; do
		vlanctl --if $vlandev --tx --tags $i --default-miss-drop
		vlanctl --if $vlandev --rx --tags $i --default-miss-drop
	done
}

gpon_vlanif_up() {
	local vlanif="$1"

	ifconfig $vlanif up
	ifconfig $vlanif multicast
}

gpon_create_vlanif() {
	local realdev="$1"
	local vlandev="$2"
	local route="$3"
	local mcast="$4"
	local mac="$5"
	local routedstr=""
	local mcaststr=""

	if [ '1' = $route ] ; then
		routedstr="--routed"
	fi

	if [ '1' = $mcast ] ; then
		mcaststr="--mcast"
	fi

	vlanctl --if-create-name $realdev $vlandev $routedstr $mcaststr
	vlanctl --if $realdev --set-if-mode-ont

	#mac ?
	if [ $mac != 0 ] ; then
		ifconfig $vlandev hw ether $mac
	fi

	gpon_vlanif_up $vlandev
}

gpon_delete_vlanif() {
	local vlandev="$1"

	ifconfig $vlandev down
	sleep 0.5
	vlanctl --if-delete $vlandev
	if [ "$?" != 0 ] ; then
		echo "vlanctl --if-delete [$vlandev] failed!"
	fi
}

# layer2 interfaces
gpon_setup_l2_device() {
	local config="$1"
	local ifname

	config_get ifname "$config" ifname

	gponif -c $ifname
	ifconfig $ifname up
}

gpon_setup_l2_interface() {
	local config="$1"
	local ifname lintf defact

	config_get ifname "$config" ifname
	config_get lintf "$config" lintf
	config_get defact "$config" defact

	gpon_create_vlanif $lintf $ifname 0 1 0
	if [ '1' = $defact ] ; then
		gpon_vlan_set_default_action $lintf
	fi
}

gpon_load_layer2_intf() {

	config_load gponl2
	config_foreach gpon_setup_l2_device device
	config_foreach gpon_setup_l2_interface interface
}

gpon_teardown_l2_device() {
	local config="$1"
	local ifname

	config_get ifname "$config" ifname

	ifconfig $ifname down
	gponif -d $ifname
}

gpon_teardown_l2_interface() {
	local config="$1"
	local ifname

	config_get ifname "$config" ifname

	gpon_delete_vlanif $ifname
}

gpon_unload_layer2_intf() {

	config_load gponl2
	config_foreach gpon_teardown_l2_interface interface
	config_foreach gpon_teardown_l2_device device
}

# layer3 interfaces
gpon_setup_l3_device() {
	local config="$1"
	local l2dev l3dev defact

	config_get l2dev "$config" l2dev
	config_get l3dev "$config" l3dev
	config_get defact "$config" defact

	gpon_create_vlanif $l2dev $l3dev 0 1 0
	if [ '1' = $defact ] ; then
		gpon_vlan_set_default_action $l2dev
	fi
}


gpon_setup_l3_ethwan_interface() {
	local config="$1"
	local l3dev

	config_get l3dev "$config" l3dev
	if [ "$(echo $l3dev | grep 'eth')" != "" ] ; then
		gpon_vlanif_up $l3dev
		gpon_setup_l3_interface $config
	fi
}

gpon_setup_l3_interface() {
	local config="$1"
	local ifname univlan l3dev defact pbit

	config_get l3dev "$config" l3dev
	config_get ifname "$config" ifname
	config_get univlan "$config" univlan
	config_get defact "$config" defact
	config_get mode "$config" mode
	config_get macaddr "$config" macaddr

	pbit=$(uci_get qos $ifname pcp)
	if [ -z $pbit ] ; then
		pbit=$(uci_get qos $l3dev pcp)
	fi
	if [ -z $pbit ] ; then
		pbit=0
	fi

	if [ -z $macaddr ] ; then
		macaddr=0
	fi

	if [ 'routed' = $mode ] ; then
		filt_mac="--filter-vlan-dev-mac-addr 1"
	else
		filt_mac=""
	fi

	if ifconfig $ifname >/dev/null 2>&1; then
		gpon_vlanif_up $ifname
		return 0
	else
		echo "To create gponl3 interface: $ifname"
	fi

	gpon_create_vlanif $l3dev $ifname 0 1 $macaddr
	vlanctl --if $l3dev --set-if-mode-rg

	vlanctl --rule-remove-all $ifname
	if [ '1' = $defact ] ; then
		gpon_vlan_set_default_action $l3dev
	fi

	if [ 'untag' = $univlan ] || [ 'untagged' = $univlan ] ; then
		vlanctl --if $l3dev --tx --tags 0 --filter-txif $ifname --rule-append
		vlanctl --if $l3dev --rx --tags 0 $filt_mac --set-rxif $ifname --rule-append
	elif [ 'singletag' = $univlan ] || [ 'singletagged' = $univlan ] ; then
		vlanctl --if $l3dev --tx --tags 1 --filter-txif $ifname --rule-append
		vlanctl --if $l3dev --rx --tags 1 --set-rxif $ifname --rule-append
	elif [ 'doubletag' = $univlan ] || [ 'dualtag' = $univlan ] || [ 'doubletagged' = $univlan ] || [ 'dualtagged' = $univlan ] ; then
		vlanctl --if $l3dev --tx --tags 2 --filter-txif $ifname --rule-append
		vlanctl --if $l3dev --rx --tags 2 --set-rxif $ifname --rule-append
	elif [ 'tag' = $univlan ] || [ 'tagged' = $univlan ] ; then
		vlanctl --if $l3dev --tx --tags 0 --filter-txif $ifname --rule-append
		vlanctl --if $l3dev --tx --tags 1 --filter-txif $ifname --rule-append
		vlanctl --if $l3dev --tx --tags 2 --filter-txif $ifname --rule-append
		vlanctl --if $l3dev --rx --tags 0 --set-rxif $ifname --rule-append
		vlanctl --if $l3dev --rx --tags 1 --set-rxif $ifname --rule-append
		vlanctl --if $l3dev --rx --tags 2 --set-rxif $ifname --rule-append
	else
		vlanctl --if $l3dev --tx --tags 0 --filter-txif $ifname --push-tag --set-vid $univlan 0 --set-pbits $pbit 0 --rule-append

#		vlanctl --if $l3dev --rx --tags 1 --filter-vid $univlan 0 --filter-pbits $pbit 0 $filt_mac --pop-tag --set-rxif $ifname --cfg-tpid 0x8100 0x8100 0x88a8 0x9100 --rule-append
		vlanctl --if $l3dev --rx --tags 1 --filter-vid $univlan 0 $filt_mac --pop-tag --set-rxif $ifname --cfg-tpid 0x8100 0x8100 0x88a8 0x9100 --rule-append
	fi

}

detach_ppp_interface() {
	local config="$1"
	local ifname l3dev proto realifname

	ifname="$(uci_get network "$config" ifname)"
	for tmpifname in ${ifname} ; do
		l3dev=`uci_get gponl3 $tmpifname l3dev`
		if [ "$l3dev" = "veip0" ] ; then
			config_get proto "$config" proto
			if [ "$proto" = "pppoe" ] ; then
				config_get realifname "$config" ifname
				ifconfig $realifname down
			fi
		fi
	done
}

gpon_teardown_ppp_interface() {
	config_load network
	config_foreach detach_ppp_interface interface
}

match_wan_interface() {
	local wanintf="$1"
	local gponl3intf="$2"
	local restore="$3"
	local ifname oldstate

	# don't use config_get for its result is not the original value in /etc/config/network,
	# for example if the wan is pppoe type, the result is pppoe-wan not veip0_1
	ifname="$(uci_get network "$wanintf" ifname)"
	for tmpifname in ${ifname} ; do
		if [ "$tmpifname" = "$gponl3intf" ] ; then
			if [ "$restore" = "0" ] ; then
				oldstate="$(uci_get network "$wanintf" auto "1")"
				uci_revert_state network "$wanintf" savedauto
				uci_set_state network "$wanintf" savedauto "$oldstate"
				uci_set network "$wanintf" auto "0"
				uci_commit network
			else
				oldstate="$(uci_get_state network "$wanintf" savedauto "1")"
				uci_set network "$wanintf" auto "$oldstate"
				uci_commit network
			fi
		fi
	done
}

search_wan_interface() {
	local config="$1"
	local restore="$2"
	local ifname

	config_get ifname "$config" ifname
	config_get l3dev "$config" l3dev

	if [ "$l3dev" = "veip0" ] ; then
		config_load network
		config_foreach match_wan_interface interface $ifname $restore
	fi
}

turn_off_restore_wan_interfaces() {
	local restore="$1"

	config_load gponl3
	config_foreach search_wan_interface interface $restore

	/etc/init.d/network reload
}

gpon_load_layer3_interfaces() {

	turn_off_restore_wan_interfaces 0

	config_load gponl3
	config_foreach gpon_setup_l3_device device
	config_foreach gpon_setup_l3_interface interface

	/usr/bin/qos -q reload
	turn_off_restore_wan_interfaces 1
}

gpon_load_layer3_ethwan_interface() {

	if [ -x /bin/pspctl ] && [ "$(pspctl dump RdpaWanType | grep 'GBE')" != "" ] ; then
		config_load gponl3

		config_foreach gpon_setup_l3_ethwan_interface interface
	fi
}

gpon_teardown_l3_device() {
	local config="$1"
	local l3dev

	config_get l3dev "$config" l3dev

	gpon_delete_vlanif $l3dev
}

gpon_teardown_l3_interface() {
	local config="$1"
	local ifname

	config_get ifname "$config" ifname

	if ifconfig $ifname >/dev/null 2>&1; then
		gpon_delete_vlanif $ifname
	fi
}

gpon_unload_layer3_interfaces() {
	gpon_teardown_ppp_interface

	config_load gponl3
	config_foreach gpon_teardown_l3_interface interface
	config_foreach gpon_teardown_l3_device device
}

gpon_check_intf() {
	intf=$1
	loop=$2
	act=$3
	echo $intf:$act > /dev/console

	veip_intf=$intf
	if [ -z $veip_intf ] ; then
		return 1;
	fi

	let count=1
	while [ $count -le $loop ]; do
		#echo check gpon interface $veip_intf: $count > /dev/console
		if ifconfig $veip_intf ; then
			ifconfig $veip_intf up;
			if [ -n $act ] ; then
				eval $act
			fi
			return 0;
		fi
		let count=count+1;
		sleep 2;
	done

	return 2;
}

eth_vlan_set_default_action() {
	local realdev="$1"
	local vlandev="$2"
	local univlan="$3"
	local tags="0 1 2 3 4"

	for i in $tags ; do
		vlanctl --if $realdev --rx --tags $i --default-miss-accept $vlandev
	done


	if [ ! -z $univlan ] && [ 'untag' != $univlan ] ; then
		vlanctl --if $realdev --tx --tags 0 --filter-txif $vlandev --push-tag --set-vid $univlan 0 --rule-append
		vlanctl --if $realdev --rx --tags 1 --filter-vid $univlan 0  --pop-tag --set-rxif $vlandev --rule-append
	fi
}

eth_set_default_vlan_intf() {
	suffix=$1
	if [ -z $suffix ]; then
		suffix="_0"
	fi

	let idx=0
	while [ $idx -le 3 ]; do
		base=eth$idx
		ifconfig $base up;
		let idx=idx+1;
	done

	let idx=0
	while [ $idx -le 3 ]; do
		base=eth$idx
		vlanif=$base$suffix

		gpon_create_vlanif $base $vlanif 0 1 0
		eth_vlan_set_default_action $base $vlanif

		echo $i: $base $vlanif > /dev/console
		let idx=idx+1;
	done
}

# uni handler
gpon_uni_setup_bridge() {
	local idx=$1

#bs /bdmf/new bridge
}

gpon_uni_create_def_vlan_intf() {
	local idx=$1
	local suffix=$2
	local univlan=$3
	local base vlanif

	if [ -z $suffix ]; then
		suffix="_0"
	fi

	base=eth$idx
	vlanif=$base$suffix

	gpon_create_vlanif $base $vlanif 0 1 0
	if [ -z $univlan ]; then
		eth_vlan_set_default_action $base $vlanif
	else
		eth_vlan_set_default_action $base $vlanif $univlan
	fi
	echo "create: $base $vlanif" > /dev/console

}

gpon_setup_uni() {
	local config="$1"
	local port type

	config_get port "$config" port
	config_get type "$config" type
	config_get univlan "$config" univlan

	if [ 'ont' = $type ] ; then
		#gpon_uni_create_def_vlan_intf $port
		gpon_uni_setup_bridge $port
	elif [ 'rg' = $type ] ; then
		if [ -z $univlan ] ; then
			gpon_uni_create_def_vlan_intf $port
		else
			gpon_uni_create_def_vlan_intf $port "_0" $univlan
		fi
	fi

	#echo "gpon_setup_uni: port($port) type($type)" > /dev/console
}

gpon_setup_uni_pre() {
	local config="$1"
	local port base

	config_get port "$config" port

	base=eth$port
	ifconfig $base up;

	#echo "gpon_setup_uni_pre: $base" > /dev/console
}

eth_flush_vlan_rule() {
	local realdev="$1"
	local lowerifname="$1"

	#flush rx direction
	vlanctl --if $lowerifname --rx --tags 1 --show-table > /dev/null
	if [ "$?" = 0 ] ; then
		Qos_vlanLastDmesg
		cat $QOS_VLAN_FILE | while read line
		do
			case $line in
				*Tag*Rule*ID*)
				ruleID=`echo "$line" |tr -d ' ' | cut -f 2 -d ':'`
				;;
				*SKB*MARK*FLOWID*)
				unset ruleID
				;;
				*Hit*Count*)
				if [ ! -z $ruleID ] ; then
					vlanctl --if $lowerifname --rx --tags 1  --rule-remove  $ruleID
				fi
				;;
			esac
		done
	fi
	rm -rf $QOS_VLAN_FILE

	#flush tx direction
	vlanctl --if $lowerifname --tx --tags 0 --show-table > /dev/null
	if [ "$?" = 0 ] ; then
		Qos_vlanLastDmesg
		cat $QOS_VLAN_FILE | while read line
		do
			case $line in
				*Tag*Rule*ID*)
				ruleID=`echo "$line" |tr -d ' ' | cut -f 2 -d ':'`
				;;
				*SKB*MARK*FLOWID*)
				unset ruleID
				;;
				*Hit*Count*)
				if [ ! -z $ruleID ] ; then
					vlanctl --if $lowerifname --tx --tags 0  --rule-remove  $ruleID
				fi
				;;
			esac
		done
	fi
	rm -rf $QOS_VLAN_FILE
}

gpon_flush_vlan_rule_uni() {
	local config="$1"
	local port type

	config_get port "$config" port
	config_get type "$config" type

	local base=eth$port
	if [ 'rg' = $type ] ; then
			eth_flush_vlan_rule $base
	fi
}

gpon_teardown_ethport_uni() {
	local config="$1"
	local port type
	local base vlanif
	local suffix="_0"

	config_get port "$config" port
	config_get type "$config" type

	base=eth$port
	vlanif=$base$suffix
	if ifconfig $vlanif >/dev/null 2>&1; then
		gpon_delete_vlanif $vlanif
	fi
}

gpon_load_uni() {
	config_load gpon

	config_foreach gpon_setup_uni_pre omci_eth_port
	config_foreach gpon_setup_uni omci_eth_port
}

gpon_unload_uni() {
	config_load gpon
	config_foreach gpon_teardown_ethport_uni omci_eth_port
}
