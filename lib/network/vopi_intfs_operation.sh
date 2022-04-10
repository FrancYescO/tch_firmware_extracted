#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh

VOPIIFNAME_SAVE_FILE="/var/run/vopi_ifname.bak"
default_ethernet_mtu=1998
default_ptm_mtu=1950

vopi_create_vlanif() {
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

	echo "$vlandev , $realdev" >> $VOPIIFNAME_SAVE_FILE
	vlanctl --if-create-name $realdev $vlandev $routedstr $mcaststr

	#mac ?
	if [ $mac != 0 ] ; then
		ifconfig $vlandev hw ether $mac
	fi

	ifconfig $vlandev multicast
}


vopi_set_mtu() {
	local interface_name=$1
	local base_interface=$2
	local mtu=$3
	if [ -z "$mtu" ] ; then
		case "$base_interface" in
			eth*)
				mtu=$default_ethernet_mtu
			;;
			ptm*)
				mtu=$default_ptm_mtu
			;;
			*)
				mtu=$default_ptm_mtu
			;;
		esac
	fi
	if [ -n "$mtu" ] ; then
		local base_mtu_path="/sys/class/net/$base_interface/mtu"
		local base_mtu=`cat $base_mtu_path`
		if [ "$mtu" -gt "$base_mtu" ] ; then
			#logger "vopi" "setting $base_interface mtu to $mtu"
			ifconfig $base_interface mtu $mtu
		fi
		ifconfig $interface_name mtu $mtu
#	logger "vopi" "setting $interface_name mtu to $mtu"
	fi
}

vopi_setup_l3_interface() {
	local config="$1"
	local ifname vlanmode vid outervid l3dev pbit
	local swstat

	config_get l3dev "$config" l3dev
	config_get ifname "$config" ifname
	config_get vlanmode "$config" vlanmode
	config_get vid "$config" vid
	config_get outervid "$config" outervid
	config_get mode "$config" mode
	config_get macaddr "$config" macaddr
	config_get mtu "$config" mtu

	pbit=$(uci_get qos $ifname pcp)
	if [ -z $pbit ] ; then
		pbit=$(uci_get qos $l3dev pcp)
	fi
	if [ -z $pbit ] ; then
		pbit=0
	fi
	if [ -z $mode ] ; then
		mode="bridged"
	fi
	if [ -z $macaddr ] ; then
		macaddr=0
	fi
	if [ 'single' = $vlanmode ] && [ -z $vid ] ; then
		echo "vopi_setup_l3_interface:vlanmode=$vlanmode,vid is required"
		return 1
	elif [ 'double' = $vlanmode ] ; then
		if [ -z $vid ] || [ -z $outervid ] ; then
			echo "vopi_setup_l3_interface:vlanmode=$vlanmode,vid=$vid and outervid=$outervid is required"
			return 1
		fi
	fi
	if [ 'routed' = $mode ] ; then
		filt_mac="--filter-vlan-dev-mac-addr 1"
	else
		filt_mac=""
	fi

	ifconfig $l3dev >/dev/null 2>&1
	if [ $? != 0 ] ; then
		echo "l3dev:$l3dev not exist,return 1 "
		return 1
	fi

	ifconfig $ifname >/dev/null 2>&1
	if [ $? == 0 ] ; then
		echo "interface:$ifname is already created,return"
		ifconfig $ifname multicast
		return 0
	else
		echo "To create vopi interface: $ifname"
	fi

	ifconfig $l3dev up
	vopi_create_vlanif $l3dev $ifname 0 1 $macaddr
	vlanctl --if $l3dev --set-if-mode-rg
	vlanctl --rule-remove-all $ifname

	vopi_set_mtu $ifname $l3dev $mtu

	swstat=`ethswctl -c hw-switching |grep Enabled`
	if [ -n "$swstat" ] ; then
		echo "vopi_setup_l3_interface:disable ethsw hw-switching"
		ethswctl -c hw-switching -o disable
	fi

	if [ 'untag' = $vlanmode ] ; then
		vlanctl --if $l3dev --tx --tags 0 --filter-txif $ifname --rule-append
		vlanctl --if $l3dev --rx --tags 0 $filt_mac --set-rxif $ifname --rule-append
	elif [ 'transparent' = $vlanmode ] ; then
		vlanctl --if $l3dev --tx --tags 1 --filter-txif $ifname --rule-append
		vlanctl --if $l3dev --rx --tags 1 --default-miss-accept $ifname
		vlanctl --if $l3dev --tx --tags 2 --filter-txif $ifname --rule-append
		vlanctl --if $l3dev --rx --tags 2 --default-miss-accept $ifname
	elif [ 'translateus' = $vlanmode ] ; then
		vlanctl --if $l3dev --tx --tags 1 --filter-txif $ifname --set-vid $vid 0 --rule-append
		vlanctl --if $l3dev --rx --tags 1 --default-miss-accept $ifname
		vlanctl --if $l3dev --tx --tags 2 --filter-txif $ifname --set-vid $vid 0 --rule-append
		vlanctl --if $l3dev --rx --tags 2 --default-miss-accept $ifname
	elif [ 'single' = $vlanmode ] ; then
		vlanctl --if $l3dev --tx --tags 0 --filter-txif $ifname --push-tag --set-vid $vid 0 --set-pbits $pbit 0 --rule-append
		vlanctl --if $l3dev --rx --tags 1 --filter-vid $vid 0 $filt_mac --pop-tag --set-rxif $ifname --cfg-tpid 0x8100 0x8100 0x88a8 0x9100 --rule-append
	elif [ 'doublectag' = $vlanmode ] ; then
		vlanctl --if $l3dev --tx --tags 0 --filter-txif $ifname --push-tag --push-tag --set-vid $outervid 0 --set-vid $vid 1 --set-pbits $pbit 0 --rule-append
		vlanctl --if $l3dev --rx --tags 2 --filter-vid $outervid 0 --filter-vid $vid 1 $filt_mac --pop-tag --pop-tag --set-rxif $ifname --cfg-tpid 0x8100 0x8100 0x88a8 0x9100 --rule-append
	elif [ 'doublestag' = $vlanmode ] ; then
		vlanctl --if $l3dev --tx --tags 0 --filter-txif $ifname --push-tag --push-tag --set-ethertype 0x88a8 --set-cfi 1 0 --set-vid $outervid 0 --set-vid $vid 1 --set-pbits $pbit 0 --rule-append
		vlanctl --if $l3dev --rx --tags 2 --filter-vid $outervid 0 --filter-vid $vid 1 $filt_mac --pop-tag --pop-tag --set-rxif $ifname --cfg-tpid 0x8100 0x8100 0x88a8 0x9100 --rule-append
	elif [ 'appendoutc' = $vlanmode ] ; then
		vlanctl --if $l3dev --tx --tags 1 --filter-txif $ifname --push-tag --set-vid $outervid 0 --set-pbits $pbit 0 --rule-append
		vlanctl --if $l3dev --rx --tags 2 --filter-vid $outervid 0 $filt_mac --pop-tag --set-rxif $ifname --cfg-tpid 0x8100 0x8100 0x88a8 0x9100 --rule-insert-last
	elif [ 'appendouts' = $vlanmode ] ; then
                vlanctl --if $l3dev --tx --tags 1 --filter-txif $ifname --push-tag --set-ethertype 0x88a8 --set-cfi 1 0 --set-vid $outervid 0 --set-pbits $pbit 0 --rule-append
                vlanctl --if $l3dev --rx --tags 2 --filter-vid $outervid 0 $filt_mac --pop-tag --set-rxif $ifname --cfg-tpid 0x8100 0x8100 0x88a8 0x9100 --rule-insert-last
	fi

}

