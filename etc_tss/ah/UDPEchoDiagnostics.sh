#!/bin/sh
AH_NAME="UDPEchoDiagnostics"
RESULTS_OBJ="${obj}.IndividualPacketResult"
pidFile="/tmp/${AH_NAME}${obj}.pid"
STATF="/var/udpechostat${obj}"

kill_children()
{
	[ -e $pidFile ] && for pid in `cat $pidFile`; do pkill -15 -P $pid; kill $pid; done; rm -f $pidFile
}

stop_children()
{
	[ -e $pidFile ] && for pid in `cat $pidFile`; do pkill -SIGUSR1 -P $pid; done;
	sleep 1
}

kill_results()
{
	local p

	cmclient -u ${AH_NAME}${obj} DEL ${RESULTS_OBJ}.
	p="${obj}.FailureCount=0"
	p="${p}	${obj}.SuccessCount=0"
	p="${p}	${obj}.AverageResponseTime=0"
	p="${p}	${obj}.MaximumResponseTime=0"
	p="${p}	${obj}.MinimumResponseTime=0"

	cmclient SETEM "${p}"
	[ -e "$STATF" ] && rm -f $STATF
}

parse_results_client()
{
	local name val idx p p_inc
	local SuccessCount=0
	local FailureCount=0
	local TestGenSN=0
	local MinimumResponseTime MaximumResponseTime AverageResponseTime

	while IFS=";" read -r name val; do
		case "$name" in
			"TestGenSN")
				TestGenSN=$val
				if [ "$newX_ADB_IndividualPacketResults" != "false" ]; then
					idx=$(cmclient ADD -u ${AH_NAME}${obj} ${RESULTS_OBJ})
					IFS=";" read -r name val
					pktSuccess="$val"
					if [ "$pktSuccess" = "false" -o "$newEchoPlusEnabled" = "false" -o "$newDataBlockSize" -le 19 ]; then
						p_inc="${RESULTS_OBJ}.${idx}.TestGenSN=${TestGenSN}"
						p_inc="${p_inc}	${RESULTS_OBJ}.${idx}.${name}=${val}"
						IFS=";" read -r name val
						p_inc="${p_inc}	${RESULTS_OBJ}.${idx}.${name}=${val}"

						if [ "$pktSuccess" = "true" ]; then
							if [ "$newDataBlockSize" -le 19 -o "$newEchoPlusEnabled" = "false" ]; then
								IFS=";" read -r name val
								p_inc="${p_inc}	${RESULTS_OBJ}.${idx}.${name}=${val}"
							fi
						fi
					else
						p_inc="${RESULTS_OBJ}.${idx}.TestGenSN=${TestGenSN}"
						p_inc="${p_inc}	${RESULTS_OBJ}.${idx}.${name}=${val}"
						IFS=";" read -r name val
						p_inc="${p_inc}	${RESULTS_OBJ}.${idx}.${name}=${val}"
						IFS=";" read -r name val
						p_inc="${p_inc}	${RESULTS_OBJ}.${idx}.${name}=${val}"
						IFS=";" read -r name val
						p_inc="${p_inc}	${RESULTS_OBJ}.${idx}.${name}=${val}"
						IFS=";" read -r name val
						p_inc="${p_inc}	${RESULTS_OBJ}.${idx}.${name}=${val}"
						IFS=";" read -r name val
						p_inc="${p_inc}	${RESULTS_OBJ}.${idx}.${name}=${val}"
						IFS=";" read -r name val
						p_inc="${p_inc}	${RESULTS_OBJ}.${idx}.${name}=${val}"
					fi
					cmclient SETEM "${p_inc}"
				fi
				;;
			"FailureCount")
				FailureCount="$val"
				;;
			"SuccessCount")
				SuccessCount="$val"
				;;
			"AverageResponseTime")
				AverageResponseTime="$val"
				;;
			"MaximumResponseTime")
				MaximumResponseTime="$val"
				;;
			"MinimumResponseTime")
				MinimumResponseTime="$val"
				;;
		esac
	done < "$1"

	p="${obj}.FailureCount=${FailureCount}"
	p="${p}	${obj}.SuccessCount=${SuccessCount}"
	p="${p}	${obj}.AverageResponseTime=${AverageResponseTime}"
	p="${p}	${obj}.MaximumResponseTime=${MaximumResponseTime}"
	p="${p}	${obj}.MinimumResponseTime=${MinimumResponseTime}"
	p="${p}	${obj}.DiagnosticsState=Completed"

	cmclient SETEM "${p}"
}

