#!/bin/sh

AH_NAME="DNSDiag"

[ "$user" = "${AH_NAME}${obj}" ] && exit 0

[ "$op" != "d" ] && . /etc/ah/helper_serialize.sh && help_serialize > /dev/null
. /etc/ah/helper_functions.sh
. /etc/ah/helper_ifname.sh
if [ -x /etc/ah/helper_qoe.sh ]; then
	. /etc/ah/helper_qoe.sh
fi

# Kill outstanding nslookup
[ -e /tmp/DNSDiagnostics_${obj}.pid ] && for pid in `cat /tmp/DNSDiagnostics_${obj}.pid`; do pkill -9 -P $pid; kill $pid; done; rm -f /tmp/DNSDiagnostics_${obj}.pid

[ "$op" = "d" ] && exit 0

# Clean all previous Result entries
cmclient DEL "$obj.Result."
cmclient SETE "${obj}.SuccessCount" 0

if [ "$setDiagnosticsState" = "0" ] || [ "$newDiagnosticsState" != "Requested" ] ; then
	cmclient SETE "${obj}.DiagnosticsState" None
	[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
	exit 0
fi

if [ -z "$newHostName" ]; then
	cmclient SETE "${obj}.DiagnosticsState" Error_Internal
	[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
	exit 0
fi

if [ -n "$newTimeout" ]; then
	[ "$newTimeout" -lt 1000 ] && timeoutSec="1" || timeoutSec="$((newTimeout / 1000))"
else
	timeoutSec="1"
fi

nsOpt="-t $timeoutSec -s"
yapstimeout="$newTimeout"

if [ -n "$newInterface" ]; then
	help_lowlayer_ifname_get interfaceName ${newInterface}
	if [ -z "$interfaceName" ]; then
		cmclient SETE "${obj}.DiagnosticsState" Error_Internal
		[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
		exit 0
	else
		# Add an entry to yaps-dns in order to fulfill the request
		[ -z "$newTimeout" ] && yapstimeout="10000" || yapstimeout="$newTimeout"

		if [ -z "$newDNSServer" ]; then
			dnso=$(cmclient GETO Device.DNS.Client.Server.*.[Enable=true])
			[ ${#dnso} -gt 0 ] && server=$(cmclient GETV $dnso.DNSServer)

			if [ -z "$dnso" ] || [ -z "$server" ]; then
				cmclient SETE "${obj}.DiagnosticsState" Error_Internal
				[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
				exit 0
			fi
		else
			server="$newDNSServer"
		fi

		echo "0 !.$newHostName $server $yapstimeout lo $interfaceName" > /tmp/dns/Device.DNS.Diagnostics
	fi
fi

[ -z "$newNumberOfRepetitions" ] && newNumberOfRepetitions=1

perform_test() {
	local st dnsServer

	if [ -x /etc/ah/helper_qoe.sh ]; then
		help_qoe_serialize "Error_Internal" || exit 0
	fi
	st=`date -u +%FT%TZ`
	cmclient SETE "${obj}.X_ADB_StartTime" "$st"
	successCount=0
	lookupCount=0
	if [ -n "$newInterface" ]; then
		dnsServer="127.0.0.1"
	else
		dnsServer="$newDNSServer"
	fi

	while [ "$lookupCount" -lt $newNumberOfRepetitions ]; do
		lookupCount="$((lookupCount+1))"
		
		res=`host $nsOpt $newHostName $dnsServer 2>/dev/null`
		status="$?"

		# DNS Not Resolved
		if [ "$status" -eq 2 ]; then
			p="${obj}.DiagnosticsState=Error_DNSServerNotResolved	${obj}.SuccessCount=0"
			cmclient SETEM "${p}"
			rm -f /tmp/DNSDiagnostics_${obj}.pid
			[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
			exit 0
		elif [ "$status" -eq 0 ]; then
			successCount="$((successCount+1))"
			resultStatus="Success"

			stripped_res=`help_tr " " "%" "$res"`
			line_count=0
			addr_count=0
			resTime=1
			hostAddress=""
			answerType="NonAuthoritative"
			for line in $stripped_res; do
				line_count="$((line_count+1))"
				case "$line" in
				"Request"*)
					resTime=${line##*:%}
				;;
				*)
					if [ -z "$hostAddress" ]; then
						hostAddress="$line"
						addr_count="$((addr_count+1))"
					elif [ "$addr_count" -lt 10 ]; then
						hostAddress="$hostAddress,$line"
						addr_count="$((addr_count+1))"
					fi
				;;
				esac
			done
			[ "$resTime" -gt 0 ] || resTime=1
		else
			resultStatus="Error_HostNameNotResolved"
			answerType="None"
			resTime="0"
			hostName=""
			hostAddress=""

			line_count=0
			serverAddress=""
		fi
		resId=$(cmclient ADD "$obj.Result")
		p="${obj}.Result.${resId}.Status"
		[ $yapstimeout -lt $resTime ] && p="$p=Error_Timeout" || p="$p=$resultStatus"
		p="${p}	${obj}.Result.${resId}.AnswerType=$answerType"
		p="${p}	${obj}.Result.${resId}.HostNameReturned=$hostName"
		p="${p}	${obj}.Result.${resId}.IPAddresses=$hostAddress"
		p="${p}	${obj}.Result.${resId}.DNSServerIP=$newDNSServer"
		p="${p}	${obj}.Result.${resId}.ResponseTime=$resTime"
		cmclient SETEM "${p}"
	done
	[ "$successCount" -eq 0 ] && diagState="Error_Other" || diagState="Complete"
	p="${obj}.DiagnosticsState=$diagState	${obj}.SuccessCount=$successCount"

	cmclient SETEM "${p}"
	[ -x /etc/ah/helper_qoe.sh ] && help_qoe_save
	rm -f /tmp/DNSDiagnostics_${obj}.pid

	if [ -n "$newInterface" ]; then
		rm -f /tmp/dns/Device.DNS.Diagnostics
	fi
}

if [ "$newWaitResults" = "true" ]; then
	echo "$$" >> /tmp/DNSDiagnostics_${obj}.pid
	perform_test
else
	perform_test &
	echo "$!" >> /tmp/DNSDiagnostics_${obj}.pid
fi

exit 0
