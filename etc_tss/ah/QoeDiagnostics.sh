#!/bin/sh

case "$obj" in
Device.X_ADB_QoE.IPPingDiagnostics)
	TIME_OBJ="Check_QoE_IPPing"
	DIAG_OBJ="Device.IP.Diagnostics.X_ADB_IPPing"
	DIAG_TYPE="IPPing"
	;;
Device.X_ADB_QoE.TraceRouteDiagnostics)
	TIME_OBJ="Check_QoE_TraceRoute"
	DIAG_OBJ="Device.IP.Diagnostics.X_ADB_TraceRoute"
	DIAG_TYPE="TraceRoute"
	;;
Device.X_ADB_QoE.SamplingDiagnostics)
	TIME_OBJ="Check_QoE_Sampling"
	DIAG_OBJ="Device.X_ADB_QoE.Sampling"
	DIAG_TYPE="Sampling"
	;;
Device.X_ADB_QoE.DownloadDiagnostics)
	TIME_OBJ_OLD="Check_QoE_Download"
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
Device.X_ADB_QoE.YoutubeDiagnostics)
	TIME_OBJ="Check_QoE_Youtube"
	DIAG_OBJ="Device.IP.Diagnostics.X_ADB_YoutubeDiagnostics"
	DIAG_TYPE="Youtube"
	;;
Device.X_ADB_QoE.WebDiagnostics)
	TIME_OBJ="Check_QoE_Web"
	DIAG_OBJ="Device.IP.Diagnostics.X_ADB_WebDiagnostics"
	DIAG_TYPE="Web"
	;;
Device.X_ADB_QoE.Scheduler)
	TIME_OBJ="Check_QoE_Scheduler"
	DIAG_OBJ=""
	DIAG_TYPE="Scheduler"
	;;
*)
	exit 0
esac

