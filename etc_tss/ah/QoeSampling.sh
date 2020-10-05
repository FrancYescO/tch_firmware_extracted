#!/bin/sh

AH_NAME="QoESampling"
[ "$user" = "${AH_NAME}${obj}" ] && exit 0

AH_PID_FILE=/tmp/${AH_NAME}.pid

. /etc/ah/helper_serialize.sh && help_serialize

stop_sampling_test()
{
	local pid

	if [ -f "$AH_PID_FILE" ]; then
		read -r pid < "$AH_PID_FILE"
		kill -15 $pid
		rm -f "$AH_PID_FILE"
	fi
}

uptime_millis()
{
	local varname=$1
	local sec hsec

	IFS=". " read -r sec hsec _ < /proc/uptime
	hsec=${hsec#0}
	eval "$varname=$((sec*1000+hsec*10))"
}

run_sampling_test()
{
	local obj=$1
	local newPathList newSamplesNumber newSamplesInterval i
	local st ut utsample params param path value pobj pvalue ptime id

	cmclient DEL $obj.Parameter
	if [ -x /etc/ah/helper_qoe.sh ]; then
		. /etc/ah/helper_qoe.sh
		help_qoe_serialize "Error_Timeout" || exit 0
	fi
	st=`date -u +%FT%TZ`
	uptime_millis ut
	cmclient SETE $obj.SampleTime $st
	newPathList=$(cmclient GETV "$obj.PathList")
	newSamplesNumber=$(cmclient GETV "$obj.SamplesNumber")
	newSamplesInterval=$(cmclient GETV "$obj.SamplesInterval")
	if [ ${#newPathList} -eq 0 -o "$newSamplesNumber" -lt 1 -o "$newSamplesInterval" -lt 5 ]; then
		#### test fails
		cmclient SETE $obj.DiagnosticsState Error
		return
	fi
	set -f
	IFS=","
	set -- $newPathList
	unset IFS
	set +f
	i=0
	while [ 1 ]; do
		for x; do
			params=$(cmclient GETD "$x" 0)
			uptime_millis utsample
			utsample=$((utsample-ut))
			for param in $params; do
				path="${param%%;*}"
				value="${param#*;}"
				if [ $i -eq 0 ]; then
					id=$(cmclient ADD "$obj.Parameter")
					cmclient SETEM "${obj}.Parameter.${id}.Path=${path}	${obj}.Parameter.${id}.Value=${value}	${obj}.Parameter.${id}.Timestamp=${utsample}"
				else
					pobj=$(cmclient GETO "${obj}.Parameter.[Path=${path}]")
					if [ ${#pobj} -gt 0 ]; then
						pvalue=$(cmclient GETV "${pobj}.Value")
						ptime=$(cmclient GETV "${pobj}.Timestamp")
						cmclient SETEM "${pobj}.Value=${pvalue},${value}	${pobj}.Timestamp=${ptime},${utsample}"
					fi
				fi
			done
		done
		i=$((i+1))
		[ $i -lt $newSamplesNumber ] && sleep "$newSamplesInterval" || break
	done
	#### test completed
	cmclient SETE $obj.DiagnosticsState Completed
	[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
	rm -f "$AH_PID_FILE"
}

case "$op" in
s)
	stop_sampling_test
	if [ "$setDiagnosticsState" = "1" ]; then
		case "$newDiagnosticsState" in
		Requested)
			run_sampling_test "$obj"&
			echo $! > "$AH_PID_FILE"
			;;
		None)
			;;
		*)
			exit 7
		esac
	else
		cmclient SETE $obj.DiagnosticsState None
	fi
	;;
esac
exit 0
