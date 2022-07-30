#!/bin/sh

case "$obj" in
*UploadDiagnostics*)
	upload=1
	AH_NAME="UploadDiagnostics"
	diagnosticsDefaultError="Error_NoTransferComplete"
	;;
*DownloadDiagnostics*)
	upload=0
	AH_NAME="DownloadDiagnostics"
	diagnosticsDefaultError="Error_TransferFailed"
	;;
*)
	exit 0;
	;;
esac

# Requirements asks to allow setting DiagnosticsState only equal to Requested.
# Interpretation: if the value is invalid we do not process it at all and exit
# with error). The value None is handled after have stopped the test.
[ "$setDiagnosticsState" = "1" -a \
  "$newDiagnosticsState" != "Requested" -a \
  "$newDiagnosticsState" != "None" ] && exit 0

[ "$user" = "${AH_NAME}${obj}" ] && exit 0

pidFile="/tmp/${AH_NAME}${obj}.pid"

kill_children()
{
	local pid=""
	if [ -e $pidFile ]; then
		while read pid; do
			#pkill -15 -P $pid
			kill -9 $pid
		done <$pidFile
		rm -f $pidFile
	fi
	incResults=$(cmclient GETO "${obj}.IncrementalResults.")
	for i in $incResults; do
		cmclient -u ${AH_NAME}${obj} DEL $i >/dev/null
	done
}

. /etc/ah/helper_firewall.sh
. /etc/ah/helper_serialize.sh && help_serialize > /dev/null
. /etc/ah/helper_functions.sh
. /etc/ah/helper_ifname.sh
if [ -x /etc/ah/helper_qoe.sh ]; then
	. /etc/ah/helper_qoe.sh
fi

