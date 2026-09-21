RAMFS_COPY_BIN="/usr/bin/bli_parser /usr/bin/bli_unseal /usr/bin/bli_unseal_rsa /usr/bin/bli_unseal_rsa_helper /usr/bin/bli_unseal_aes128 /usr/bin/bli_unseal_aes128_helper /usr/bin/bli_unseal_sha1 /usr/bin/bli_unseal_sha1_helper /usr/bin/bli_unseal_sha256 /usr/bin/bli_unseal_aes256 /usr/bin/bli_unseal_aes256_helper /usr/bin/bli_unseal_zip /usr/bin/bli_unseal_zip_helper /usr/bin/bli_unseal_open /bin/busybox:/bin/sed:/usr/bin/tail:/usr/bin/cut:/bin/mkdir:/bin/mktemp:/bin/rm:/usr/bin/mkfifo:/usr/bin/sha256sum:/usr/bin/tee /usr/bin/curl `ls /etc/ssl/certs/*.0`"

get_image() { # <source> [ <command> ]
	local from="$1"
	local conc="$2"
	local cmd

	case "$from" in
		http://*|ftp://*) cmd="wget -O- -q";;
		https://*) cmd="curl -S -s --capath /etc/ssl/certs";;
                tftp://*) cmd="curl --connect-timeout 300 -m 1800 -S -s";;
		*) cmd="cat";;
	esac
	if [ -z "$conc" ]; then
		local magic="$(eval $cmd \$from | dd bs=2 count=1 2>/dev/null | hexdump -n 2 -e '1/1 "%02x"')"
		case "$magic" in
			1f8b) conc="zcat";;
			425a) conc="bzcat";;
		esac
	fi

	eval "$cmd \$from ${conc:+| $conc}"
}

bli_field() {
	INPUT="$1"
	FIELD="$2"
        echo "$1" | grep $2 | sed 's/.*: //'
}

show_error() {
	ERRC=$1
	MSG="$2"
	logger -p daemon.crit -t "sysupgrade[$$]" "Sysupgrade failed: $MSG"
	echo "$MSG"
	echo ${ERRC} >/var/state/sysupgrade
}

platform_check_image() {
	rm -f /var/state/sysupgrade
	[ "$ARGC" -gt 1 ] && return 1

	MEMFREE=$(awk '/(MemFree|Buffers)/ {free+=$2} END {print free}' /proc/meminfo)
	if [ $MEMFREE -lt 4096 ]; then
	    # Having the kernel reclaim pagecache, dentries and inodes and check again
	    echo 3 >/proc/sys/vm/drop_caches
	    MEMFREE=$(awk '/(MemFree|Buffers)/ {free+=$2} END {print free}' /proc/meminfo)
	    if [ $MEMFREE -lt 4096 ]; then
		show_error 1 "Not enough memory available to proceed"
		return 1
	    fi
	fi

	INFO=`get_image "$1" | bli_parser`
	if [ $? -ne 0 ]; then
		show_error 2 "Header is corrupted"
		return 1;
	fi

	# Only allow a BLI format
	if [ "BLI2" != "`bli_field "$INFO" magic_value`" ]; then
		show_error 3 "Incorrect magic"
		return 1
	fi

	# FIA must match the RIP
	if [ "`cat /proc/rip/0028`" != "`bli_field "$INFO" fia`" ]; then
		show_error 4 "Incorrect FIA"
		return 1
	fi

	# FIM must be 23
	if [ "23" != "`bli_field "$INFO" fim`" ]; then
		show_error 5 "Incorrect FIM"
		return 1
	fi

	# Boardname must match the RIP
	if [ "`cat /proc/rip/0040`" != "`bli_field "$INFO" boardname`" ]; then
		show_error 6 "Incorrect Boardname"
		return 1
	fi

	# Product ID must match the RIP
	if [ "`cat /proc/rip/8001`" != "`bli_field "$INFO" prodid`" ]; then
		show_error 7 "Incorrect Product ID"
		return 1
	fi

	# Variant ID must match the RIP, except if set to 0 in RIP
	if [ "`cat /proc/rip/8003`" != "0" ] && [ "`cat /proc/rip/8003`" != "`bli_field "$INFO" varid`" ]; then
		show_error 8 "Incorrect Variant ID"
		return 1
	fi

	# Prepare separate stream for signature check
	SIGCHECK_PIPE=`mktemp`
	rm $SIGCHECK_PIPE
	mkfifo $SIGCHECK_PIPE

	# Run signature check in background on second stream
	(signature_checker -b <$SIGCHECK_PIPE 2>/dev/null) &
	SIGCHECK_PID=$!

	# Do a dry-run
	set -o pipefail
        UNPACKEDSIZE=`get_image "$1" | tee $SIGCHECK_PIPE | (bli_parser > /dev/null && bli_unseal)| wc -c`
	if [ $? -ne 0 ]; then
		show_error 9 "File is corrupted"
		return 1
	fi
	set +o pipefail

	# Obtain signature result
	wait $SIGCHECK_PID
	SIGCHECK_RESULT=$?
	rm $SIGCHECK_PIPE

	if [ $SIGCHECK_RESULT -ne 0 ]; then
		show_error 10 "Signature check failed"
		return 1
	fi

	BANKSIZE=$((0x`cat /proc/mtd  | grep bank_1 | cut -d ' ' -f 2 `))
	if [ $UNPACKEDSIZE -ne $BANKSIZE ]; then
		show_error 11 "File does not match banksize"
		return 1
	fi

	return 0;
}

