#!/bin/sh

[ "$user" = "DNS" ] && exit 0

. /etc/ah/helper_ifname.sh

# Configuration Handler for:
# 	- Device.DNS.Relay.Enable
#	- Device.DNS.Relay.Forwarding.{i}.
#	- Device.DNS.Client.Enable
#	- Device.DNS.Client.Server.{i}.
#
# This may affect the following parameters:
# 	- Device.DNS.Relay.Status
#	- Device.DNS.Relay.Forwarding.{i}.Status
#	- Device.DNS.Client.Status
#	- Device.DNS.Client.Server.{i}.Status
#
# Running time:
#	- 770ms for a full Client *or* Relay reconfiguration from scratch on a
#	  BCM6328-based CPE, with two clients, two relays and a dynamic rule
#
#	This handler has been certified for SETM usage!
#				,------------------>>>  always check
#		avoid		.__  ,--- ----- ,.  ,.  the original
#		cheap		   \ |---   |   | \/ |  SETM logo!
#		imitations	---' '---   '   '    '  ^^^^^^^^^^^^

if [ $setEnable -eq 1 ] && [ "$obj" = "Device.DNS.Client" -o "$obj" = "Device.DNS.Relay" ]; then
	[ "$newEnable" = "true" ] && myStatus="Enabled" || myStatus="Disabled"
	[ "$newEnable" = "true" ] && childUpdateOn="Disabled" || childUpdateOn="Enabled"
	cmclient SET "$obj".+.[Status="$childUpdateOn"].Status "$childUpdateOn"
	cmclient -u DNS SET "$obj".Status "$myStatus"
	exit 0
fi

if [ "${obj%.*}" = "Device.DNS.Client.Server" -o "${obj%.*}" = "Device.DNS.Relay.Forwarding" ]; then
	[ "$user" = "CWMP" -a $newType != "Static" -a $setInterface -eq 1 ] && exit 1
fi

if [ $newEnable = "false" ] || [ $op = "d" ] || [ "`cmclient GETV ${obj%.[A-Z][a-z]*}.Enable`" = "false" ]; then
	rm -f /tmp/dns/"${obj}_"*
	cmclient -u DNS SET "$obj".Status Disabled
	# Remove route
	dns_obj=$(cmclient GETO "$obj.[Status=Enabled].[Interface=$newInterface].[DNSServer=$newDNSServer]")
	if [ -n "$newInterface" -a -n "$newDNSServer" -a -z "$dns_obj" ]; then
		roObj=$(cmclient GETO "Device.Routing.Router.*.IPv4Forwarding.*.[Interface=$newInterface].[DestIPAddress=$newDNSServer].[StaticRoute=false]")
		[ -n "$roObj" ] && cmclient -u DNS DEL "$roObj"
	fi
	exit 0
fi

### DNS Server Priority
[ -z "$newX_ADB_PrioBase" ]	&& newX_ADB_PrioBase=0
[ -z "$newX_ADB_PrioDomain" ]	&& newX_ADB_PrioDomain=0
cache_enable=""
[ -z "$newX_ADB_CacheEnable" -a "${obj%.[A-Z][a-z]*}" = "Device.DNS.Client" ] && cache_enable=$(cmclient GETV Device.DNS.Client.X_ADB_CacheEnable) || cache_enable=$newX_ADB_CacheEnable
[ "$cache_enable" = "false" ] && __cache_flag=1 ||  __cache_flag=

#	prio base
if [ $newX_ADB_PrioBase -gt 0 ]; then
	prio=$newX_ADB_PrioBase
else
	[ -n "$newInterface" ] && DNSOverrideAllowed=$(cmclient GETV "$newInterface.X_ADB_DNSOverrideAllowed")
	if [ "$DNSOverrideAllowed" = "true" ]; then
		case "$newType" in
			"Static" ) prio=3 ;;
			"IPCP" ) prio=2 ;;
			"DHCPv6" ) prio=1 ;;
			"DHCPv4" ) prio=0 ;;
		esac
	else
		case "$newType" in
			"Static" ) prio=0 ;;
			"IPCP" ) prio=1 ;;
			"DHCPv6" ) prio=2 ;;
			"DHCPv4" ) prio=3 ;;
		esac
	fi 
fi
#	prio domain
if [ $newX_ADB_PrioDomain -gt 0 ]; then
	domain_prio="$newX_ADB_PrioDomain"
else
	domain_prio="$prio"
fi ### ###

if [ -n "$newType" ]; then
	[ $newType = "Static" ] && cmclient SETS "$obj" 1 || cmclient SETS "$obj" 0
