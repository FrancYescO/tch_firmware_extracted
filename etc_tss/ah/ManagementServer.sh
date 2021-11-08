#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handler for:	Device.ManagementServer
#

AH_NAME="TR069"

[ "$user" = "$AH_NAME" ] && exit 0

. /etc/ah/helper_functions.sh
. /etc/ah/helper_provisioning.sh

update_cr_url()
{
	if [ "$newX_ADB_IPv6Preferred" = "true" ]; then
		addr=$(cmclient GETV "${newX_ADB_ConnectionRequestInterface}.IPv6Address.[Status=Enabled].[IPAddressStatus!Invalid].IPAddress")
		if [ -z "$addr" ]; then
			addr=$(cmclient GETV "${newX_ADB_ConnectionRequestInterface}.IPv4Address.IPAddress")
			for addr in $addr; do
				break
			done
			IPv6Addr=0
		else
			# Now we select the "good" IPv6 address candidate.
			for single in $addr; do
				case $single in
				fe80*)
					;;
				*)
					found="y"
					break
					;;
				esac
			done
			if [ "$found" = "y" ]; then
				addr="$single"
				IPv6Addr=1
			else
				addr=$(cmclient GETV "${newX_ADB_ConnectionRequestInterface}.IPv4Address.IPAddress")
				for addr in $addr; do
					break
				done
				IPv6Addr=0
			fi
		fi
	else
		addr=$(cmclient GETV "${newX_ADB_ConnectionRequestInterface}.IPv4Address.IPAddress")
		for addr in $addr; do
			break
		done
		IPv6Addr=0
	fi
	if [ -n "$addr" ]; then
		_tmp=$(cmclient GETV Device.ManagementServer.X_ADB_ConnectionRequestRandomPath)
		if [ "$_tmp" = "true" ]; then
			randPath=$(tr -Cd "a-zA-Z0-9" < /dev/urandom | head -c 10)
			newX_ADB_ConnectionRequestPath="${newX_ADB_ConnectionRequestPath}${randPath}"
		fi
		[ "$IPv6Addr" = "1" ] &&\
			newurl="http://[${addr}]:${newX_ADB_ConnectionRequestPort}/${newX_ADB_ConnectionRequestPath}" ||\
			newurl="http://${addr}:${newX_ADB_ConnectionRequestPort}/${newX_ADB_ConnectionRequestPath}"
	else
		newurl=""
	fi
	[ -n "$newurl" -a "$newurl" != "$newConnectionRequestURL" ] && cmclient -u TR069 SET Device.ManagementServer.ConnectionRequestURL "$newurl"
}

check_service()
{
	if help_post_provisioning_add "Device.ManagementServer.EnableCWMP" "$newEnableCWMP" "Default"; then
		if [ "$newEnableCWMP" = "true" ]; then
			/etc/init.d/cwmp enable
			/etc/init.d/cwmp start
		else
			/etc/init.d/cwmp stop
			/etc/init.d/cwmp disable
		fi
	fi
}

##################
### Start here ###
##################
case "$op" in
s)
	if help_is_changed X_ADB_ConnectionRequestPort X_ADB_ConnectionRequestPath X_ADB_ConnectionRequestRandomPath\
		X_ADB_ConnectionRequestInterface X_ADB_IPv6Preferred || help_is_set EnableCWMP; then
		update_cr_url
	fi
	if help_is_changed EnableCWMP; then
		check_service
	fi
	;;
esac
exit 0