#
# Retrive the routing interface basing to the url
# get_route_interface <ret> <url>
#
get_route_interface()
{
	local _host _iface url="$2"

	_host=${url#*://}; _host=${_host#*@}; _host=${_host%%/*}; _host=${_host%%:*}

	_host=$(host "$_host")

	for _host in $_host; do
		case "$_host" in
			*"."*) break ;;
		esac
	done

	_iface=$(ip route get "$_host")
	_iface=${_iface##*dev }; _iface=${_iface%% src*}
	[ ${#_iface} -gt 0 ] && eval $1='$_iface' || eval $1=''
}

kill_children

# Any parameter was changed or DiagosticsState set to 'None' -
# kill previous test and exit
if [ "$setDiagnosticsState" = "0" ]; then
	cmclient -u "${AH_NAME}${obj}" SET "${obj}.DiagnosticsState" "None"
	[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
	exit 0
elif [ "$newDiagnosticsState" != "Requested" ]; then
	exit 0
fi

interfaceOption=""
if [ -n "$newInterface" ]; then
	help_lowlayer_ifname_get interfaceOption ${newInterface}
	if [ -z "$interfaceOption" ]; then
		cmclient -u "${AH_NAME}${obj}" SET "${obj}.DiagnosticsState" \
		         "$diagnosticsDefaultError"
		[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
		exit 0
	else
		interfaceOption="-i ${interfaceOption}"
	fi
fi

[ "$upload" = "0" ] && url="$newDownloadURL" || url="$newUploadURL"

if [ -z "$url" ]; then
	cmclient -u "${AH_NAME}${obj}" SET "${obj}.DiagnosticsState" \
	         "$diagnosticsDefaultError"
	[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
	exit 0
fi

get_route_interface phys_iface "$url"
#route_iface=$(help_obj_from_ifname_get $iface)
#help_lowest_ifname_get phys_iface ${route_iface}
[ -n "$phys_iface" ] && interfaceOption="$interfaceOption -x $phys_iface"

if [ "$upload" = "1" -a "$newTimeBasedTestDuration" -le 0 ]; then
	if [ "$newTestFileLength" -le 0 ]; then
		# upload size cannot be 0 or negative
		cmclient -u "${AH_NAME}${obj}" SET "${obj}.DiagnosticsState" \
		         "$diagnosticsDefaultError"
		[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
		exit 0
	fi
	uploadSize="$newTestFileLength"
else
	uploadSize=0
fi

parse_incremental_result()
{
	local name="$1"
	local val="$2"
	local mode="$3"

	case "$name" in
		"IncBOMTime")
			echo "IncBOMTime=${val}"
			;;
		"IncEOMTime")
			echo "IncEOMTime=${val}"
			;;
		"IncTestBytes")
			if [ "$mode" = "0" ]; then
				echo "IncTestBytesReceived=${val}"
			else
				echo "IncTestBytesSent=${val}"
			fi
			;;
	esac
}

parse_results()
{
	local res="$1" mode="$2"
	local name val ROMTime BOMTime EOMTime
	local TestBytesReceived TestBytesSent TestRate TotalRate
	local TCPOpenRequestTime TCPOpenResponseTime TotalBytesReceived TotalBytesSent LocalIP

	while IFS=";" read -r name val; do
		case "$name" in
			"IncrementalResult")
				idx=$(cmclient ADD -u ${AH_NAME}${obj} "${obj}.IncrementalResults")
				if [ "$idx" -ge 0 ]; then
					IFS=";" read -r name val
					p_inc="${obj}.IncrementalResults.$idx.$(parse_incremental_result $name $val $mode)"
					IFS=";" read -r name val
					p_inc="${p_inc}	${obj}.IncrementalResults.$idx.$(parse_incremental_result $name $val $mode)"
					IFS=";" read -r name val
					p_inc="${p_inc}	${obj}.IncrementalResults.$idx.$(parse_incremental_result $name $val $mode)"

					cmclient SETEM "${p_inc}"
				fi
				;;
			"ROMTime")
				ROMTime="$val"
				;;
			"BOMTime")
				BOMTime="$val"
				;;
			"EOMTime")
				EOMTime="$val"
				;;
			"TestBytesReceived")
				TestBytesReceived="$val"
				;;
			"TestBytesUploaded")
				TestBytesSent="$val"
				;;
			"TCPOpenRequestTime")
				TCPOpenRequestTime="$val"
				;;
			"TCPOpenResponseTime")
				TCPOpenResponseTime="$val"
				;;
			"TotalBytesReceived")
				TotalBytesReceived="$val"
				;;
			"TotalBytesSent")
				TotalBytesSent="$val"
				;;
			"TestRate")
				TestRate="$val"
				;;
			"TotalRate")
				TotalRate="$val"
				;;
			"LocalIP")
				LocalIP="$val"
				;;
		esac
	done <<-EOF
		$res
	EOF

	p="${obj}.ROMTime=${ROMTime}"
	p="${p}	${obj}.BOMTime=${BOMTime}"
	p="${p}	${obj}.EOMTime=${EOMTime}"
	p="${p}	${obj}.TCPOpenRequestTime=${TCPOpenRequestTime}"
	p="${p}	${obj}.TCPOpenResponseTime=${TCPOpenResponseTime}"
	if [ "$mode" = "0" ]; then
		p="${p}	${obj}.TestBytesReceived=${TestBytesReceived}"
		p="${p}	${obj}.TotalBytesReceived=${TotalBytesReceived}"
	else
		p="${p}	${obj}.TestBytesSent=${TestBytesSent}"
		p="${p}	${obj}.TotalBytesSent=${TotalBytesSent}"
	fi
	p="${p}	${obj}.X_ADB_TestRate=${TestRate}"
	p="${p}	${obj}.X_ADB_TotalRate=${TotalRate}"

	cmclient SETEM "${p}"

	cmclient SETE "Device.DeviceInfo.IPAddress" "${LocalIP}"

	cmclient -u "${AH_NAME}${obj}" SET "${obj}.DiagnosticsState" "Completed"
}