parse_error()
{
	read res<"$1"
	case "$res" in
		*"Error_Internal"*)
			state="Error_Internal"
			;;
		*"Error_Other"*)
			state="Error_Other"
			;;
		*"Error_Cannot_Resolve_Host_Name"*)
			state="Error_Cannot_Resolve_Host_Name"
			;;
		*)
			state="Error_Other"
			;;
	esac
	cmclient SETE "${obj}.DiagnosticsState" "$state"
}

[ "$user" = "${AH_NAME}${obj}" ] && exit 0

# Per-object serialization.
. /etc/ah/helper_serialize.sh && help_serialize > /dev/null

. /etc/ah/helper_functions.sh
. /etc/ah/helper_udpecho.sh
if [ -x /etc/ah/helper_qoe.sh ]; then
	. /etc/ah/helper_qoe.sh
fi

#Stop tests if requested
if [ "$setDiagnosticsState" = "1" -a "$newDiagnosticsState" = "Completed" ]; then
	stop_children
	kill_children
	exit 0
fi

# Any parameter was changed or DiagosticsState set to 'None' -
# kill previous test and exit
if [ "$setDiagnosticsState" = "0" -o "$newDiagnosticsState" != "Requested" ]; then
	cmclient SETE "${obj}.DiagnosticsState" None
	kill_children
	[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
	exit 0
fi

kill_children
kill_results

interfaceOption=""
if [ -n "$newInterface" ]; then
	. /etc/ah/helper_ifname.sh
	help_lowlayer_ifname_get interfaceOption ${newInterface}
	if [ -z "$interfaceOption" ]; then
		cmclient SETE "${obj}.DiagnosticsState" Error_Other
		[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
		exit 0
	fi
fi

if [ -z "$newHost" ] || [ -z "$newInterTransmissionTime" ] || [ -z "$newNumberOfRepetitions" ] || [ -z "$newTimeout" ] || [ -z "$newDataBlockSize" ] || [ -z "$newDSCP" ]; then
	cmclient SETE "${obj}.DiagnosticsState Error_Other"
	[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
	exit 0
fi
if [ -z "$newX_ADB_UDPPort" ] || [ -z "$newEchoPlusEnabled" ]; then
	cmclient SETE "${obj}.DiagnosticsState Error_Other"
	[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
	exit 0
fi

do_test()
{
	local interfaceOption="$1"
	local status

	if [ -x /etc/ah/helper_qoe.sh ]; then
		help_qoe_serialize "Error_Internal" || exit 0
	fi

	iptables -t mangle -F LocalQoE
	[ $newX_ADB_TrafficClass -gt 0 ] && iptables -t mangle -A LocalQoE \
		-m mark \
		--mark "$(($newX_ADB_TrafficClass*16777216))"/0xff000000 \
		-j ACCEPT

	st=`date -u +%FT%TZ`
	cmclient SETE "${obj}.X_ADB_StartTime" "$st"
	udpechoclient "$interfaceOption" "$newX_ADB_UDPPort" "$newHost" "$newNumberOfRepetitions" "$newInterTransmissionTime" "$newTimeout" "$newDataBlockSize" "$newDSCP" "$newEchoPlusEnabled" "$newX_ADB_TrafficClass" 2>"$STATF" 1>"$STATF"
	status="$?"
	if [ $status -eq 0 ]; then
		parse_results_client "$STATF"
	# If not killed by SIGKILL, parse error result
	elif [ $status -ne 137 ]; then
		parse_error "$STATF"
	fi
	[ -e "$STATF" ] && rm -f $STATF
	[ -e "$pidFile" ] && rm -f $pidFile
	[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
}

do_test "$interfaceOption"&
echo "$!" > "$pidFile"
exit 0
