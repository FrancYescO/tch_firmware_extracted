#!/bin/sh

# Configuration handler registered on:
#	WiFi.AccessPoint.{i}.AssociatedDevice.{i}.		DEL
#	WiFi.AccessPoint.{i}.AssociatedDevice.{i}.MACAddress	SET
#	WiFi.AccessPoint.{i}.X_ADB_QoE.				SET

AH_NAME=QoEWiFi

. /etc/ah/helper_functions.sh
. /etc/ah/helper_serialize.sh && help_serialize

# Compute mean (weighted moving average WMA - last element has the biggest weight) value from elements in list
# Usage: mean_fromlist <output_var> <list>
mean_fromlist()
{
	[ "$1" != "listv" ] && local listv
	[ "$1" != "elem" ] && local elem
	[ "$1" != "mean" ] && local mean
	[ "$1" != "parm" ] && local parm

	parm=$1
	listv=$2

	set -f
	IFS=","
	set -- $listv
	unset IFS
	set +f

	for elem; do
		if [ "$elem" != 0 ]; then
			[ -z "$mean" ] && mean=$elem || mean=$(((mean+elem)/2))
		fi
	done
	eval $parm='$mean'
}

# Merge element to list and return merged list
# Usage: mean_fromlist <output_list> <max_size> <list_object> <element_to_add>
update_list()
{
	[ "$1" != "buff_sz" ] && local buff_sz
	[ "$1" != "list" ] && local list
	[ "$1" != "elem" ] && local elem
	[ "$1" != "e_num" ] && local e_num
	[ "$1" != "list_t" ] && local list_t

	buff_sz=$2
	list=$3
	elem=$4

	### Empty List
	if [ ${#list} -eq 0 ]; then
		eval $1='$elem'
		return
	fi

	e_num=1
	list_t=$list
	while [ ${list_t} != ${list_t#*,} ]
	do
		list_t=${list_t#*,}
		e_num=$((e_num+1))
	done

	### If list is full, remove last element
	[ $e_num -ge $buff_sz ] && list=${list#*,}

	eval $1='$list,$elem'
}

# Collect and add statistics to lists
# Usage: xadbqoe_collect_stats <QoE_object> <max_samples>
xadbqoe_collect_stats()
{
	local obj_list ap_o=${1%.X_ADB_QoE} buff_sz=$2
	# inner loop vars
	local mac rssi tput node_o node_rssi node_tput node_ut node_utm

	obj_list=$(cmclient GETO ${ap_o}.AssociatedDevice)
	for obj_list in $obj_list
	do
		mac=$(cmclient GETV ${obj_list}.MACAddress)
		rssi=$(cmclient GETV ${obj_list}.SignalStrength)
		tput=$(cmclient GETV ${obj_list}.X_ADB_Throughput)
		txb=$(cmclient GETV ${obj_list}.Stats.BytesSent)
		rxb=$(cmclient GETV ${obj_list}.Stats.BytesReceived)

		node_o=$(cmclient GETO ${ap_o}.X_ADB_QoE.Node.[MACAddress=${mac}])
		node_rssi=$(cmclient GETV ${node_o}.RSSIList)
		node_tput=$(cmclient GETV ${node_o}.ThroughputList)
		node_ut=$(cmclient GETV ${node_o}.UserThroughputList)
		node_txb=$(cmclient GETV ${node_o}.BytesSent)
		node_rxb=$(cmclient GETV ${node_o}.BytesReceived)

		update_list "node_rssi" "$buff_sz" "$node_rssi" "$rssi"
		update_list "node_tput" "$buff_sz" "$node_tput" "$tput"
		mean_fromlist "node_tputm" "$node_tput"
		mean_fromlist "node_rssim" "$node_rssi"

		[ -n "$txb" ] || txb=0
		[ -n "$rxb" ] || rxb=0
		if [ "$node_rxb" = "0" -a "$node_txb" = "0" ]; then
			node_utm=0
		else
			if [ $txb -ge $node_txb ]; then
				dtxb=$((txb-node_txb))
			else
				# FIXME
				dtxb=$((node_txb))
			fi
			if [ $rxb -ge $node_rxb ]; then
				drxb=$((rxb-node_rxb))
			else
				# FIXME
				drxb=$((node_rxb))
			fi
			# 8/1000 = 1/125
			calc=$((((dtxb+drxb)/125)/newSamplingInterval))
			update_list "node_ut" "$buff_sz" "$node_ut" "$calc"
			mean_fromlist "node_utm" "$node_ut"
		fi

		cmclient SETEM "${node_o}.RSSIList=$node_rssi	${node_o}.ThroughputList=$node_tput	\
				${node_o}.RSSI=$node_rssim	${node_o}.Throughput=$node_tputm	\
				${node_o}.BytesSent=$txb	${node_o}.BytesReceived=$rxb	\
				${node_o}.UserThroughputList=$node_ut	${node_o}.UserThroughput=$node_utm"
	done
}

# Reset QoE statistics
# Usage: xadbqoe_reset_stats <QoE_object>
xadbqoe_reset_stats()
{
	local qoe_o=$1
	cmclient SETEM "${qoe_o}.Node.RSSIList=	${qoe_o}.Node.ThroughputList=	\
			${qoe_o}.Node.UserThroughputList=	\
			${qoe_o}.Node.BytesSent=0	${qoe_o}.Node.BytesReceived=0"
}

# Check enable of QoE auto trigger (SamplingInterval != 0)
# Usage: xadbqoe_checkenabled <accesspoint_object>
xadbqoe_checkenabled()
{
	local ap_o=$1 smp_int
	smp_int=$(cmclient GETV ${ap_o}.X_ADB_QoE.SamplingInterval)
	[ "$smp_int" = "0" ] && return 1
	return 0
}

# Create timer for QoE WiFI
# Usage: xadbqoe_createtimer <QoE_object> <timer_DeadLine>
xadbqoe_createtimer()
{
	local timer_o qoe_o=$1 deadline=$2
	[ -z "$deadline" ] && deadline=$(cmclient GETV ${qoe_o}.SamplingInterval)

	timer_o=$(cmclient GETO Device.X_ADB_Time.Event.[Alias=${qoe_o#Device.WiFi.}])
	if [ ${#timer_o} -eq 0 ]; then
		timer_o=$(cmclient ADDS Device.X_ADB_Time.Event.[Alias=${qoe_o#Device.WiFi.}].[Type=Periodic])
		timer_o=Device.X_ADB_Time.Event.${timer_o}
		cmclient ADD ${timer_o}.Action.[Operation=Set].[Path=${qoe_o}.Update].[Value=true]
		cmclient SET ${timer_o}.Enable true
	fi
	cmclient SET ${timer_o}.DeadLine $deadline
}

# Change max elements for lists - if change to lower then delete lasts elements
# Usage: xadbqoe_changebuffsz <QoE_object> <old_size> <new_size>
xadbqoe_changebuffsz()
{
	local qoe_o=$1 old_buffsz=$2 new_buffsz=$3 resize_num node indx \
		rssi_list tput_list

	[ $old_buffsz -le $new_buffsz ] && return
	resize_num=$((oldSamplesCount-newSamplesCount))

	node=$(cmclient GETO ${qoe_o}.Node)
	for node in $node
	do
		indx=$resize_num
		rssi_list=$(cmclient GETV ${node}.RSSIList)
		tput_list=$(cmclient GETV ${node}.ThroughputList)
		while [ $indx -gt 0 ]; do
			rssi_list=${rssi_list#*,}
			tput_list=${tput_list#*,}
			indx=$((indx-1))
		done
		cmclient SETEM "${node}.RSSIList=${rssi_list}	${node}.ThroughputList=${tput_list}"
	done
}


service_config_assocdevice()
{
	local date setem="" node_o ap_o=${obj%%.AssociatedDevice*}

	node_o=$(cmclient GETO ${ap_o}.X_ADB_QoE.Node.[MACAddress=$newMACAddress])
	if [ ${#node_o} -eq 0 ]; then
		node_o=$(cmclient ADD ${ap_o}.X_ADB_QoE.Node)
		node_o=${ap_o}.X_ADB_QoE.Node.${node_o}
		setem="	${node_o}.MACAddress=${newMACAddress}"
	fi
	date=`date -u +%FT%TZ`
	setem="	${node_o}.LastAssociation=${date}${setem}"
	setem="${node_o}.Active=true${setem}"
	cmclient SETEM "$setem"

	### Create timer?
	xadbqoe_checkenabled "$ap_o" || return

	xadbqoe_createtimer "${ap_o}.X_ADB_QoE"
}

service_delete_assocdevice()
{
	local date node_o ap_o=${obj%%.AssociatedDevice*} assdev

	node_o=$(cmclient GETO ${ap_o}.X_ADB_QoE.Node.[MACAddress=$newMACAddress])
	if [ ${#node_o} -eq 0 ]; then
		echo "$AH_NAME: warning, $obj untracked" > /dev/console
		return
	fi
	date=`date -u +%FT%TZ`
	cmclient SETE ${node_o}.LastDisassociation ${date}
	cmclient SETE ${node_o}.Active false

	### Need to stop the timer?
	xadbqoe_checkenabled "$ap_o" || return

	assdev=$(cmclient GETV ${ap_o}.AssociatedDeviceNumberOfEntries)
	[ "$assdev" = "1" ] && cmclient DEL Device.X_ADB_Time.Event.[Alias=${ap_o#Device.WiFi.}.X_ADB_QoE]
}


service_config_xadbqoe() {
	local qoe_o=$obj
	if [ "$newUpdate" = "true" ]; then
		xadbqoe_collect_stats "$qoe_o" "$newSamplesCount"
		cmclient SETE ${qoe_o}.Update false
	fi
	if [ "$newResetStats" = "true" ]; then
		xadbqoe_reset_stats "$qoe_o"
		cmclient SETE ${qoe_o}.ResetStats false
	fi
	help_is_changed SamplingInterval \
		&& xadbqoe_createtimer "$qoe_o" "$newSamplingInterval"

	help_is_changed SamplesCount \
		&& xadbqoe_changebuffsz "$qoe_o" "${oldSamplesCount:-0}" "$newSamplesCount"
}

service_config()
{
	case $obj in
		*.AssociatedDevice.*)
			service_config_assocdevice
			;;
		*.X_ADB_QoE)
			service_config_xadbqoe "$obj"
			;;
	esac
}

service_delete()
{
	case $obj in
		*.AssociatedDevice.*)
			service_delete_assocdevice
			;;
	esac
}

##################
### Start here ###
##################

case "$op" in
	d)
		service_delete
		;;
	s)
		service_config
		;;
esac

exit 0
