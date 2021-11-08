#!/bin/sh

# It may be not sensible to have this as a separate handler. But have a look at
# DHCPv4Client.sh and friends and you'll understand. TODO: merge this with a
# proper handler once we clean away the mess.

AH_NAME="DNSUpdate"

[ "$user" = "${AH_NAME}" ] && exit 0

. /etc/ah/helper_functions.sh
# Per-parameter serialization.
. /etc/ah/helper_serialize.sh && help_serialize ${AH_NAME} > /dev/null

dns_update() {
	local IPIf="$1"
	local type="$2"
	local dns_servers="$3"
	local confType subObj dynObj rule r o setm_params
	local inIf="" timeout="" domain="" domain_strict="" prioBase="" prioDomain="" 


for confType in Client Relay; do
	if [ "$confType" = "Client" ]; then
		subObj="Device.DNS.Client.Server"
		dynObj="Device.DNS.Client.X_ADB_DynamicServerRule"
	else
		subObj="Device.DNS.Relay.Forwarding"
		dynObj="Device.DNS.Relay.X_ADB_DynamicForwardingRule"
	fi

	cmclient DEL $subObj.[DNSServer=]

	cmclient DEL $subObj.[Interface="${IPIf}"].[Type="${type}"]
	[ -z "$dns_servers" ] && continue

	rule=$(cmclient GETO "$dynObj.[Interface=${IPIf}].[Type=${type}].[Enable=true]")
	[ -z "$rule" ] && rule=$(cmclient GETO "$dynObj.[Interface=${IPIf}].[Type=Any].[Enable=true]")
	[ -z "$rule" ] && rule=$(cmclient GETO "$dynObj.[Interface=].[Type=${type}].[Enable=true]")
	[ -z "$rule" ] && rule=$(cmclient GETO "$dynObj.[Interface=].[Type=Any].[Enable=true]")
	[ -z "$rule" ] && rule="_"
	for r in $rule; do
		if [ "$r" != "_" ]; then
			dontcreate=$(cmclient GETV "${r}.X_ADB_DontCreate")
			if [ "$dontcreate" = "true" ]; then
				continue
			fi
			inIf=$(cmclient GETV "${r}.X_ADB_InboundInterface")
			timeout=$(cmclient GETV "${r}.X_ADB_Timeout")
			domain=$(cmclient GETV "${r}.X_ADB_DomainFiltering")
			domain_strict=$(cmclient  GETV "${r}.X_ADB_DomainFilteringRestricted")
			prioBase=$(cmclient GETV ${r}.X_ADB_PrioBase)
			prioDomain=$(cmclient GETV ${r}.X_ADB_PrioDomain)
		else
			inIf=""; timeout=""; domain=""; domain_strict=""; prioBase=""; prioDomain=""
		fi

		set -f; IFS=","; set -- $dns_servers; unset IFS; set +f
		for arg; do
			o=$(cmclient ADDS "${subObj}")
			o="${subObj}.${o}"
			setm_params="${o}.Enable=true"

			setm_params="$setm_params	${o}.DNSServer=${arg}"
			setm_params="$setm_params	${o}.Type=${type}"
			setm_params="$setm_params	${o}.Interface=${IPIf}"

			[ -n "$inIf" ] && 		setm_params="$setm_params	${o}.X_ADB_InboundInterface=${inIf}"
			[ -n "$timeout" ] && 		setm_params="$setm_params	${o}.X_ADB_Timeout=${timeout}"
			[ -n "$domain" ] && 		setm_params="$setm_params	${o}.X_ADB_DomainFiltering=${domain}"
			[ -n "$domain_strict" ] &&	setm_params="$setm_params	${o}.X_ADB_DomainFilteringRestricted=${domain_strict}"

			case "$arg" in
			*:*)	[ -n "$prioBase" ] && setm_params="$setm_params	$o.X_ADB_PrioBase=$prioBase" ;;
			*)	setm_params="$setm_params	$o.X_ADB_PrioBase=$((prioBase + 1))" ;;
			esac

			[ -n "$prioDomain" ] &&		setm_params="$setm_params	${o}.X_ADB_PrioDomain=${prioDomain}"

			cmclient SETM "$setm_params" > /dev/null
		done
        objMon=$(cmclient GETO "Device.X_ADB_InterfaceMonitor.[Enable=true].Group.[Enable=true].Interface.[AdminStatus=Operational].[DetectionMode=DNS].[MonitoredInterface=${IPIf}]")
        [ ${#objMon} -ne 0 ] && cmclient SET "$objMon.DNSRestart" "true"
	done


done
}

case "$op" in
	s)
		dnsIP=""
		dnsType=""
		dnsServers=""
		
		case "$obj" in
		*"PPP.Interface"*)
			ppp_obj="${obj%%.IPCP*}"
			dnsIP=$(cmclient GETO "Device.IP.Interface.[X_ADB_ActiveLowerLayer=$ppp_obj]")
			dnsType="IPCP"
			dnsServers="$newDNSServers"
		;;
		*"X_ADB_VPN.Client.L2TP"*)
			dnsIP=$(cmclient GETO "Device.IP.Interface.[LowerLayers=$obj]")
			dnsType="IPCP"
			dnsServers="$newDNSServers"
		;;
		*"DHCPv4.Client"*)
			dnsIP=$(cmclient GETV "$obj.Interface")
			dnsType="DHCPv4"
			dnsServers="$newDNSServers"
		;;
		*"IP.Interface"*)
			# X_ADB_DNSOverrideAllowed parameter
			if [ "$changedX_ADB_DNSOverrideAllowed" -eq 0 ]; then
				exit 0
			fi
			dnsIP="$obj"
			llayer=$(cmclient GETV "$obj.LowerLayers")
			case "$llayer" in
			*"PPP.Interface"*)
				dnsType="IPCP"
				dnsServers=$(cmclient GETV "$llayer.IPCP.DNSServers")
			;;
			*"X_ADB_VPN.Client.L2TP"*)
				dnsType="IPCP"
				dnsServers=$(cmclient GETV "$llayer.DNSServers")
			;;
			*)
				dnsType="DHCPv4"
				dnsServers=$(cmclient GETV "Device.DHCPv4.Client.[Interface=$obj].DNSServers")
			;;
			esac
		;;
		esac
		cmclient SET "Device.DNS.Client.X_ADB_DynamicServerRule.*.[Interface=${dnsIP}].[Enable=true].Enable" true
		cmclient SET "Device.DNS.Relay.X_ADB_DynamicForwardingRule.*.[Interface=${dnsIP}].[Enable=true].Enable" true
		dns_update "$dnsIP" "$dnsType" "$dnsServers"
	;;
esac

exit 0
