#!/bin/sh

AH_NAME="QoeReport"
[ "$user" = "${AH_NAME}" -a $setUpload -ne 1 ] && exit 0

. /etc/ah/helper_ifname.sh

case "$obj" in
Device.X_ADB_QoE.SamplingDiagnostics.Report)
	TIME_OBJ="Report_QoE_Sampling"
	BASE_OBJ="Device.X_ADB_QoE.SamplingDiagnostics"
	DIAG_OBJ="Device.X_ADB_QoE.Sampling"
	FILE_REPORT="/tmp/QoE_sampling_report.xml"
	DIAG_TYPE="Sampling"
	MULTIPLE_REPORT=0
	;;
Device.X_ADB_QoE.DownloadDiagnostics.Report)
	TIME_OBJ="Report_QoE_Download"
	BASE_OBJ="Device.X_ADB_QoE.DownloadDiagnostics"
	DIAG_OBJ="Device.IP.Diagnostics.X_ADB_DownloadDiagnostics"
	FILE_REPORT="/tmp/QoE_download_report.xml"
	DIAG_TYPE="Download"
	MULTIPLE_REPORT=0
	;;
Device.X_ADB_QoE.UploadDiagnostics.Report)
	TIME_OBJ="Report_QoE_Upload"
	BASE_OBJ="Device.X_ADB_QoE.UploadDiagnostics"
	DIAG_OBJ="Device.IP.Diagnostics.X_ADB_UploadDiagnostics"
	FILE_REPORT="/tmp/QoE_upload_report.xml"
	DIAG_TYPE="Upload"
	MULTIPLE_REPORT=0
	;;
Device.X_ADB_QoE.NSLookupDiagnostics.Report)
	TIME_OBJ="Report_QoE_NSLookup"
	BASE_OBJ="Device.X_ADB_QoE.NSLookupDiagnostics"
	DIAG_OBJ="Device.DNS.Diagnostics.X_ADB_NSLookup"
	FILE_REPORT="/tmp/QoE_nslookup_report.xml"
	DIAG_TYPE="NSLookup"
	MULTIPLE_REPORT=0
	;;
Device.X_ADB_QoE.UDPEchoDiagnostics.Report)
	TIME_OBJ="Report_QoE_UDPEcho"
	BASE_OBJ="Device.X_ADB_QoE.UDPEchoDiagnostics"
	DIAG_OBJ="Device.IP.Diagnostics.X_ADB_UDPEchoDiagnostics"
	FILE_REPORT="/tmp/QoE_udpecho_report.xml"
	DIAG_TYPE="UDPEcho"
	MULTIPLE_REPORT=0
	;;
Device.X_ADB_QoE.LANDiagnostics.Report)
	TIME_OBJ="Report_QoE_LAN"
	BASE_OBJ="Device.X_ADB_QoE.LANDiagnostics"
	DIAG_OBJ="Device.IP.Diagnostics.X_ADB_LANDiagnostics"
	FILE_REPORT="/tmp/QoE_lan_report.xml"
	DIAG_TYPE="LAN"
	MULTIPLE_REPORT=0
	;;
Device.X_ADB_QoE.WiFiChannelMeasurementsDiagnostics.Report)
	TIME_OBJ="Report_QoE_WiFiChannelMeasurements"
	BASE_OBJ="Device.X_ADB_QoE.WiFiChannelMeasurementsDiagnostics"
	DIAG_OBJ="Device.WiFi.X_ADB_WiFiChannelMeasurementsDiagnostics"
	FILE_REPORT="/tmp/QoE_WiFiChannelMeasurements_report.xml"
	DIAG_TYPE="WiFiChannelMeasurements"
	MULTIPLE_REPORT=0
	;;
Device.X_ADB_QoE.AssociatedDevicesDiagnostics.Report)
	TIME_OBJ="Report_QoE_AssociatedDevicesDiagnostics"
	BASE_OBJ="Device.X_ADB_QoE.AssociatedDevicesDiagnostics"
	DIAG_OBJ="Device.WiFi.X_ADB_AssociatedDevicesDiagnostics"
	FILE_REPORT="/tmp/QoE_AssociatedDevicesDiagnostics_report.xml"
	DIAG_TYPE="AssociatedDevices"
	MULTIPLE_REPORT=0
	;;