fi

[ -z "$newX_ADB_DomainFiltering" ] && newX_ADB_DomainFiltering="*"
[ -z "$newInterface" ] && iface_name="*" || help_lowlayer_ifname_get "iface_name" "$newInterface"
[ -z "$iface_name" ] && exit 0
[ -z "$newX_ADB_DomainInterface" ] && domain_iface_name="$iface_name" || help_lowlayer_ifname_get "domain_iface_name" "$newX_ADB_DomainInterface"

if [ "${obj%.[A-Z][a-z]*}" = "Device.DNS.Client" ]; then
	newX_ADB_InboundInterface="lo"
else
	[ -z "$newX_ADB_InboundInterface" ] && newX_ADB_InboundInterface="*" || help_lowlayer_ifname_get "newX_ADB_InboundInterface" "$newX_ADB_InboundInterface"
fi
[ -z "$newX_ADB_InboundInterface" ] && exit 0
[ -z "$newX_ADB_Timeout" ] && newX_ADB_Timeout="10000"


set -f; IFS=","; set -- $newX_ADB_DomainFiltering; unset IFS; set +f
i=0
### Be sure to clean all legacy configurations binded to the object
rm -f /tmp/dns/"${obj}_"* 
for arg; do
	__prio=$prio
	__iface_name=$iface_name
	if [ "$arg" = "DROP_RULE" ]; then
		ins_drop_rule=1
		continue
	fi

	if [ "$arg" != "*" ]; then
		[ "${arg#.}" = "$arg" ] && arg=".$arg"
		__prio=$domain_prio
		__iface_name=$domain_iface_name
	fi
	[ -z "$__iface_name" ] && continue
	[ "$newX_ADB_DomainFilteringRestricted" = "true" ] && arg="!${arg}"

	echo "$__prio $arg $newDNSServer $newX_ADB_Timeout $newX_ADB_InboundInterface $__iface_name $__cache_flag" > \
		/tmp/dns/"${obj}_${i}"
	i=$((i+1))

	### Create DROP RULE
	if [ -n "$ins_drop_rule" ]; then
		dr_name="~DR_${arg}"
		dr_iface="*"
		if [ "$newX_ADB_InboundInterface" = "lo" ]; then
			dr_name="${dr_name}_lo"
			dr_iface="lo"
		fi
		if [ ! -e /tmp/dns/"$dr_name" ]; then
			echo "$__prio $arg drop 0 $dr_iface *" > \
				/tmp/dns/"$dr_name"
		fi
		continue
	fi ### ### ###
done
cmclient -u DNS SET "$obj".Status Enabled


# remove route if interface or DNS Server changed
if [ -n "$oldInterface" -a -n "$oldDNSServer" ] && [ "$newInterface" != "$oldInterface" -o "$newDNSServer" != "$oldDNSServer" ]; then
	dns_obj=$(cmclient GETO "$obj.[Status=Enabled].[Interface=$oldInterface].[DNSServer=$oldDNSServer]")
	roObj=$(cmclient GETO "Device.Routing.Router.*.IPv4Forwarding.*.[Interface=$oldInterface].[DestIPAddress=$oldDNSServer].[StaticRoute=false]")
	[ -n "$roObj" -a -z "$dns_obj" ] && cmclient -u DNS DEL "$roObj"
fi


# Do not add route if it is already exist
if [ -n "$newInterface" -a -n "$newDNSServer" ]; then
	roObj=$(cmclient GETO "Device.Routing.Router.*.IPv4Forwarding.*.[Interface=$newInterface].[DestIPAddress=$newDNSServer]")
	[ -n "$roObj" ] && exit 0
fi

# Get gateway from DHCPv4 object and add route for DNS Server
gw=$(cmclient GETV "Device.DHCPv4.Client.*.[Interface=$newInterface].IPRouters")
gw="${gw%%,*}"
if [ -n "$newDNSServer" -a -n "$gw" -a -n "$newInterface" ]; then
	routeId=`cmclient ADDS "Device.Routing.Router.1.IPv4Forwarding"`
	routeObj="Device.Routing.Router.1.IPv4Forwarding.$routeId"
	setm="$routeObj.DestIPAddress=$newDNSServer	$routeObj.Enable=true"
	setm="${setm}	$routeObj.GatewayIPAddress=$gw	$routeObj.Interface=$newInterface"
	setm="${setm}	$routeObj.Origin=DHCPv4	$routeObj.StaticRoute=false"
	setm="${setm}	$routeObj.DestSubnetMask=255.255.255.255"
	cmclient SETM "${setm}"
fi

exit 0