getActualSecond()
{
	local minutes hours seconds
	minutes=$(date +%M)
	minutes=${minutes#0*}
	hours=$(date +%H)
	hours=${hours#0*}
	seconds=$(date +%S)
	seconds=${seconds#0*}
	minutes=$((hours*60+minutes))
	seconds=$((minutes*60+seconds))
	echo $seconds
}

qoe_stop()
{
	cmclient SET "X_ADB_Time.Event.[Alias=$TIME_OBJ].Enable" "false"
	# temporary trick
	[ ${#TIME_OBJ_OLD} -eq 0 ] || cmclient DEL "X_ADB_Time.Event.[Alias=$TIME_OBJ_OLD]"
	rm -f "/tmp/${TIME_OBJ}_Delayed"
	logger -t qoe -p 4 "$DIAG_TYPE - stopped"

	#if scheduler finish loop set all include tests request to none - clear results
	if [ "$DIAG_TYPE" = "Scheduler" ]; then
		if [ "$newDiagnosticsState" = "Requested" -o "$newDiagnosticsState" = "None" ]; then
			IFS=","
			for testName in $newPathList; do
				cmclient SET "X_ADB_QoE.${testName}.DiagnosticsState" "None"
			done
			unset IFS
			pids=$(ls /tmp/scheduler_run_pids/)
			for pids in $pids; do
				pid=$(cat /tmp/scheduler_run_pids/$pids)
				kill -9 $pid
				rm -f /tmp/scheduler_run_pids/$pids
			done
			rm -f /tmp/scheduler_run
		fi
	else
		if [ "$newDiagnosticsState" = "None" ]; then
			cmclient SET "$DIAG_OBJ.[Alias>QoeTest_].[DiagnosticsState=Requested].DiagnosticsState" "None"
		fi
	fi
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
		#deadLine="1$(tr -cd "0-9" < /dev/urandom | head -c 9)"
		deadLine=`cut -c1-10 < "/proc/sys/kernel/random/uuid"`
		deadLine=${deadLine//[!0-9]} #get only numbers
		while [ "${deadLine:0:1}" = "0" ]; do deadLine=${deadLine##0}; done #remove leading zeros
		deadLine=$((deadLine%(newStartupDelayRange*60)+1))
		echo "$deadLine" > "/tmp/${TIME_OBJ}_Delayed"

		#qoe test must be delayed
		ret=1
	else
		logger -t qoe -p 6 "$DIAG_TYPE - Start test execution now"
		deadLine=$((newExecutionInterval))

		#qoe test can start now
		ret=0
	fi

	set_p="$eventObj.DeadLine=$deadLine"
	if [ $((newExecutionCount+1)) -ge $newExecutionNumber ]; then
		#if last loop disable timer
		[ $ret -eq 0 ] && cmclient SET "$eventObj.Enable" "false" && return $ret
		#if is last and delayed loop set aperiodic timer
		set_p="$set_p	$eventObj.Type=PersistentAperiodic"
	else
		set_p="$set_p	$eventObj.Type=Periodic"
	fi
	set_p="$set_p	$eventObj.Enable=true"
	cmclient SETM "$set_p"
	logger -t qoe -p 6 "$DIAG_TYPE - Next test execution in ${deadLine}sec"

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

qoe_check_cpu()
{
	local ret=0 maxCpuUsage cpuUsage

	maxCpuUsage=$newCPUThreshold
	cpuUsage=$(cmclient GETV "Device.DeviceInfo.ProcessStatus.CPUUsage")
	if [ $cpuUsage -gt $maxCpuUsage ]; then
		ret=2
		logger -t qoe -p 3 "$DIAG_TYPE - CPU Usage over limit: ${cpuUsage}%"
	fi
	return $ret
}

read_wan_kbytes()
{
	local txLine=0 rxLine=0 txBytes=0 rxBytes=0
	wan=$(cmclient GETV "Device.IP.Interface.1.Name")
	while IFS=" " read -r a b c d e; do
		case "$a" in
		"TX:")
			txLine=1
		;;
		"RX:")
			rxLine=1
		;;
		*)
			if [ $txLine -eq 1 ]; then
				txBytes=$((a/1024))
				txLine=0
			fi
			if [ $rxLine -eq 1 ]; then
				rxBytes=$((a/1024))
				rxLine=0
			fi
		;;
		esac
	done <<-EOF
        `ip -s link show ${wan}`
	EOF
	echo $((txBytes+rxBytes))
}

qoe_check_traffic()
{
	local ret=0 maxTraffic currentTraffic wan

	maxTraffic=$newUserTrafficThreshold
	first=`read_wan_kbytes`
	sleep 1
	second=`read_wan_kbytes`
	diff=$((second-first))
	if [ $diff -gt $maxTraffic ]; then
		logger -t qoe -p 3 "$DIAG_TYPE User traffic over limit: ${diff}kbit/sec"
		ret=3
	fi
	return $ret
}

qoe_start()
{
	local diagObj
	logger -t qoe -p 4 "$DIAG_TYPE - starting..."
	newExecutionCount=0
	#delete previous test instances - only if it's first test in series
	#to clear series it's needed to change previous to None
	[ "${oldDiagnosticsState}" = "None" ] && cmclient DEL "$DIAG_OBJ.[Alias>QoeTest_]"

	if qoe_schedule; then
		if [ "$DIAG_TYPE" = "Scheduler" ]; then
			memRes=0
			cpuRes=0
			trafRes=0
		else
			qoe_check_mem
			memRes=$?
			qoe_check_cpu
			cpuRes=$?
			qoe_check_traffic
			trafRes=$?
		fi
		if [ $memRes -eq 0 -a $cpuRes -eq 0 -a $trafRes -eq 0 ]; then
			#start first test instance now
			newExecutionCount=1
			cmclient SETE "${obj}.ExecutionCount" "$newExecutionCount"
			if [ "$DIAG_TYPE" = "Scheduler" ]; then
				scheduler_run_loop &
				mkdir -p /tmp/scheduler_run_pids
				echo "$!" > /tmp/scheduler_run_pids/$$
			else
				qoe_add "Requested"
				idx=$?
				diagObj="$DIAG_OBJ.$idx"
			fi
			if [ "$newExecutionCount" -ge "$newExecutionNumber" ]; then
				#qoe_wait_for_termination ${obj} $(cmclient GETO "${DIAG_OBJ}.[DiagnosticsState=Requested]")
				qoe_wait_for_termination ${obj} $diagObj
				#logger -t qoe -p 4 "$DIAG_TYPE - completed"
				#newDiagnosticsState=Completed
				#cmclient SETE "${obj}.DiagnosticsState" "$newDiagnosticsState"
				[ "$DIAG_TYPE" = "Scheduler" ] && cmclient SET X_ADB_QoE.Scheduler.Report.Upload "true" && qoe_stop
			fi
			#if [ "$newExecutionCount" -ge "$newExecutionNumber" ]; then
			#	logger -t qoe -p 4 "$DIAG_TYPE - completed"
			#	newDiagnosticsState=Completed
			#	cmclient SETE "${obj}.DiagnosticsState" "$newDiagnosticsState"
			#	[ "$DIAG_TYPE" = "Scheduler" ] && cmclient SET X_ADB_QoE.Scheduler.Report.Upload "true"
			#	qoe_stop
			#fi
		else
			if [ $memRes -ne 0 ]; then
				newDiagnosticsState=Error_OutOfMemory
			elif [ $cpuRes -ne 0 ]; then
				newDiagnosticsState=Error_CPUThresholdExceeded
			elif [ $trafRes -ne 0 ]; then
				newDiagnosticsState=Error_TrafficThresholdExceeded
			fi
			qoe_add "$newDiagnosticsState"
			idx=$?
			diagObj="$DIAG_OBJ.$idx"
			st=`date -u +%FT%TZ`
			cmclient SETE "${diagObj}.X_ADB_StartTime" "$st"
			cmclient SETE "${obj}.DiagnosticsState" "$newDiagnosticsState"
			qoe_stop
		fi
	else
		cmclient SETE "${obj}.ExecutionCount" "$newExecutionCount"
	fi
}

qoe_add()
{
	local id set_p noe ADD=ADD it=0 aliasToAdd="QoeTest_$newExecutionCount" aliasExist
	local newState=$1
	noe=$(cmclient GETV "${DIAG_OBJ}NumberOfEntries")
	[ ${#noe} -eq 0 ] && noe=0
	if [ $noe -ge $newMaxStored ]; then
		ADD=ADDS
		logger -t qoe -p 4 "$DIAG_TYPE - Test n.${newExecutionCount} won't be stored, max $newMaxStored"
	fi
	id=$(cmclient $ADD $DIAG_OBJ)
	while [ 1 ]; do
		aliasExist=`cmclient GETO "${DIAG_OBJ}.[Alias=${aliasToAdd}]`
		[ ${#aliasExist} -eq 0 ] && break
		it=$((it+1))
		aliasToAdd="QoeTest_${newExecutionCount}_${it}"
	done
	cmclient SETE "$DIAG_OBJ.$id.Alias" "$aliasToAdd"
	case "$obj" in
	Device.X_ADB_QoE.IPPingDiagnostics)
		set_p="$DIAG_OBJ.$id.Host=$newHost"
		set_p="$set_p	$DIAG_OBJ.$id.Interface=$newInterface"
		set_p="$set_p	$DIAG_OBJ.$id.Timeout=$newTimeout"
		set_p="$set_p	$DIAG_OBJ.$id.DataBlockSize=$newDataBlockSize"
		set_p="$set_p	$DIAG_OBJ.$id.DSCP=$newDSCP"
		set_p="$set_p	$DIAG_OBJ.$id.NumberOfRepetitions=$newNumberOfRepetitions"
		;;
	Device.X_ADB_QoE.TraceRouteDiagnostics)
		set_p="$DIAG_OBJ.$id.Host=$newHost"
		set_p="$set_p	$DIAG_OBJ.$id.Interface=$newInterface"
		set_p="$set_p	$DIAG_OBJ.$id.Timeout=$newTimeout"
		set_p="$set_p	$DIAG_OBJ.$id.DataBlockSize=$newDataBlockSize"
		set_p="$set_p	$DIAG_OBJ.$id.DSCP=$newDSCP"
		set_p="$set_p	$DIAG_OBJ.$id.NumberOfTries=$newNumberOfTries"
		set_p="$set_p	$DIAG_OBJ.$id.MaxHopCount=$newMaxHopCount"
		;;
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
	Device.X_ADB_QoE.YoutubeDiagnostics)
		set_p="$DIAG_OBJ.$id.URL=$newURL"
		set_p="$set_p	$DIAG_OBJ.$id.BufferSize=$newBufferSize"
		set_p="$set_p	$DIAG_OBJ.$id.MinTime=$newMinTime"
		set_p="$set_p	$DIAG_OBJ.$id.MaxTime=$newMaxTime"
		set_p="$set_p	$DIAG_OBJ.$id.BitRate=$newBitRate"
		set_p="$set_p	$DIAG_OBJ.$id.ProtocolVersion=$newProtocolVersion"
		set_p="$set_p	$DIAG_OBJ.$id.OneBitRate=$newOneBitRate"
		;;
	Device.X_ADB_QoE.WebDiagnostics)
		set_p="$DIAG_OBJ.$id.URL=$newURL"
		;;
	esac
	cmclient SETEM "$set_p"
	logger -t qoe -p 6 "$DIAG_TYPE - Test n.${newExecutionCount} $newState"
	cmclient SET "$DIAG_OBJ.$id.DiagnosticsState" $newState
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
		logger -t qoe -p 6 "$DIAG_TYPE - Test n.${newExecutionCount}_2 $newState"
		cmclient SET "$DIAG_OBJ.$id.DiagnosticsState" $newState
	fi
	return ${id}
}

qoe_wait_for_termination()
{
	local QoEObject=$1 watchedObject=$2 result="Requested"
	while [ "$result" = "Requested" ]; do
		sleep 1
		result=$(cmclient GETV "${watchedObject}.DiagnosticsState")
	done
	logger -t qoe -p 4 "${QoEObject//"Device.X_ADB_QoE."} - completed"
	cmclient SET "${QoEObject}.DiagnosticsState" "Completed"
	qoe_stop
}

qoe_check()
{
	local diagObj memRes cpuRes trafRes
	if [ "$newDiagnosticsState" = "Requested" ]; then
		if [ "$newExecutionCount" -lt "$newExecutionNumber" ]; then
			if qoe_schedule; then
				qoe_check_mem
				memRes=$?
				qoe_check_cpu
				cpuRes=$?
				qoe_check_traffic
				trafRes=$?
				if [ !$memRes -a !$cpuRes -a !$trafRes ]; then
					newExecutionCount=$((newExecutionCount+1))
					cmclient SETE "${obj}.ExecutionCount" "$newExecutionCount"
					if [ "$DIAG_TYPE" = "Scheduler" ]; then
						scheduler_run_loop
					else
						qoe_add "Requested"
						idx=$?
						diagObj="$DIAG_OBJ.$idx"
					fi
				else
					newDiagnosticsState=Error_OutOfMemory
					cmclient SETE "${obj}.DiagnosticsState" "$newDiagnosticsState"
					qoe_stop
				fi
				if [ "$newExecutionCount" -ge "$newExecutionNumber" ]; then
					cmclient SETE "${obj}.DiagnosticsState" "Completed"
					[ "$DIAG_TYPE" = "Scheduler" ] && cmclient SET X_ADB_QoE.Scheduler.Report.Upload "true" && qoe_stop
				fi
			fi
		fi
		if [ "$newExecutionCount" -ge "$newExecutionNumber" ]; then
			[ "$DIAG_TYPE" = "Scheduler" ] || qoe_wait_for_termination ${obj} ${diagObj}
			#logger -t qoe -p 4 "$DIAG_TYPE - completed"
			#newDiagnosticsState=Completed
			#cmclient SETE "${obj}.DiagnosticsState" "$newDiagnosticsState"
		fi
	else
		qoe_stop
	fi
	[ -e /tmp/scheduler_run_pids/$$ ] && rm -f /tmp/scheduler_run_pids/$$
	#save diagnostics status
	cmclient SAVE
}

scheduler_run_loop()
{
	local testName idx status="" objectsToSampling= objectList= immediate_inactive
	#mkdir -p /tmp/scheduler_run_pids
	#echo "" > /tmp/scheduler_run_pids/$mainPid
	while true; do
		[ -e /tmp/scheduler_run ] && sleep 1 && continue
		pids=$(ls /tmp/scheduler_run_pids/)
		for pids in $pids; do
			break;
		done
		[ "$pids" = "$$" ] && break || sleep 1
	done

	echo $$ > /tmp/scheduler_run

	IFS=","
	for testName in $newPathList; do
		#wait for old finish
		status="Requested"
		while [ "$status" = "Requested" ]; do
			status=`cmclient GETV "X_ADB_QoE.${testName}.DiagnosticsState"`
			[ "$status" != "Requested" ] && break;
			sleep 5
		done
		day=$(date +%a)
		sec=$(getActualSecond)
		endtime=$(cmclient GETV Device.X_ADB_QoE.Scheduler.WeeklySchedule.[Day=${day}].EndTime)
		if [ $sec -gt $endtime ]; then
			newExecutionCount=$newExecutionNumber
			break;
		fi
		#check if immediate test is ongoing, if yes wait until finish
		while true; do
			immediate_inactive=$(cmclient GETV Device.IP.Diagnostics.X_ADB_Report.Enable)
			[ "$immediate_inactive" = "true" ] && break
			sleep 1
		done

		cmclient SETE "Device.X_ADB_QoE.Scheduler.TestOngoing" "true"
		cmclient SET "X_ADB_QoE.${testName}.DiagnosticsState" "Requested"
		status="Requested"
		while [ "$status" = "Requested" ]; do
			sleep 5
			status=`cmclient GETV "X_ADB_QoE.${testName}.DiagnosticsState"`
		done
		cmclient SETE "Device.X_ADB_QoE.Scheduler.TestOngoing" "false"
	done

	rm -f /tmp/scheduler_run_pids/$$
	rm -f /tmp/scheduler_run
	unset IFS
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
			exit 0
			;;
		esac
	elif [ "$setCheck" = "1" -a "$newCheck" = "true" ]; then
		qoe_check &
		if [ "$DIAG_TYPE" = "Scheduler" ]; then
			mkdir -p /tmp/scheduler_run_pids
			echo "$!" > /tmp/scheduler_run_pids/$$
		fi
	else
		qoe_stop
		cmclient SETE "$obj.DiagnosticsState" None
	fi
	;;
esac
exit 0