platform_is_dualbank() {
	grep bank_2 /proc/mtd >/dev/null
	return $?
}

mount_overlay_if_necessary() {
	if ! ( mount | grep '/dev/mtdblock[0-9] on /overlay type jffs2' >/dev/null ) ; then
		# Running from RAM fs, the jffs2 isn't mounted...
		mkdir -p /overlay
		device=/dev/mtdblock$(grep -E "(rootfs_data|userfs)" /proc/mtd | sed 's/mtd\([0-9]\):.*\(rootfs_data\|userfs\).*/\1/')
		mount $device /overlay -t jffs2
		sleep 1
		mount -o remount,rw /overlay
		sleep 1
	fi
}

platform_do_upgrade() {
	if platform_is_dualbank; then
		target_bank=$(cat /proc/banktable/notbooted)
		platform_do_upgrade_bank $1 $target_bank || exit 1
		mount_overlay_if_necessary
		if [ -d /overlay/$target_bank ]; then
			# Mark target configuration as removeable
			mv /overlay/$target_bank /overlay/${target_bank}.remove_due_to_upgrade
		fi
		if [ -n $device ]; then
			umount $device
		fi
		if [ "$SWITCHBANK" -eq 1 ]; then
			echo $target_bank > /proc/banktable/active
		fi
	else
		platform_do_upgrade_bank $1 bank_1 || exit 1
		mount_overlay_if_necessary
		mkdir -p /overlay/homeware_conversion
	fi
}

platform_do_upgrade_bank() {
	BANK="$2"

	if [ "$BANK" != "bank_1" ]; then
		if [ "$BANK" != "bank_2" ]; then
			show_error 12 "Only upgrading bank_1 or bank_2 is allowed"
			return 1;
		fi
	fi

	MTD=/dev/`cat /proc/mtd  | grep \"$BANK\" | sed 's/:.*//'`

	if [ -z $MTD ]; then
		show_error 13 "Could not find bank $BANK in /proc/mtd"
		return 1;
	fi

	v "Programming..."
	(get_image "$1" | ((bli_parser > /dev/null ) && bli_unseal) | mtd write - $2 ) || return 1;

	v "Clearing FVP of $MTD..."
	dd bs=4 count=1 if=/dev/zero of=$MTD 2>/dev/null || return 1;

	v "Firmware upgrade done"
}
