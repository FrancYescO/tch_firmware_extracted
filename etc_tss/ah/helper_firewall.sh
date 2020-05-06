#!/bin/sh

type help_serialize >/dev/null || . /etc/ah/helper_serialize.sh

if [ -f /etc/ah/IPv6_helper_firewall.sh ]; then
	help_iptables_all() {
		help_iptables "$@"
		help_ip6tables "$@"
	}
else
	help_iptables_all() {
		help_iptables "$@"
	}
fi

#
# NOTE!: THIS FUNCTION IS USED AS A MARKER WHEN SOURCING THIS HELPER;
#        IT CANNOT BE DELETED OR RENAMED WITHOUT FIXING ALL AROUND LINES OF TYPE
#        command -v help_iptables >/dev/null || . /etc/ah/helper_firewall.sh
#
help_iptables() {
	# FIXME Implement a better locking system
	if [ -z "$tmpiptablesprefix" ]; then
		if [ -n "$user" ] && [ -d "/tmp/$user" ]; then
			export tmpiptablesprefix="/tmp/$user"
		else
			export tmpiptablesprefix="/tmp/iptables_"`cut -c1-6 < "/proc/sys/kernel/random/uuid"`
			mkdir $tmpiptablesprefix
		fi
	elif [ ! -d "$tmpiptablesprefix" ]; then
		[ "$1" != commit ] && \
			echo "$0 $tmpiptablesprefix directory does not exists when executing help_iptables $@" >/dev/console
		return 1
	fi

	local current_table="filter"

	if [ "$1" = "-t" ]; then
		current_table=$2
		shift 2
	fi

	local tmpfile="$tmpiptablesprefix/iptables-$current_table"

	if [ ! -s "$tmpfile" ]; then
		echo "*$current_table" > "$tmpfile"
		help_append_trap "help_iptables commit && rmdir \"$tmpiptablesprefix\" 2>/dev/null" EXIT
	fi

	case "$1" in
		commit)
			set +f
			help_serialize iptables-commit notrap >/dev/null
			for rulefile in "$tmpiptablesprefix"/iptables-*; do
				[ -f "$rulefile" ] || continue
				echo "COMMIT" >> "$rulefile"
				cat "$rulefile" >> "$tmpiptablesprefix/iptables"
			done
			rm -f "$tmpiptablesprefix"/iptables-*
			if [ -s "$tmpiptablesprefix/iptables" ]; then
				if [ "$2" = "noerr" ]; then
					iptables-restore --noflush < "$tmpiptablesprefix/iptables" 2>/dev/null
				else
					if iptables-restore --noflush < "$tmpiptablesprefix/iptables" 2>/dev/console; then :; else
						echo '\n\e[47;35mERROR!\e[0m\n\n' >/dev/console
						local i=1
						while IFS= read -r x; do
							echo "$i: $x" >/dev/console
							i=$((i + 1))
						done < "$tmpiptablesprefix/iptables"
					fi
				fi
			fi
			rm -f "$tmpiptablesprefix/iptables"

			if [ -f "$tmpiptablesprefix/do_flush" ]; then
				echo 1 > /proc/net/nf_conntrack_flush
				rm -f "$tmpiptablesprefix/do_flush"
			fi

			# TODO: move this to targets.
			local lastFlush=0
			[ -s /tmp/last_fc_flush ] && read -r lastFlush < /tmp/last_fc_flush
			local now
			IFS=. read -r now _ < /proc/uptime
			if [ $((now - 5)) -gt $lastFlush ]; then
				[ -x /bin/fc ] && fc flush
				echo $now > /tmp/last_fc_flush
			fi
			help_serialize_unlock iptables-commit
			;;
		-[NF])
			echo ":$2 -" >> "$tmpfile"
			;;
		*)
			echo "$@" >> "$tmpfile"
			;;
	esac
}

help_iptables_no_cache() {
	help_iptables "$@" -m comment --comment 'nocache'
}

isEnslaved() {
	local ifname="$1" i l

	i=$(cmclient GETO "Device.**.[Name=$ifname]")
	for i in $i; do
		if [ "${i%%.[0-9]*}" != "Device.Bridging.Bridge" ]; then
			l=$(cmclient GETV InterfaceStack.[LowerLayer="$i"].HigherLayer)
			for l in $l; do
				[ "${l%%.[0-9]*}" = "Device.Bridging.Bridge" ] && return 0
			done
		fi
	done
	return 1
}


#
# Usage: bridge_get_wan <ret> <Bridging.Bridge.obj>
# Get the interface name of the wan bridge port in the provided bridge, if any
#
help_bridge_get_wan() {
	[ "$1" != "_v" ] && local _v
	[ "$1" != "_p" ] && local _p

	_v=""
	_p=$(cmclient GETV -u "$user" "$2.**.[ManagementPort=false].LowerLayers")
	for _p in $_p; do
		is_wan_intf "$_p" && help_lowlayer_ifname_get _p $_p && _v=${_v:+$_v }$_p
	done
	eval $1='$_v'
}

