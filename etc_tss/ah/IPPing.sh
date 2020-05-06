#!/bin/sh

AH_NAME="IPPing"

convmsec() {
	local msec=$1

	if [ ${msec%%.*} != "0" ]; then
		msec=${msec%%.*}${msec##*.}
	else
		msec=${msec##*.}
	fi

	msec=$(((msec + 500)/1000))

	echo "$msec"
}

# Requirements asks to allow setting DiagnosticsState only equal to Requested.
# Interpretation: if the value is invalid we do not process it at all and exit
# with error). The value None is handled after have stopped the test.
[ "$setDiagnosticsState" = "1" -a \
  "$newDiagnosticsState" != "Requested" -a \
  "$newDiagnosticsState" != "None" ] && exit 0

[ "$user" = "${AH_NAME}${obj}" ] && exit 0

. /etc/ah/helper_serialize.sh && help_serialize > /dev/null
. /etc/ah/helper_functions.sh

SET="-u ${AH_NAME}${obj} SET"
SETM="-u ${AH_NAME}${obj} SETM"

[ -e /tmp/IPPing_${obj}.pid ] && for pid in `cat /tmp/IPPing_${obj}.pid`; do pkill -P $pid; kill $pid; done; rm -f /tmp/IPPing_${obj}.pid

# Any parameter was changed or DiagosticsState set to 'None'.
if [ "$setDiagnosticsState" = "0" ]; then
	cmclient ${SET} "${obj}.DiagnosticsState" "None"
	exit 0
elif [ "$newDiagnosticsState" != "Requested" ]; then
	exit 0
fi

interfaceOption=""
interfaceIP=""
if [ -n "$newInterface" ]; then
	. /etc/ah/helper_ifname.sh
	help_lowlayer_ifname_get nm ${newInterface}
	[ -n "$nm" ] && interfaceIP=`ip a s dev "$nm" | grep 'inet .* '"$nm" | grep -o '[0-9\.]*' | cut -d$'\n' -f1`
	interfaceOption="-I $interfaceIP"
	if [ -z "$interfaceOption" ]; then
		cmclient ${SET} "${obj}.DiagnosticsState" Error_Internal
		exit 0
	fi
fi
[ -n "$newHostReference" ] && hosts=`cmclient GETV "$newHostReference"` || hosts="$newHost"
[ -n "$newNumberOfRepetitions" ] && countOption="-c ${newNumberOfRepetitions}" || countOption="-c 1"
[ -n "$newDataBlockSize" ] && sizeOption="-s ${newDataBlockSize}" || sizeOption=""
[ -n "$newDSCP" ] && dscpOption="-t $((newDSCP << 2))" || dscpOption=""
if [ "$newProtocolVersion" = "IPv6" ]; then
	ver="-6"
elif [ "$newProtocolVersion" = "IPv4" ]; then
	ver="-4"
else
	ver=""
fi
(
	st=`date -u +%FT%TZ`
	cmclient SETE "${obj}.X_ADB_StartTime" "$st"
	for host in $hosts; do
		res=$(ping $ver -q $interfaceOption $countOption $sizeOption $dscpOption $host 2>&1)
		status="$?"
		case ${res} in
			*"received"*)
				while IFS=' ' read -r a1 a2 a3 a4 a5; do
					if [ "$a1" = "round-trip" ]; then
						IFS='/' read -r min avg max <<-EOF
							$a4
						EOF
					elif [ "$a2" = "packets" ]; then
					pktsend=$a1 && pktrecv=$a4
					fi
				done <<-EOF
					$res
				EOF
				if [ "$max" != "" ]; then
					min=`convmsec $min`
					avg=`convmsec $avg`
					max=`convmsec $max`
				else
					min=0
					avg=0
					max=0
				fi

				p="${obj}.DiagnosticsState=Complete"
				p="${p}	${obj}.SuccessCount=$pktrecv"
				p="${p}	${obj}.FailureCount=$(($pktsend - $pktrecv))"
				p="${p}	${obj}.MinimumResponseTime=${min}"
				p="${p}	${obj}.AverageResponseTime=${avg}"
				p="${p}	${obj}.MaximumResponseTime=${max}"
				cmclient ${SETM} "${p}"
				rm -f /tmp/IPPing_${obj}.pid
				exit 0
			;;
			*"bad"*)
				state="Error_CannotResolveHostName"
			;;
			*"unreachable"*)
				state="Error_Internal"
			;;

			#Should never happen
			*)
				state="Error_Other"
			;;
		esac
	done
	p="${obj}.DiagnosticsState=${state}	${obj}.SuccessCount=0	${obj}.FailureCount=${newNumberOfRepetitions}"
	p="${p}	${obj}.MinimumResponseTime=0"
	p="${p}	${obj}.AverageResponseTime=0"
	p="${p}	${obj}.MaximumResponseTime=0"
	cmclient ${SETM} "${p}"
	rm -f /tmp/IPPing_${obj}.pid

) & echo "$!" >> /tmp/IPPing_${obj}.pid
exit 0
