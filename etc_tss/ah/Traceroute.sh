#!/bin/sh

AH_NAME="Traceroute"

[ "$user" = "${AH_NAME}${obj}" ] && exit 0

# Requirements asks to allow setting DiagnosticsState only equal to Requested.
# Interpretation: if the value is invalid we do not process it at all and exit
# with error). The value None is handled after have stopped the test.
[ "$setDiagnosticsState" = "1" -a \
  "$newDiagnosticsState" != "Requested" -a \
  "$newDiagnosticsState" != "None" ] && exit 1

. /etc/ah/helper_serialize.sh && help_serialize
. /etc/ah/helper_ifname.sh

# Check if another test session is running
if [ -e "/tmp/${AH_NAME}${obj}.pid" ]; then
	read -r pid < "/tmp/${AH_NAME}${obj}.pid"
	kill $pid
	# We need to kill also traceroute, but after the process that reads its
	# return value, otherwise the notification COMPLETE is sent to the ACS.
	killall traceroute
	rm -f "/tmp/${AH_NAME}${obj}.pid"
fi

# Any parameter was changed or DiagosticsState set to 'None'.
if [ "$setDiagnosticsState" = "0" ]; then
	cmclient -u "${AH_NAME}${obj}" DEL "${obj}.RouteHops."
	cmclient -u "${AH_NAME}${obj}" SET "${obj}.DiagnosticsState" None
	exit 0
elif [ "$newDiagnosticsState" != "Requested" ]; then
	exit 0
fi

if [ "$newProtocolVersion" = "IPv6" ]; then
	verOption="-6"
elif [ "$newProtocolVersion" = "IPv4" ]; then
	verOption="-4"
else
	verOption=""
fi
interfaceOption=""
destHost=${newHost}
case "$newHost" in
	*:*)
		verOption="-6"
		if [ -n "$newInterface" ]; then
			case "$newHost" in
				fe80:*)
					help_lowlayer_ifname_get ifname "${newInterface}"
					destHost="${destHost}%${ifname}"
					;;
			esac
		fi
		;;
	*)
		if [ -n "$newInterface" ]; then
			if [ "$newProtocolVersion" = "IPv6" ]; then
				sourceAddrs=$(cmclient GETV "$newInterface.IPv6Address.[Status=Enabled].[IPAddressStatus=Preferred].IPAddress")
				# use the global IPv6 address if possible
				for sourceAddr in $sourceAddrs; do
					case "$sourceAddr" in
						fe80:*)
						;;
						*)
							break;
						;;
					esac
				done
			else
				sourceAddr=$(cmclient GETV "$newInterface.IPv4Address.1.IPAddress")
			fi
			if [ -z "$sourceAddr" ]; then
				cmclient -u "${AH_NAME}${obj}" SET "${obj}.DiagnosticsState" Error_Internal
				cmclient -u "${AH_NAME}${obj}" DEL "${obj}.RouteHops."
				exit 0
			fi
			interfaceOption="-s ${sourceAddr}"
		fi
		;;
esac

[ -n "$newMaxHopCount" ] && maxHopOption="-m ${newMaxHopCount}" || maxHopOption="-m 30"
[ -n "$newNumberOfTries" ] && countOption="-q ${newNumberOfTries}" || countOption="-q 3"
[ -z "$newTimeout" ] && newTimeout=5000
[ $newTimeout -ge 1000 ] && timeoutOption="-w $((newTimeout / 1000))" || timeoutOption="-w 5"
[ -n "$newDSCP" ] && dscpOption="-t $((newDSCP << 2))" || dscpOption=""
(
	cmclient -u "${AH_NAME}${obj}" DEL "${obj}.RouteHops."
	error=1
	set -f
	traceroute $verOption $interfaceOption $countOption $timeoutOption $maxHopOption $dscpOption $destHost 2>&1 | (while read -r row; do
		case $row in
		*"!H"*)
			error=1
			;;
		*"bad address"*)
			error=2
			;;
		*"ms"*)
			error=0
			rtt=""
			for t in $row; do
				case $t in
				"ms") rtt="${rtt:+$rtt,}`expr ${prev#*.} / 500 + ${prev%.*}`" ;;
				"("*) host="$prev"; hostAddress="$t"; t=${t%)}; hostAddress=${t#(} ;;
				esac
				prev="$t"
			done
			idx=$(cmclient ADD "$obj.RouteHops")
			cmclient SETM -u "${AH_NAME}${obj}" "$obj.RouteHops.$idx.Host=$host	$obj.RouteHops.$idx.HostAddress=$hostAddress	$obj.RouteHops.$idx.RTTimes=$rtt	$obj.RouteHops.$idx.ErrorCode=0"
			echo -n "$hostAddress $rtt | " >> $outFile
			;;
		*"unreachable"*)
			error="1"
			;;
		esac
	done
	exit $error
	)

	error=$?
	set +f
	case "$error" in
	0)
		setm="${setm:+$setm	}$obj.DiagnosticsState=Complete"
		;;
	1)
		setm="$obj.ResponseTime=0"
		setm="$setm	$obj.DiagnosticsState=Error_MaxHopCountExceeded"
		;;
	2)
		setm="$obj.ResponseTime=0"
		setm="$setm	$obj.DiagnosticsState=Error_CannotResolveHostName"
		;;
	esac

	cmclient -u "${AH_NAME}${obj}" SETM "$setm"

	rm -f "/tmp/${AH_NAME}${obj}.pid"

) & echo "$!" > "/tmp/${AH_NAME}${obj}.pid"

exit 0
