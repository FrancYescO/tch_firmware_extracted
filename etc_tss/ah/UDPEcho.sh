#!/bin/sh

AH_NAME="UDPEcho"
STATF="/var/udpechostat"

service_config() {
	interfaceOption=""
	if [ -n "$newInterface" ]; then
		. /etc/ah/helper_ifname.sh
		help_lowlayer_ifname_get interfaceOption ${newInterface}
		if [ -z "$interfaceOption" ]; then
			return
		fi
	fi

	if [ "$changedEnable" = "1" ]; then
		killall udpecho 2> /dev/null
		if [ "$newEnable" = "true" ]; then
			# sanity check
			
			if [ -z "$newUDPPort" ]; then
				return
			fi
			
			udpecho "$interfaceOption" "$newUDPPort" "$newSourceIPAddress" "$newEchoPlusEnabled" &
			pid="$!"
			echo "$pid" > "$STATF.pid"
		else
			rm -f "$STATF.pid"
		fi
	fi
}

. /etc/ah/helper_udpecho.sh

##################
### Start here ###
##################
case "$op" in
	g)
		collect "$STATF.pid"

		for arg
		do
			parse_results_server "$STATF" "$arg"
		done
		;;
	s)
		service_config
		;;
esac
exit 0
