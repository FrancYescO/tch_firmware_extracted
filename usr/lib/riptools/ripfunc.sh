
SILENT=${SILENT:-1}
DRYRUN=${DRYRUN:-0}

RIPNAME=eripv2
RIPDEV=
RIPTYPE=
RIPSIZE=

rip_debug() {
	if [ "$SILENT" != "1" ]; then
		echo "$*"
	fi
}

findrip_ubi() {
	local devnum=0
	local volumes
	local volname
	while true ; do
		volumes=$(ubinfo -a -d $devnum 2>/dev/null| grep "^Volume ID" | tr -d : | tr -s ' ' | cut -d' ' -f3 | tr "\n" " ")
		echo "DEV $devnum VOLUMES=$volumes"
		[ -z "$volumes" ] && break
		for volid in $volumes ; do
			volname=$(ubinfo -a -d $devnum -n $volid | grep ^Name | tr -s ' ' | cut -d' ' -f2)
			echo "VOLUME $devnum/$volid: $volname"
			if [ "$volname" = "$RIPNAME" ] ; then
				RIPDEV=/dev/ubi${devnum}_${volid}
				RIPSIZE=$(cat /sys/devices/virtual/ubi/ubi${devnum}/ubi"${devnum}_${volid}"/data_bytes )
				RIPTYPE=UBI
				echo FOUND
				return
			fi
		done
		devnum=$(($devnum + 1))
	done
}

findrip_mtd() {
	local part=$(grep $RIPNAME /proc/mtd | cut -d ' ' -f1 | tr -d ': ')
	if [ -z "$part" ]; then
		return
	fi
	RIPDEV=/dev/$part
	RIPTYPE=MTD
	RIPSIZE=$((0x$(grep eripv2 /proc/mtd | cut -d ' ' -f2)))
}

#find rip device, size and type
if [ ! -z "$(which ubinfo)" -a ! -z "$(which ubiupdatevol)" ]; then
	findrip_ubi
fi
if [ -z $RIPDEV ]; then
	findrip_mtd
fi

if [ -z $RIPDEV ]; then
	echo "error: No eripv2 partition found"
	exit 1
fi

rip_debug RIPDEV=$RIPDEV
rip_debug RIPTYPE=$RIPTYPE
rip_debug RIPSIZE=$RIPSIZE

gethash() {
	local name=$1
	md5sum $name | cut -d ' ' -f1
}

update_rip_partition() {
	local img=$1
	local cmd
	if [ "$RIPTYPE" = "MTD" ]; then
		cmd="mtd write $img $RIPDEV"
	elif [ "$RIPTYPE" = "UBI" ]; then
		cmd="ubiupdatevol $RIPDEV $img"
	else
		echo "error: do not know how to write the eRIP"
		return 1
	fi
	rip_debug $cmd
	if [ "$DRYRUN" = "0" ]; then
		$cmd
	fi
}

writerip() {
	local img=$1
	local hash=$2
	local rhash
	
	if [ -z "$img" ]; then
		echo "error: no contents to write"
		return 1
	fi
	
	if [ -z "$RIPDEV" ]; then
		echo "error: no eRIP partition found"
		return 1
	fi
	
	if [ ! -z "$hash" ]; then
		rhash=$(gethash $RIPDEV)
		if [ "$rhash" = "$hash" ]; then
			echo "OK: RIP contents already up-to-date, skipping write"
			return 0
		fi
	fi
	
	update_rip_partition $img
	
	if [ ! -z $hash ]; then
		rhash=$(gethash $RIPDEV)
		if [ "$rhash" != "$hash" ]; then
			echo "FATAL: eRIP not correctly written"
			return 1
		fi
	fi
}

reload_ripdrv() {
	rip_debug "reloading $RIP_MODULES_TO_RELOAD"
	for mod in $RIP_MODULES_TO_RELOAD; do
		insmod $mod
		rip_debug "loaded $mod"
	done
}

unload_ripdrv() {
	local modules=""
	if [ $(lsmod | grep -c ^keymanager) -gt 0 ]; then
		RIP_MODULES_TO_RELOAD=keymanager
		rmmod keymanager || return 1
		rip_debug "unloaded keymanager"
	fi
	
	rmmod ripdrv 
	if [ $? -ne 0 ]; then
		reload_ripdrv
		return 1
	fi
	rip_debug "unloaded ripdrv"
	RIP_MODULES_TO_RELOAD="ripdrv $RIP_MODULES_TO_RELOAD"
	rip_debug "need to reload: $RIP_MODULES_TO_RELOAD"
}

ripclean() {
	/usr/lib/riptools/ripclean "$@"
}

rip_delete_entries() {
	local E=0
	local D=""
	for entry in $* ; do
		D="$D -d $entry"
	done
	
	if [ -z "$RIPDEV" ]; then
		echo "error no eRIP partition found"
		return 1
	fi
	
	local tmpripdir=$(mktemp -p /tmp -d)
	local tmprip=$tmpripdir/rip
	local cmd="ripclean -s $RIPSIZE $D $RIPDEV $tmprip"
	rip_debug $cmd
	if [ "$SILENT" = "1" ]; then
		$cmd >/dev/null
	else
		$cmd
	fi
	
	local modules
	if [ -f $tmprip ]; then
		unload_ripdrv
		if [ $? -ne 0 ]; then
			echo "error: failed to unload the rip driver"
			E=1
		else
			writerip $tmprip $(gethash $tmprip) || E=$?
			reload_ripdrv
		fi
	else
		echo "rip not changed"
	fi
	rm -rf $tmpripdir
	
	return $E 
}