vopi_load_layer3_interfaces() {
	echo "#VLAN Interface , Physical Interface" >> $VOPIIFNAME_SAVE_FILE

	config_load vopi_intfs
	config_foreach vopi_setup_l3_interface interface
}


vopi_delete_vlanif() {
	local vlandev="$1"
	local swstat

	swstat=`ethswctl -c hw-switching |grep Disabled`
	if [ -n "$swstat" ] ; then
		echo "vopi_delete_vlanif:enable ethsw hw-switching"
		ethswctl -c hw-switching -o enable
	fi

	echo "vopi_delete_vlanif:vlandev=$vlandev"
	ifconfig $vlandev down
	vlanctl --if-delete $vlandev
	if [ "$?" != 0 ] ; then
		echo "vlanctl --if-delete [$vlandev] failed!"
	fi
}

detach_ppp_interface() {
	local config="$1"
	local ifname l3dev proto realifname

	ifname="$(uci_get network "$config" ifname)"
	for tmpifname in ${ifname} ; do
		config_get proto "$config" proto
		if [ "$proto" = "pppoe" ] ; then
			l3dev=`uci_get vopi_intfs $tmpifname l3dev`
			if [ ! -z $l3dev ] ; then
				config_get realifname "$config" ifname
				ifconfig $realifname down
			fi
		fi
	done
}

vopi_teardown_ppp_interface() {
	config_load network
	config_foreach detach_ppp_interface interface
}

vopi_unload_layer3_interfaces() {
	vopi_teardown_ppp_interface

	if [ ! -e $VOPIIFNAME_SAVE_FILE ] ; then
		echo "$VOPIIFNAME_SAVE_FILE not exist,return"
		return
	fi
	cat $VOPIIFNAME_SAVE_FILE | while read line
	do
		case $line in
			*VLAN*Interface*)
				;;
			*)
				vlanIf=`echo "$line" |tr -d ' ' | cut -f 1 -d ','`
				vopi_delete_vlanif $vlanIf
				;;
		esac
	done
	rm $VOPIIFNAME_SAVE_FILE
}