sep_un='_'
sep_NL='\n'
getMapOfRule()
{
	mapList=""
	local chain_nr=''
	chains=$(cmclient GETO "Device.Firewall.Chain.Rule.")
	local target targetChain
	for chains in $chains; do
		target=$(cmclient GETV $chains.Target)
		if [ $target = "TargetChain" ]; then
			targetChain=$(cmclient GETV $chains.TargetChain)
			enable=$(cmclient GETV $chains.Enable)
			if [ $enable = "true" ]; then
				get_elem_n chain_nr $chains 4 '.'
				mapList=$mapList"$chain_nr$sep_un"${chains##*.}" "${targetChain##*.}"\n"
				eval var_mapa=mapa_"$chain_nr$sep_un"${chains##*.}
				eval $var_mapa=${targetChain##*.}
			fi
		fi
	done
}

searchLoopedRule()
{
	local startPoint
	local rows
	local isLoop
	local startChain=$1

#	getMapOfRule mapList
	getMapOfRule
	get_elem_n startPoint $1 4 '.'
	startPoint="$startPoint$sep_un${startChain##*.}"

#CHAINS OCCURENCE
	local chainNr
	local listOfChains=''
	local prefix=$sep_un
	local postfix=" "
	while read lineMap; do

		chainRule=${lineMap%%" "*}
		chainNr=${lineMap%%${sep_un}*}
		if help_is_in_list_general "$listOfChains" "$chainNr" "$prefix" "$postfix"; then
			eval chainOccurence_${chainNr}=\$'(('chainOccurence_${chainNr} + 1'))'
		else
			eval chainOccurence_${chainNr}=1
			listOfChains="$listOfChains$prefix$chainNr$postfix"
		fi
		eval chainOccurence=\$chainOccurence_${chainNr}
		eval variable=helpMapPointRule_${chainNr}${sep_un}$chainOccurence
		eval $variable=$chainRule

	done <<-EOF
	$(echo "$mapList")
	EOF

	searchLoop $startPoint 0 "NOLOOP" 1
	ret=$?
	dealocLoopedRulesVariables
	return $ret
}

dealocLoopedRulesVariables()
{
	echo "BPK CLEAR"
	local chainNr
	local listOfChains=''
	local prefix=$sep_un
	local postfix=" "

	prevChainNr=${mapList%%${sep_un}*}
	while read lineMap; do

		chainRule=${lineMap%%" "*}
		chainNr=${lineMap%%${sep_un}*}

		if help_is_in_list_general "$listOfChains" "$chainNr" "$prefix" "$postfix"; then
			eval chainOccurence_${chainNr}=\$'(('chainOccurence_${chainNr} + 1'))'
		else
			eval chainOccurence_${chainNr}=1
			listOfChains="$listOfChains$prefix$chainNr$postfix"
		fi
		eval chainOccurence=\$chainOccurence_${chainNr}
		eval variable=helpMapPointRule_${chainNr}${sep_un}$chainOccurence
		eval $variable=""

		if [ $chainNr -ne $prevChainNr ]; then
			eval chainOccurence_${prevChainNr}=""
			prevChainNr=$chainNr
		fi

	done <<-EOF
	$(echo "$mapList")
	EOF
	eval chainOccurence_${chainNr}=""

}


#
#	REQURSIVE SEARCHING OF LOOPED RULES
#
#	$1 - StartRule
#	$2 - history
#	$3 - RET
#	$4 - FLAG START POINT
#
searchLoop()
{
	startPoint=$1
	deep=$2
	result=$3
	searchBegin=$4
	startPointIsOnMap=0

	if help_is_in_list_general "$mapList" "$startPoint" "$sep_NL" " "; then
		startPointIsOnMap=1
	fi

	if [ 1 -eq $startPointIsOnMap ]; then
		thisChain=${startPoint%%"$sep_un"*}
		deep=$((deep+1))
		history=${history}"${sep_un}${thisChain}"

		if [ 1 -eq $searchBegin ]; then
			eval chainOccurence_${thisChain}=1
			history=${history#${sep_un}*}
		fi

		eval chainOccurence=\$chainOccurence_${thisChain}
		currentRule=$startPoint

		#Check if current chain occured - check if loop
		if [ $searchBegin -eq 0 ]; then
			help_is_in_list_general ${history%"$sep_un"*} "$thisChain" "$sep_un" "$sep_un"
			[ 0 -eq $? ] && result="LOOP"
		else
			searchBegin=0
		fi

		while [ $chainOccurence -gt 0 -a $result != "LOOP" ];
		do
			eval nextChain=\$mapa_$currentRule
			eval nextChainOccurence=\$chainOccurence_${nextChain}
			nextRule=""
			eval nextRule=\$helpMapPointRule_${nextChain}${sep_un}$nextChainOccurence

			#RECURSION
			if [ $result != "LOOP" -a $nextChainOccurence -gt 0 -a -n "$nextRule" ]; then
				searchLoop $nextRule $deep "$result" 0
				if [ 1 -eq $? ]; then
					result="LOOP"
					break
				fi
				get_elem_n thisChain "${history}$sep_un" $deep '$sep_un'
			fi

			eval chainOccurence=\$chainOccurence_${thisChain}
			chainOccurence=$((chainOccurence - 1))
			eval chainOccurence_${thisChain}=$chainOccurence
			eval currentRule=\$helpMapPointRule_${thisChain}${sep_un}$chainOccurence
		done
		deep=$((deep-1))
		[ $deep -gt 0 ] && history=${history%"$sep_un"*} || history=""
	fi
	[ $result = "LOOP" ] && return 1 || return 0
}