Device.X_ADB_QoE.MPDUDiagnostics.Report)
	TIME_OBJ="Report_QoE_MPDU"
	BASE_OBJ="Device.X_ADB_QoE.MPDUDiagnostics"
	DIAG_OBJ="Device.WiFi.X_ADB_MPDUDiagnostics"
	FILE_REPORT="/tmp/QoE_MPDU_report.xml"
	DIAG_TYPE="MPDU"
	MULTIPLE_REPORT=0
	;;
Device.IP.Diagnostics.X_ADB_Report)
	TIME_OBJ=""
	BASE_OBJ="Device.IP.Diagnostics.IPPing Device.IP.Diagnostics.TraceRoute Device.IP.Diagnostics.DownloadDiagnostics Device.IP.Diagnostics.UploadDiagnostics"
	DIAG_OBJ=""
	FILE_REPORT="/tmp/QoE_ipdiagnostics_report.xml"
	DIAG_TYPE="IPPing TraceRoute Download Upload"
	MULTIPLE_REPORT=1
	;;
*)
	exit 0
esac

print_xml_param()
{
	local obj=$1
	local pname=$2
	local level=$3
	local style=$4
	local param
	local sp

	while [ "$level" -gt 0 ]
	do
		sp="$sp  "
		level=$((level-1))
	done
	param=$(cmclient GETV $obj.$pname)
	param=${param##${obj}.}
	pname=${pname#X_ADB_}
	if [ "$style" = "xml" ]; then
		echo "$sp<$pname>$param</$pname>" >> $FILE_REPORT
	else
		echo "$sp<param name=\"$pname\">$param</param>" >> $FILE_REPORT
	fi
}

print_xml_device_id()
{
	local oui

	echo "  <DeviceId>" >> $FILE_REPORT
	print_xml_param DeviceInfo Manufacturer 2 xml
	oui=$(cmclient GETV DeviceInfo.ManufacturerOUI)
	echo "    <OUI>$oui</OUI>" >> $FILE_REPORT
	print_xml_param DeviceInfo ProductClass 2 xml
	print_xml_param DeviceInfo SerialNumber 2 xml
	echo "  </DeviceId>" >> $FILE_REPORT
}

print_xml_device_info()
{
	echo "  <DeviceInfo>" >> $FILE_REPORT
	print_xml_param DeviceInfo HardwareVersion 2 xml
	print_xml_param DeviceInfo SoftwareVersion 2 xml
	print_xml_param X_ADB_FactoryData BaseMACAddress 2 xml
	print_xml_param DeviceInfo IPAddress 2 xml
	echo "  </DeviceInfo>" >> $FILE_REPORT
}

print_xml_test_info()
{
	local dobj=$1
	local dtype=$2
	local params p userinfo

	userinfo=$(cmclient GETV $obj.UserInfo)

	echo "      <TestInfo>" >> $FILE_REPORT
	echo "        <TestType>$dtype</TestType>" >> $FILE_REPORT
	echo "        <UserInfo>$userinfo</UserInfo>" >> $FILE_REPORT
	[ $MULTIPLE_REPORT -eq 1 ] && params="X_ADB_TestCode" || params="TestCode"
	case "$dobj" in
	*SamplingDiagnostics)
		params="$params SamplesNumber SamplesInterval"
		;;
	*DownloadDiagnostics)
		params="$params DownloadURL Interface TimeBasedTestDuration \
			TimeBasedTestIncrements TimeBasedTestIncrementsOffset \
			DSCP EthernetPriority"
		;;
	*UploadDiagnostics)
		params="$params UploadURL Interface TestFileLength \
			TimeBasedTestDuration TimeBasedTestIncrements \
			TimeBasedTestIncrementsOffset DSCP EthernetPriority"
		;;
	*IPPing)
		params="$params Host Interface NumberOfRepetitions \
			Timeout DataBlockSize ProtocolVersion DSCP"
		;;
	*TraceRoute)
		params="$params Host Interface NumberOfTries \
			Timeout DataBlockSize MaxHopCount DSCP"
		;;
	*NSLookupDiagnostics)
		params="$params Interface HostName DNSServer \
			DNSServer2 Timeout NumberOfRepetitions"
		;;
	*UDPEchoDiagnostics)
		params="$params Interface EchoPlusEnabled Host \
			UDPPort NumberOfRepetitions Timeout \
			DataBlockSize DSCP InterTransmissionTime"
		;;
	*LANDiagnostics)
		params="$params Interface Target ProbingMethod SmallMtu \
			BigMtu Numprobes Interval LowerPercentile \
			AvgPercentile Timeout"
		;;
	*WiFiChannelMeasurementsDiagnostics)
		params="$params Duration Band"
		;;
	*AssociatedDevicesDiagnostics)
		params="$params DeviceList"
		;;
	*MPDUDiagnostics)
		:
		;;
	esac
	for p in $params
	do
		print_xml_param "$dobj" "$p" 4 xml
	done
	echo "      </TestInfo>" >> $FILE_REPORT
}