parse_error()
{
	local res="$1"
	local mode="$2"

	case "$res" in
		*"CONNECTION FAILED"*)
			state="Error_InitConnectionFailed"
			;;
		*"NO RESPONSE"*)
			state="Error_NoResponse"
			;;
		*"TRANSFER FAILED"*)
			state="Error_TransferFailed"
			[ "$mode" -ne "0" ] && state="Error_NoTransferComplete"
			;;
		*"PASSWORD REQUEST FAILED"*)
			state="Error_PasswordRequestFailed"
			;;
		*"LOGIN FAILED"*)
			state="Error_LoginFailed"
			;;
		*"NO TRANSFER MODE"*)
			state="Error_NoTransferMode"
			;;
		*"NO PASV"*)
			state="Error_NoPASV"
			;;
		*"INCORRECT SIZE"*)
			state="Error_IncorrectSize"
			;;
		*"TIMEDOUT"*)
			state="Error_Timeout"
			;;
		*"UPLOAD COMMAND FAILED"*)
			state="Error_NoSTOR"
			;;
		*"NO CWD"*)
			state="Error_NoCWD"
			;;
		*)
			# TODO: something else failed
			state="$diagnosticsDefaultError"
			;;
	esac
	cmclient -u "${AH_NAME}${obj}" SET "${obj}.DiagnosticsState" "$state"
}


do_test()
{
	local interfaceOption="$1"
	local url="$2"
	local path=${url#*://*/}
	local domain=${url%$path}
	local uploadSize="$3"
	local mode="$4"
	local yaftOpts
	local status

	if [ -x /etc/ah/helper_qoe.sh ]; then
		help_qoe_serialize "Error_Timeout" || exit 0
	fi
	#initialize ROMTime
	cmclient SETE "${obj}.ROMTime" "$(date -u +%FT%T.000000)"
	path=$(help_uri_escape "$path")
	url="${domain}${path}"

	if [ ${newTimeBasedTestDuration:-0} -ge 1 ]; then
		url="${url%%/}"
		durationFilename="$newTimeBasedTestDuration"
		while [ ${#durationFilename} -lt 3 ]; do durationFilename="0"$durationFilename; done
		if [ "$mode" = "0" ]; then
			yaftOpts="-d ${url}/dntimebaseduration_${durationFilename}.txt -D ${newTimeBasedTestDuration}"
		else
			yaftOpts="-u ${url}/uptimebaseduration_${durationFilename}.txt -D ${newTimeBasedTestDuration}"
		fi

		if [ -n "$newTimeBasedTestIncrements" -a "$newTimeBasedTestIncrements" -ge "1" ]; then
			yaftOpts="${yaftOpts} -I ${newTimeBasedTestIncrements}"
		fi
		if [ -n "$newTimeBasedTestIncrementsOffset" -a "$newTimeBasedTestIncrementsOffset" -ge "1" ]; then
			yaftOpts="${yaftOpts} -O ${newTimeBasedTestIncrementsOffset}"
		fi

		if [ "$mode" = "0" ]; then
			yaftOpts="${yaftOpts} -o -"
		fi
	else
		if [ "$mode" = "0" ]; then
			yaftOpts="-d $url -o -"
		else
			yaftOpts="-u $url -n $uploadSize"
		fi
	fi

	[ ${newDSCP:-0} -gt 0 ] && yaftOpts="${yaftOpts} -P ${newDSCP}"
	[ ${newEthernetPriority:-0} -gt 0 ] && yaftOpts="${yaftOpts} -E ${newEthernetPriority}"
	yaftOpts="${yaftOpts} -R 5 -m 5 -Z -B cpu=1"

	res=`yaft -v $yaftOpts $interfaceOption 2>&1`
	status="$?"

	if [ "$status" = "0" ]; then
		parse_results "$res" "$mode"
	else
		parse_error "$res" "$mode"
	fi
	[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
	rm -f $pidFile
}


do_test "$interfaceOption" "$url" "$uploadSize" "$upload"&

echo "$!" >> "$pidFile"

exit 0
