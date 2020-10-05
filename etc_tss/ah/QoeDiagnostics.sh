#!/bin/sh

case "$obj" in
Device.X_ADB_QoE.SamplingDiagnostics)
	TIME_OBJ="Check_QoE_Sampling"
	DIAG_OBJ="Device.X_ADB_QoE.Sampling"
	DIAG_TYPE="Sampling"
	;;
Device.X_ADB_QoE.DownloadDiagnostics)
	TIME_OBJ_OLD="Check_QoE_Downlaod"
	TIME_OBJ="Check_QoE_Download"
	DIAG_OBJ="Device.IP.Diagnostics.X_ADB_DownloadDiagnostics"
	DIAG_TYPE="Download"
	;;
Device.X_ADB_QoE.UploadDiagnostics)
	TIME_OBJ="Check_QoE_Upload"
	DIAG_OBJ="Device.IP.Diagnostics.X_ADB_UploadDiagnostics"
	DIAG_TYPE="Upload"
	;;
Device.X_ADB_QoE.NSLookupDiagnostics)
	TIME_OBJ="Check_QoE_NSLookup"
	DIAG_OBJ="Device.DNS.Diagnostics.X_ADB_NSLookup"
	DIAG_TYPE="NSLookup"
	;;
Device.X_ADB_QoE.UDPEchoDiagnostics)
	TIME_OBJ="Check_QoE_UDPEcho"
	DIAG_OBJ="Device.IP.Diagnostics.X_ADB_UDPEchoDiagnostics"
	DIAG_TYPE="UDPEcho"
	;;
Device.X_ADB_QoE.LANDiagnostics)
	TIME_OBJ="Check_QoE_LAN"
	DIAG_OBJ="Device.IP.Diagnostics.X_ADB_LANDiagnostics"
	DIAG_TYPE="LAN"
	;;
Device.X_ADB_QoE.WiFiChannelMeasurementsDiagnostics)
	TIME_OBJ="Check_QoE_WiFiChannelMeasurements"
	DIAG_OBJ="Device.WiFi.X_ADB_WiFiChannelMeasurementsDiagnostics"
	DIAG_TYPE="WiFiChannelMeasurements"
	;;
Device.X_ADB_QoE.AssociatedDevicesDiagnostics)
	TIME_OBJ="Check_QoE_AssociatedDevices"
	DIAG_OBJ="Device.WiFi.X_ADB_AssociatedDevicesDiagnostics"
	DIAG_TYPE="AssociatedDevices"
	;;
Device.X_ADB_QoE.MPDUDiagnostics)
	TIME_OBJ="Check_QoE_MPDU"
	DIAG_OBJ="Device.WiFi.X_ADB_MPDUDiagnostics"
	DIAG_TYPE="MPDU"
	;;
*)
	exit 0
esac