print_xml_test_item()
{
	local id=$1
	local dobj=$2
	local dtype=$3
	local starttime timestamp results res par

	case "$dobj" in
	*Sampling*)
		starttime=$(cmclient GETV "$dobj.SampleTime")
		;;
	*DownloadDiagnostics*)
		starttime=$(cmclient GETV "$dobj.ROMTime")
		;;
	*UploadDiagnostics*)
		starttime=$(cmclient GETV "$dobj.ROMTime")
		;;
	*NSLookup*)
		local nrepetitions nresults
		starttime=$(cmclient GETV "$dobj.X_ADB_StartTime")
		nrepetitions=$(cmclient GETV "$dobj.NumberOfRepetitions")
		nresults=$(cmclient GETV "$dobj.ResultNumberOfEntries")
		if [ "$nrepetitions" != "$nresults" ]; then
			logger -t qoe -p 4 "$dtype - Report related to ${alias} discarded"
			return
		fi
		;;
	*IPPing*)
		starttime=$(cmclient GETV "$dobj.X_ADB_StartTime")
		;;
	*UDPEchoDiagnostics*)
		starttime=$(cmclient GETV "$dobj.X_ADB_StartTime")
		;;
	*LANDiagnostics*)
		starttime=$(cmclient GETV "$dobj.StartTime")
		;;
	*WiFiChannelMeasurementsDiagnostics*)
		starttime=$(cmclient GETV "$dobj.LastScanTime")
		;;
	*AssociatedDevicesDiagnostics*)
		starttime=$(cmclient GETV "$dobj.LastScanTime")
		;;
	*MPDUDiagnostics*)
		starttime=$(cmclient GETV "$dobj.LastScanTime")
		;;
	esac
	[ ${#starttime} -ne 0 ] && timestamp=`date -D "%FT%T" -d $starttime -Iseconds`
	echo "    <TestItem>" >> $FILE_REPORT
	[ $MULTIPLE_REPORT -eq 1 ] && par="$dobj" || par="$BASE_OBJ"
	print_xml_test_info "$par" "$dtype"
	echo "      <ItemInfo>" >> $FILE_REPORT
	echo "        <ID>$id</ID>" >> $FILE_REPORT
	echo "        <Timestamp>$timestamp</Timestamp>" >> $FILE_REPORT
	print_xml_param "$dobj" DiagnosticsState 4 xml
	echo "      </ItemInfo>" >> $FILE_REPORT
	echo "      <ItemData>" >> $FILE_REPORT
	echo "        <ParamList>" >> $FILE_REPORT
	case "$dobj" in
	*Sampling*)
		local params param path value times

		params=$(cmclient GETO "$dobj.Parameter")
		for param in $params
		do
			path=$(cmclient GETV "$param.Path")
			value=$(cmclient GETV "$param.Value")
			times=$(cmclient GETV "$param.Timestamp")
			echo "          <param name=\"$path\">" >> $FILE_REPORT
			echo "            <value>$value</value>" >> $FILE_REPORT
			echo "            <timestamp>$times</timestamp>" >> $FILE_REPORT
			echo "          </param>" >> $FILE_REPORT
		done
		;;
	*IPPing*)
		print_xml_param "$dobj" SuccessCount 5
		print_xml_param "$dobj" FailureCount 5
		print_xml_param "$dobj" AverageResponseTime 5
		print_xml_param "$dobj" MinimumResponseTime 5
		print_xml_param "$dobj" MaximumResponseTime 5
		;;
	*DownloadDiagnostics*)
		print_xml_param "$dobj" ROMTime 5
		print_xml_param "$dobj" BOMTime 5
		print_xml_param "$dobj" EOMTime 5
		print_xml_param "$dobj" TCPOpenRequestTime 5
		print_xml_param "$dobj" TCPOpenResponseTime 5
		print_xml_param "$dobj" TestBytesReceived 5
		print_xml_param "$dobj" TotalBytesReceived 5
		print_xml_param "$dobj" X_ADB_TestRate 5
		print_xml_param "$dobj" X_ADB_TotalRate 5
		results=$(cmclient GETO "$dobj.IncrementalResults")
		for res in $results
		do
			res=${res##${dobj}.}
			print_xml_param "$dobj" "$res.IncTestBytesReceived" 5
			print_xml_param "$dobj" "$res.IncBOMTime" 5
			print_xml_param "$dobj" "$res.IncEOMTime" 5
		done
		;;
	*UploadDiagnostics*)
		print_xml_param "$dobj" ROMTime 5
		print_xml_param "$dobj" BOMTime 5
		print_xml_param "$dobj" EOMTime 5
		print_xml_param "$dobj" TCPOpenRequestTime 5
		print_xml_param "$dobj" TCPOpenResponseTime 5
		print_xml_param "$dobj" TestBytesSent 5
		print_xml_param "$dobj" TotalBytesSent 5
		print_xml_param "$dobj" X_ADB_TestRate 5
		print_xml_param "$dobj" X_ADB_TotalRate 5
		results=$(cmclient GETO "$dobj.IncrementalResults")
		for res in $results
		do
			res=${res##${dobj}.}
			print_xml_param "$dobj" "$res.IncTestBytesSent" 5
			print_xml_param "$dobj" "$res.IncBOMTime" 5
			print_xml_param "$dobj" "$res.IncEOMTime" 5
		done
		;;
	*NSLookup*)
		print_xml_param "$dobj" SuccessCount 5
		results=$(cmclient GETO "$dobj.Result")
		for res in $results
		do
			res=${res##${dobj}.}
			print_xml_param "$dobj" "$res.Status" 5
			print_xml_param "$dobj" "$res.AnswerType" 5
			print_xml_param "$dobj" "$res.HostNameReturned" 5
			print_xml_param "$dobj" "$res.IPAddresses" 5
			print_xml_param "$dobj" "$res.DNSServerIP" 5
			print_xml_param "$dobj" "$res.ResponseTime" 5
		done
		;;
	*UDPEchoDiagnostics*)
		print_xml_param "$dobj" SuccessCount 5
		print_xml_param "$dobj" FailureCount 5
		print_xml_param "$dobj" AverageResponseTime 5
		print_xml_param "$dobj" MaximumResponseTime 5
		print_xml_param "$dobj" MinimumResponseTime 5
		results=$(cmclient GETO "$dobj.IndividualPacketResult")
		for res in $results
		do
			res=${res##${dobj}.}
			print_xml_param "$dobj" "$res.PacketSuccess" 5
			print_xml_param "$dobj" "$res.PacketSendTime" 5
			print_xml_param "$dobj" "$res.PacketRcvTime" 5
			print_xml_param "$dobj" "$res.TestGenSN" 5
			print_xml_param "$dobj" "$res.TestRespSN" 5
			print_xml_param "$dobj" "$res.TestRespRcvTimeStamp" 5
			print_xml_param "$dobj" "$res.TestRespReplyTimeStamp" 5
			print_xml_param "$dobj" "$res.TestRespReplyFailureCount" 5
		done
		;;
	*LANDiagnostics*)
		print_xml_param "$dobj" Result.Timestamp 5
		print_xml_param "$dobj" Result.Capacity 5
		print_xml_param "$dobj" Result.AvailableBandwidth 5
		print_xml_param "$dobj" Result.SmallMtuRtts 5
		print_xml_param "$dobj" Result.BigMtuRtts 5
		;;
	*WiFiChannelMeasurementsDiagnostics*)
		print_xml_param "$dobj" OperatingChannel 5
		channels=$(cmclient GETO "$dobj.Channel")
		for chan in $channels
		do
			chan=${chan##${dobj}.}
			print_xml_param "$dobj" "$chan.Channel" 5
			print_xml_param "$dobj" "$chan.ChannelLoad" 5
			print_xml_param "$dobj" "$chan.NoisePower" 5
			print_xml_param "$dobj" "$chan.TxDuration" 5
			print_xml_param "$dobj" "$chan.InBSSRxDuration" 5
			print_xml_param "$dobj" "$chan.OtherBSSRxDuration" 5
			print_xml_param "$dobj" "$chan.BadRxFCSDuration" 5
			print_xml_param "$dobj" "$chan.BadRxPacketDuration" 5
			print_xml_param "$dobj" "$chan.SleepDuration" 5
			print_xml_param "$dobj" "$chan.TxOpportunities" 5
			print_xml_param "$dobj" "$chan.GoodTxDuration" 5
			print_xml_param "$dobj" "$chan.BadTxDuration" 5
			print_xml_param "$dobj" "$chan.CRSGlitchCount" 5
			print_xml_param "$dobj" "$chan.BadPLCPCount" 5
			print_xml_param "$dobj" "$chan.IdleChannelTime" 5
			print_xml_param "$dobj" "$chan.CompositeNoiseScore" 5
		done
		;;
	*AssociatedDevicesDiagnostics*)
		assoc_dev=$(cmclient GETO "$dobj.AssociatedDevice")
		for adev in $assoc_dev
		do
			adev=${adev##${dobj}.}
			print_xml_param "$dobj" "$adev.MACAddress" 5
			print_xml_param "$dobj" "$adev.SSID" 5
			print_xml_param "$dobj" "$adev.AssociationTime" 5
			print_xml_param "$dobj" "$adev.Protocol" 5
			print_xml_param "$dobj" "$adev.LastDataDownlinkRate" 5
			print_xml_param "$dobj" "$adev.LastDataUplinkRate" 5
			print_xml_param "$dobj" "$adev.RSSI" 5
			print_xml_param "$dobj" "$adev.SignalQuality" 5
			print_xml_param "$dobj" "$adev.Throughput" 5
			print_xml_param "$dobj" "$adev.BytesSent" 5
			print_xml_param "$dobj" "$adev.BytesReceived" 5
			print_xml_param "$dobj" "$adev.PacketsSent" 5
			print_xml_param "$dobj" "$adev.PacketsReceived" 5
			print_xml_param "$dobj" "$adev.PacketRequested" 5
			print_xml_param "$dobj" "$adev.PacketStored" 5
			print_xml_param "$dobj" "$adev.PackedDropped" 5
			print_xml_param "$dobj" "$adev.PacketRetried" 5
			print_xml_param "$dobj" "$adev.QueueUtilization" 5
			print_xml_param "$dobj" "$adev.RTSFail" 5
			print_xml_param "$dobj" "$adev.RetryDrop" 5
			print_xml_param "$dobj" "$adev.PSRetries" 5
			print_xml_param "$dobj" "$adev.PacketAcked" 5
		done
		;;
	*MPDUDiagnostics*)
		samples=$(cmclient GETO "$dobj.Sample")
		for samp in $samples
		do
			samp=${samp##${dobj}.}
			print_xml_param "$dobj" "$samp.MCS" 5
			print_xml_param "$dobj" "$samp.TXMCS" 5
			print_xml_param "$dobj" "$samp.TXMCSPercent" 5
			print_xml_param "$dobj" "$samp.TXMCSSGI" 5
			print_xml_param "$dobj" "$samp.TXMCSSGIPercent" 5
			print_xml_param "$dobj" "$samp.RXMCS" 5
			print_xml_param "$dobj" "$samp.RXMCSSGI" 5
			print_xml_param "$dobj" "$samp.RXMCSSGIPercent" 5
			print_xml_param "$dobj" "$samp.TXVHT" 5
			print_xml_param "$dobj" "$samp.TXVHTPER" 5
			print_xml_param "$dobj" "$samp.TXVHTPercent" 5
			print_xml_param "$dobj" "$samp.TXVHTSGI" 5
			print_xml_param "$dobj" "$samp.TXVHTSGIPER" 5
			print_xml_param "$dobj" "$samp.TXVHTSGIPercent" 5
			print_xml_param "$dobj" "$samp.RXVHT" 5
			print_xml_param "$dobj" "$samp.RXVHTPER" 5
			print_xml_param "$dobj" "$samp.RXVHTPercent" 5
			print_xml_param "$dobj" "$samp.RXVHTSGI" 5
			print_xml_param "$dobj" "$samp.RXVHTSGIPER" 5
			print_xml_param "$dobj" "$samp.RXVHTSGIPercent" 5
			print_xml_param "$dobj" "$samp.MPDUDens" 5
			print_xml_param "$dobj" "$samp.MPDUDensPercent" 5
		done
		;;
	esac
	echo "        </ParamList>" >> $FILE_REPORT
	echo "      </ItemData>" >> $FILE_REPORT
	echo "    </TestItem>" >> $FILE_REPORT
}

