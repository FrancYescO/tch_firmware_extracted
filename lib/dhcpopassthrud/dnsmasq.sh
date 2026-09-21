#!/bin/sh
. "$IPKG_INSTROOT/lib/functions.sh"

# [poolname] [v4|v6] [flush|update] [option list]
POOL=$1
PROTOCOL=$2
ACTION=$3
OPTIONS=$4

OPTSFILE_PATH="/etc/dhcpopassthru.d"

get_main_cfg() {
	local cfg

	config_cb() {
		local type="$1"
		local name="$2"
		if [ "$type" = "dnsmasq" ]; then
		    if [ -z "$cfg" ]; then
			cfg=$name
		    fi
		fi
	}
	config_load dhcp
	echo "$cfg"
}

pool_to_cfg() {
	local pool=$1

	cfg=$(uci_get dhcp "${pool}" dnsmasq_config)
	if [ -z "$cfg" ]; then
	    cfg=$(get_main_cfg)
	fi
	echo "$cfg"
}

dnsmasq_reload() {
	local pool=$1
	local instance

	instance=$(pool_to_cfg "${pool}")
	[ $? -ne 0 ] && return 1

	dnsmasq_cfg="/var/run/dnsmasq.${instance}.pid"
	[ -f "${dnsmasq_cfg}" ] && kill -HUP "$(cat "${dnsmasq_cfg}")"
}

dnsmasq_getopt_type() {
	local option=$1
	local _typevar=$2

	case $option in
		 1) eval $_typevar=addr ;;
		 4) eval $_typevar=addr ;;
		 6) eval $_typevar=addr ;;
		15) eval $_typevar=text ;;
		17) eval $_typevar=text ;;
		42) eval $_typevar=addr ;;
		67) eval $_typevar=text ;;
		 *) eval $_typevar=hex ;;
	esac
}

dnsmasq_mkconfig() {
	local pool=$1
	local protocol=$2
	local options=$3
	local optsfile_path=$4
	local networkid
	local type count temp value val

	networkid=$(uci_get dhcp "${pool}" networkid)
	[ -n "${networkid}" ] && networkid="${networkid##*:},"

	tmp=$(mktemp)
	chmod og+r "$tmp"
	for option in ${options}
	do
		value=$(eval echo "\$OPT_${option}")
		[ -z "$value" ] && continue

		dnsmasq_getopt_type "$option" type
		case $type in
			addr)
				temp=$value
				value=""
				while [ ${#temp} -gt 0 ]
				do
					v="${temp:0:11}"
					temp="${temp:12}"
					val=""
					for a in 0x${v//:/ 0x}
					do
						val=${val}.$(( a ))
					done
					[ ${#value} -gt 0 ] && value=${value},
					value="${value}${val:1}"
				done
				;;
			text)
				value=$(echo -e "\\x${value//:/\\x}")
			;;
		esac
		echo "${networkid}$option,$value" >> "$tmp"
	done
	mv -f "$tmp" "${optsfile_path}/${pool}-${protocol}.conf"
}

get_vendorclass_cfg() {
        local cfg

        vendorclass_cb() {
                local name="$1"
                local networkid

                config_get networkid "$name" networkid
                networkid="${networkid##*:}"
                [ -z "${networkid}" ] && return

                networkid="${networkid##*:}"

                [ "$networkid" = "$2" ] && {
                        local vendorclass

                        config_get vendorclass "$name" vendorclass

                        cfg="${vendorclass} $cfg"
                }
        }
        config_load dhcp

        config_foreach vendorclass_cb vendorclass "$@"
        echo "$cfg"
}

firewall_allow_networkid() {
        local pool=$1
        local networkid
        local vendorclasses
        local fw_reload=0

        /etc/init.d/firewall enabled || return

        networkid=$(uci_get dhcp "${pool}" networkid)
        [ -z "${networkid}" ] && return
        networkid="${networkid##*:}"

        vendorclasses=$(get_vendorclass_cfg "${networkid}")

        logger -t TEST "vendorclasses => $vendorclasses"
 
        for vendorclass in ${vendorclasses}
        do
                enabled=$(uci_get firewall block_"${vendorclass}" enabled 1)
                [ "$enabled" = 0 ] || {
                        uci_set firewall block_"${vendorclass}" enabled 0
                        fw_reload=1
                }
        done

        [ "$fw_reload" = 1 ] && {
                uci_commit firewall
                /etc/init.d/firewall reload
        }
}

handle_ipv4() {
        case "$ACTION" in
                update)
                        dnsmasq_mkconfig "${POOL}" "${PROTOCOL}" "${OPTIONS}" "${OPTSFILE_PATH}" && dnsmasq_reload "${POOL}"
                        firewall_allow_networkid "${POOL}"
                        ;;

        esac
}

case "${PROTOCOL}" in
	v4) handle_ipv4
	    ;;
	*) exit 1
	   ;;
esac