qoe_stop()
{
	cmclient SET "X_ADB_Time.Event.[Alias=$TIME_OBJ].Enable" "false"
	# temporary trick
	[ ${#TIME_OBJ_OLD} -eq 0 ] || cmclient DEL "X_ADB_Time.Event.[Alias=$TIME_OBJ_OLD]"
	rm -f "/tmp/${TIME_OBJ}_Delayed"
	logger -t qoe -p 4 "$DIAG_TYPE - stopped"
}

qoe_schedule()
{
	local ret eventObj id aid set_p deadLine _deadLine _enable

	eventObj=$(cmclient GETO "X_ADB_Time.Event.[Alias=$TIME_OBJ]")
	if [ ${#eventObj} -eq 0 ]; then
		id=$(cmclient ADD X_ADB_Time.Event)
		eventObj="Device.X_ADB_Time.Event.$id"
		set_p="$eventObj.Alias=$TIME_OBJ"
		aid=$(cmclient ADD "$eventObj.Action")
		set_p="$set_p	$eventObj.Action.$aid.Path=$obj.Check"
		set_p="$set_p	$eventObj.Action.$aid.Value=true"
		cmclient SETEM "$set_p"
	fi
	if [ "$newStartupDelayRange" -gt 0 ] && [ ! -f "/tmp/${TIME_OBJ}_Delayed" ]; then
		logger -t qoe -p 4 "$DIAG_TYPE - Evaluating random delay, max ${newStartupDelayRange}min"
		deadLine="1$(tr -cd "0-9" < /dev/urandom | head -c 9)"
		deadLine=$((deadLine%(newStartupDelayRange*60)+1))
		echo "$deadLine" > "/tmp/${TIME_OBJ}_Delayed"

		#qoe test must be delayed
		ret=1
	else
		logger -t qoe -p 6 "$DIAG_TYPE - Start test execution now"
		deadLine=$((newExecutionInterval*60))

		#qoe test can start now
		ret=0
	fi
	_deadLine=$(cmclient GETV "$eventObj.DeadLine")
	_enable=$(cmclient GETV "$eventObj.Enable")
	if [ "$_deadLine" != "$deadLine" -o "$_enable" != "true" ]; then
		set_p="$eventObj.DeadLine=$deadLine"
		set_p="$set_p	$eventObj.Type=Periodic"
		set_p="$set_p	$eventObj.Enable=true"
		cmclient SETM "$set_p"
		logger -t qoe -p 6 "$DIAG_TYPE - Next test execution in ${deadLine}sec"
	fi
	return $ret
}

qoe_check_mem()
{
	local ret=0 minfree memfree

	minfree=$((${newMinFreeMemory:-0}*1000))
	if [ $minfree -gt 0 ]; then
		memfree=$(cmclient GETV "Device.DeviceInfo.MemoryStatus.Free")
		if [ ${memfree:-0} -lt $minfree ]; then
			ret=1
			logger -t qoe -p 3 "$DIAG_TYPE - Out of memory (${memfree}Kb free)"
		fi
	fi
	return $ret
}

qoe_start()
{
	logger -t qoe -p 4 "$DIAG_TYPE - starting..."

	#delete previous test instances
	cmclient DEL "$DIAG_OBJ.[Alias>QoeTest_]"

	if qoe_schedule; then
		if qoe_check_mem; then
			#start first test instance now
			newExecutionCount=1
			cmclient SETE "${obj}.ExecutionCount" "$newExecutionCount"
			qoe_add
		else
			newDiagnosticsState=Error_OutOfMemory
			cmclient SETE "${obj}.DiagnosticsState" "$newDiagnosticsState"
			qoe_stop
		fi
	else
		newExecutionCount=0
		cmclient SETE "${obj}.ExecutionCount" "$newExecutionCount"
	fi
}

qoe_add()
{
	local id set_p noe ADD=ADD

	noe=$(cmclient GETV "${DIAG_OBJ}NumberOfEntries")
	[ ${#noe} -eq 0 ] && noe=0
	if [ $noe -ge $newMaxStored ]; then
		ADD=ADDS
		logger -t qoe -p 4 "$DIAG_TYPE - Test n.${newExecutionCount} won't be stored, max $newMaxStored"
	fi
	id=$(cmclient $ADD $DIAG_OBJ)
	cmclient SETE "$DIAG_OBJ.$id.Alias" "QoeTest_$newExecutionCount"
	case "$obj" in
	Device.X_ADB_QoE.SamplingDiagnostics)
		set_p="$DIAG_OBJ.$id.PathList=$newPathList"
		set_p="$set_p	$DIAG_OBJ.$id.SamplesNumber=$newSamplesNumber"
		set_p="$set_p	$DIAG_OBJ.$id.SamplesInterval=$newSamplesInterval"
		;;
	Device.X_ADB_QoE.DownloadDiagnostics)
		set_p="$DIAG_OBJ.$id.Interface=$newInterface"
		set_p="$set_p	$DIAG_OBJ.$id.DownloadURL=$newDownloadURL"
		set_p="$set_p	$DIAG_OBJ.$id.TimeBasedTestDuration=$newTimeBasedTestDuration"
		set_p="$set_p	$DIAG_OBJ.$id.TimeBasedTestIncrements=$newTimeBasedTestIncrements"
		set_p="$set_p	$DIAG_OBJ.$id.TimeBasedTestIncrementsOffset=$newTimeBasedTestIncrementsOffset"
		set_p="$set_p	$DIAG_OBJ.$id.DSCP=$newDSCP"
		set_p="$set_p	$DIAG_OBJ.$id.EthernetPriority=$newEthernetPriority"
		set_p="$set_p	$DIAG_OBJ.$id.X_ADB_TrafficPriority=$newTrafficPriority"
		;;
	Device.X_ADB_QoE.UploadDiagnostics)
		set_p="$DIAG_OBJ.$id.Interface=$newInterface"
		set_p="$set_p	$DIAG_OBJ.$id.UploadURL=$newUploadURL"
		set_p="$set_p	$DIAG_OBJ.$id.TestFileLength=$newTestFileLength"
		set_p="$set_p	$DIAG_OBJ.$id.TimeBasedTestDuration=$newTimeBasedTestDuration"
		set_p="$set_p	$DIAG_OBJ.$id.TimeBasedTestIncrements=$newTimeBasedTestIncrements"
		set_p="$set_p	$DIAG_OBJ.$id.TimeBasedTestIncrementsOffset=$newTimeBasedTestIncrementsOffset"
		set_p="$set_p	$DIAG_OBJ.$id.DSCP=$newDSCP"
		set_p="$set_p	$DIAG_OBJ.$id.EthernetPriority=$newEthernetPriority"
		set_p="$set_p	$DIAG_OBJ.$id.X_ADB_TrafficPriority=$newTrafficPriority"
		;;
	Device.X_ADB_QoE.NSLookupDiagnostics)
		set_p="$DIAG_OBJ.$id.Interface=$newInterface"
		set_p="$set_p	$DIAG_OBJ.$id.HostName=$newHostName"
		set_p="$set_p	$DIAG_OBJ.$id.DNSServer=$newDNSServer"
		set_p="$set_p	$DIAG_OBJ.$id.Timeout=$newTimeout"
		set_p="$set_p	$DIAG_OBJ.$id.NumberOfRepetitions=$newNumberOfRepetitions"
		;;
	Device.X_ADB_QoE.UDPEchoDiagnostics)
		set_p="$DIAG_OBJ.$id.Interface=$newInterface"
		set_p="$set_p	$DIAG_OBJ.$id.EchoPlusEnabled=$newEchoPlusEnabled"
		set_p="$set_p	$DIAG_OBJ.$id.Host=$newHost"
		set_p="$set_p	$DIAG_OBJ.$id.X_ADB_UDPPort=$newUDPPort"
		set_p="$set_p	$DIAG_OBJ.$id.NumberOfRepetitions=$newNumberOfRepetitions"
		set_p="$set_p	$DIAG_OBJ.$id.Timeout=$newTimeout"
		set_p="$set_p	$DIAG_OBJ.$id.DataBlockSize=$newDataBlockSize"
		set_p="$set_p	$DIAG_OBJ.$id.DSCP=$newDSCP"
		set_p="$set_p	$DIAG_OBJ.$id.InterTransmissionTime=$newInterTransmissionTime"
		set_p="$set_p	$DIAG_OBJ.$id.X_ADB_TrafficClass=$newTrafficClass"
		set_p="$set_p	$DIAG_OBJ.$id.X_ADB_IndividualPacketResults=$newIndividualPacketResults"
		;;
	Device.X_ADB_QoE.LANDiagnostics)
		set_p="$DIAG_OBJ.$id.Interface=$newInterface"
		set_p="$set_p	$DIAG_OBJ.$id.Target=$newTarget"
		set_p="$set_p	$DIAG_OBJ.$id.ProbingMethod=$newProbingMethod"
		set_p="$set_p	$DIAG_OBJ.$id.SmallMtu=$newSmallMtu"
		set_p="$set_p	$DIAG_OBJ.$id.BigMtu=$newBigMtu"
		set_p="$set_p	$DIAG_OBJ.$id.Numprobes=$newNumprobes"
		set_p="$set_p	$DIAG_OBJ.$id.Interval=$newInterval"
		set_p="$set_p	$DIAG_OBJ.$id.LowerPercentile=$newLowerPercentile"
		set_p="$set_p	$DIAG_OBJ.$id.AvgPercentile=$newAvgPercentile"
		set_p="$set_p	$DIAG_OBJ.$id.Timeout=$newTimeout"
		;;
	Device.X_ADB_QoE.WiFiChannelMeasurementsDiagnostics)
		set_p="$DIAG_OBJ.$id.Duration=$newDuration"
		set_p="$set_p	$DIAG_OBJ.$id.Band=$newBand"
		;;
	Device.X_ADB_QoE.AssociatedDevicesDiagnostics)
		set_p="$DIAG_OBJ.$id.DeviceList=$newDeviceList"
		;;
	esac
	cmclient SETEM "$set_p"
	logger -t qoe -p 6 "$DIAG_TYPE - Test n.${newExecutionCount} Requested"
	cmclient SET "$DIAG_OBJ.$id.DiagnosticsState" Requested
	# optional lookup test on secondary DNS server
	if [ ${#newDNSServer2} -gt 0 ]; then
		id=$(cmclient $ADD $DIAG_OBJ)
		cmclient SETE "$DIAG_OBJ.$id.Alias" "QoeTest_${newExecutionCount}_2"
		set_p="$DIAG_OBJ.$id.Interface=$newInterface"
		set_p="$set_p	$DIAG_OBJ.$id.HostName=$newHostName"
		set_p="$set_p	$DIAG_OBJ.$id.DNSServer=$newDNSServer2"
		set_p="$set_p	$DIAG_OBJ.$id.Timeout=$newTimeout"
		set_p="$set_p	$DIAG_OBJ.$id.NumberOfRepetitions=$newNumberOfRepetitions"
		cmclient SETEM "$set_p"
		logger -t qoe -p 6 "$DIAG_TYPE - Test n.${newExecutionCount}_2 Requested"
		cmclient SET "$DIAG_OBJ.$id.DiagnosticsState" Requested
	fi
}

qoe_check()
{
	if [ "$newDiagnosticsState" = "Requested" ]; then
		if [ "$newExecutionCount" -lt "$newExecutionNumber" ]; then
			if qoe_schedule; then
				if qoe_check_mem; then
					newExecutionCount=$((newExecutionCount+1))
					cmclient SETE "${obj}.ExecutionCount" "$newExecutionCount"
					qoe_add
				else
					newDiagnosticsState=Error_OutOfMemory
					cmclient SETE "${obj}.DiagnosticsState" "$newDiagnosticsState"
					qoe_stop
				fi
			fi
		fi
		if [ "$newExecutionCount" -ge "$newExecutionNumber" ]; then
			logger -t qoe -p 4 "$DIAG_TYPE - completed"
			newDiagnosticsState=Completed
			cmclient SETE "${obj}.DiagnosticsState" "$newDiagnosticsState"
			qoe_stop
		fi
	else
		qoe_stop
	fi

	#save diagnostics status
	cmclient SAVE
}

##################
### Start here ###
##################

case "$op" in
s)
	if [ "$setDiagnosticsState" = "1" ]; then
		case "$newDiagnosticsState" in
		Requested)
			qoe_stop
			qoe_start
			;;
		None)
			qoe_stop
			;;
		*)
			exit 1
			;;
		esac
	elif [ "$setCheck" = "1" -a "$newCheck" = "true" ]; then
		qoe_check &
	else
		qoe_stop
		cmclient SETE "$obj.DiagnosticsState" None
	fi
	;;
esac
exit 0