create_xml_file()
{
	local alias id par count=0
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $FILE_REPORT
	echo "<Qoe protocol=\"qoe\" version=\"1.0\" type=\"data\">" >> $FILE_REPORT
	print_xml_device_id
	print_xml_device_info
	echo "  <TestItems>" >> $FILE_REPORT
	set -- $_dtype

	for dobj in $_dobjs
	do
		if [ $MULTIPLE_REPORT -eq 1 ]; then
			count=$((count+1))
			par=$(eval echo \${$count})
			print_xml_test_item $count $dobj $par
		else
			alias=$(cmclient GETV "$dobj.Alias")
			id="${alias#*_}"
			if [ "${alias%%_$id}" = "QoeTest" ]; then
				print_xml_test_item $id $dobj $DIAG_TYPE
			fi
		fi
	done
	echo "  </TestItems>" >> $FILE_REPORT
	echo "</Qoe>" >> $FILE_REPORT
}

qoe_report_stop()
{
	cmclient SET "X_ADB_Time.Event.[Alias=$TIME_OBJ].Enable" "false"
	#remove report file
	rm -f $FILE_REPORT
	logger -t qoe -p 4 "$DIAG_TYPE - Report stopped"
}

qoe_report_start()
{
	local eventObj id set_p deadLine

	eventObj=$(cmclient GETO "X_ADB_Time.Event.[Alias=$TIME_OBJ]")
	if [ ${#eventObj} -eq 0 ]; then
		id=$(cmclient ADD X_ADB_Time.Event)
		eventObj="X_ADB_Time.Event.$id"
		set_p="$eventObj.Alias=$TIME_OBJ"
		aid=$(cmclient ADD "$eventObj.Action")
		set_p="$set_p	$eventObj.Action.$aid.Path=$obj.Upload"
		set_p="$set_p	$eventObj.Action.$aid.Value=true"
		cmclient SETEM "$set_p"
	fi
	set_p="$eventObj.Type=Periodic"
	deadLine=$((newUploadInterval*3600))
	set_p="$set_p	$eventObj.DeadLine=$deadLine"
	set_p="$set_p	$eventObj.Enable=true"
	cmclient SETM "$set_p"
	logger -t qoe -p 4 "$DIAG_TYPE - Report started, upload every ${newUploadInterval}h"
}

qoe_report_upload()
{
	local url
	local username password access res

	#prepare upload URL
	url=$(cmclient GETV $obj.UploadURL)

	#prepare auth option
	username=$(cmclient GETV $obj.Username)
	password=$(cmclient GETV $obj.Password)
	if [ ${#username} -ne 0 ] && [ ${#password} -ne 0 ]; then
		access="$username:$password"
	fi

	interfaceOption=""
	if [ -n "$newInterface" ]; then
		help_lowlayer_ifname_get interfaceOption ${newInterface}
		if [ -n "$interfaceOption" ]; then
			interfaceOption="-i ${interfaceOption}"
		fi
	fi

	#run yaft tool
	logger -t qoe -p 6 "$DIAG_TYPE - Uploading to $url"
	yaft -u "$url" -f "$FILE_REPORT" -L "$access" -v -C $interfaceOption
	res=$?

	return $res
}

qoe_tests_execute()
{
	local test diagState
	IFS=","
	for test in $newTestList; do
		logger -t testagent -p 6 "execute test $test"
		cmclient SET "Device.IP.Diagnostics.${test}.DiagnosticsState" "Requested"
		diagState="Requested"
		while [ $diagState = "Requested" ]; do
			sleep 1
			diagState=`cmclient GETV "Device.IP.Diagnostics.${test}.DiagnosticsState"`
		done
	done
	cmclient SET "Device.IP.Diagnostics.X_ADB_Report.Enable" "true"
	cmclient SET "Device.IP.Diagnostics.X_ADB_Report.Upload" "true"
	unset IFS
}

qoe_report_send()
{
	local state count par

	#check whether the report file already exists
	[ -f $FILE_REPORT ] && return
	> $FILE_REPORT

	logger -t qoe -p 6 "$DIAG_TYPE - Checking for available test results..."

	#fetch diagnostics test instances
	if [ $MULTIPLE_REPORT -eq 1 ]; then
		_dobjs=""
		_dtype=""
		count=0
		set -- $DIAG_TYPE
		for dobj in $BASE_OBJ
		do
			count=$((count+1))
			state=$(cmclient GETV "$dobj.DiagnosticsState")
			if [ "$state" = "Requested" ]; then
				rm -f $FILE_REPORT
				logger -t qoe -p 6 "$DIAG_TYPE - No results to send yet, exit"
				return
			elif [ "$state" != "None" ]; then
				par=$(eval echo \${$count})
				_dobjs="$_dobjs $dobj"
				_dtype="$_dtype $par"
			fi
		done
		if [ ${#_dobjs} -eq 0 ]; then
			rm -f $FILE_REPORT
			logger -t qoe -p 6 "$DIAG_TYPE - No results to send, exit"
			return
		fi
	else
		_dobjs=$(cmclient GETO "$DIAG_OBJ.[Alias>QoeTest_].[DiagnosticsState!Requested].[DiagnosticsState!None]")
		if [ -z "$_dobjs" ]; then
			#nothing to send
			rm -f $FILE_REPORT
			logger -t qoe -p 6 "$DIAG_TYPE - No results to send, exit"
			return
		fi
	fi

	#build XML report file
	logger -t qoe -p 6 "$DIAG_TYPE - Building XML report file..."
	create_xml_file

	#upload the report file
	local retry_number retry_interval attempts timestamp res

	retry_number=$(cmclient GETV $obj.RetryNumber)
	retry_interval=$(cmclient GETV $obj.RetryInterval)
	[ "$retry_number" -ge 0 ] || retry_number=0
	[ "$retry_interval" -ge 1 ] || retry_interval=1
	attempts=0
	while [ 1 ]
	do
		qoe_report_upload
		res=$?
		timestamp=`date -u +%FT%TZ`
		if [ "$res" = "0" ]; then
			#upload successful
			cmclient SETE $obj.LastUploadStatus Completed
			cmclient SETE $obj.LastUploadTime $timestamp
			logger -t qoe -p 6 "$DIAG_TYPE - Report uploaded successfully"
			break;
		else
			#upload failed
			cmclient SETE $obj.LastUploadStatus Error
			cmclient SETE $obj.LastUploadErrorTime $timestamp
			logger -t qoe -p 4 "$DIAG_TYPE - Attempt failed"
		fi
		attempts=$((attempts+1))
		if [ "$attempts" -ge "$retry_number" ]; then
			logger -t qoe -p 3 "$DIAG_TYPE - Upload aborted"
			break
		else
			logger -t qoe -p 6 "$DIAG_TYPE - Retry upload in ${retry_interval}sec..."
			sleep $retry_interval
		fi
	done

	#if uploaded, cleanup diagnostics test instances
	if [ "$res" = 0 ]; then
		if [ $MULTIPLE_REPORT -eq 1 ]; then
			for dobj in $_dobjs
			do
				cmclient SET "$dobj.DiagnosticsState" "None"
			done
			logger -t qoe -p 6 "$DIAG_TYPE - test results uploaded, now resetted"
		else
			count=0
			for dobj in $_dobjs
			do
				cmclient DEL $dobj
				count=$((count+1))
			done
			logger -t qoe -p 6 "$DIAG_TYPE - ${count} test results uploaded, now deleted"
		fi
	fi
	cmclient SET Device.IP.Diagnostics.X_ADB_Report.Upload false
	#save diagnostics status
	cmclient SAVE

	#remove report file
	rm -f $FILE_REPORT
}

##################
### Start here ###
##################

case "$op" in
s)
	if [ ${#TIME_OBJ} -gt 0 -a \( "$setEnable" = "1" -o "$changedUploadInterval" = "1" \) ]; then
		qoe_report_stop
		if [ "$newEnable" = "true" ]; then
			qoe_report_start
		fi
	fi
	if [ "$setUpload" = "1" -a "$newUpload" = "true" -a "$newEnable" = "true" ]; then
		qoe_report_send &
	fi
	if [ "$setTestList" = "1" ]; then
		qoe_tests_execute &
	fi
	;;
esac
exit 0
