RAMFS_COPY_BIN="/usr/bin/bli_parser /usr/bin/bli_unseal /usr/bin/bli_unseal_rsa /usr/bin/bli_unseal_rsa_helper /usr/bin/bli_unseal_aes128 /usr/bin/bli_unseal_aes128_helper /usr/bin/bli_unseal_sha1 /usr/bin/bli_unseal_sha1_helper /usr/bin/bli_unseal_sha256 /usr/bin/bli_unseal_aes256 /usr/bin/bli_unseal_aes256_helper /usr/bin/bli_unseal_zip /usr/bin/bli_unseal_zip_helper /usr/bin/bli_unseal_open /bin/busybox:/bin/sed:/usr/bin/tail:/usr/bin/cut:/bin/mkdir:/bin/mktemp:/bin/rm:/usr/bin/mkfifo:/usr/bin/sha256sum:/usr/bin/tee /usr/bin/curl `ls /etc/ssl/certs/*.0`"

TEMP_FILES_TO_CLEANUP=
cleanup_temp_files() {
	for f in $TEMP_FILES_TO_CLEANUP; do
		rm -f $f
	done
}

trap "cleanup_temp_files" EXIT

add_temp_file() {
	TEMP_FILES_TO_CLEANUP="$TEMP_FILES_TO_CLEANUP $1"
}

platform_is_dualbank() {
	grep bank_2 /proc/mtd >/dev/null
	return $?
}

platform_streaming_bank() {
	if platform_is_dualbank; then
		cat /proc/banktable/notbooted
	fi
}

get_filetype() {
lua - $1 <<EOF
lfs = require "lfs"
print(lfs.attributes(arg[1], "mode") or "none")
EOF
}

get_cache_filename() {
	echo "/tmp/$(echo $1 | md5sum | cut -d' ' -f1)"
}

get_client_auth_arguments() {
    local ssl_key_type
    local ssl_engine
    local ssl_key
    if [ -n "$SSL_CLIENTCERT" ] && [ -n "$SSL_CLIENTKEY" ]; then
       ssl_key_type="$(echo "$SSL_CLIENTKEY" | cut -f1 -d:)"
       ssl_engine="$(echo "$SSL_CLIENTKEY" | cut -f2 -d:)"
       ssl_key="$(echo "$SSL_CLIENTKEY" | cut -f3 -d:)"
       if [ "$ssl_key_type" == "engine" ] && [ -n "$ssl_engine" ] &&  [ -n "$ssl_key" ]; then
          local key_handler="$(cat "$ssl_key")"
          # Using engine for client authentication.
          echo "--cert $SSL_CLIENTCERT --engine $ssl_engine --key-type ENG --key $key_handler"
       else
	  # Using PEM file for client authentication
          echo "--cert $SSL_CLIENTCERT --key $SSL_CLIENTKEY"
       fi
    fi
}

tcp_cat() {
	echo "$1" | sed -n 's|^tcp://\(.\+\):\([^:]\+\)$|\1 \2|p' | xargs nc
}

get_image() { # <source> [ <command> ]
	local from="$1"
	local conc="$2"
	local cmd
	local pipe
	local rv

	echo "get_image $1" >/dev/console

	local filetype="none"
	case "$from" in
		ftp://*) cmd="wget -O- -q -T 300";;
		http://*) cmd="curl -f --connect-timeout 900 -m 1800 -S -s --anyauth";;
		https://*) cmd="curl -f --connect-timeout 900 -m 1800 -S -s --capath /etc/ssl/certs $(get_client_auth_arguments)";;
		tftp://*) cmd="curl -f --connect-timeout 300 -m 1800 -S -s";;
		tcp://*) cmd="tcp_cat";;
		*)
			cmd="cat"
			filetype=$(get_filetype $from)
		;;
	esac

	if [ ${UPGRADE_SAFELY:-0} -eq 1 ]; then
		# make sure the upgrade happens streaming or is done
		# from a locally downloaded file
		if [ -z $(platform_streaming_bank) ]; then
			#no streaming possible
			if [ "$filetype" != "file" ]; then
				local CACHED_STREAM_FILE=$(get_cache_filename $1)
				if [ ! -f $CACHED_STREAM_FILE ]; then
					# retrieve first for later reuse
					eval "$cmd \$from >$CACHED_STREAM_FILE"
					add_temp_file $CACHED_STREAM_FILE
				fi
				from=$CACHED_STREAM_FILE
			fi
			cmd="cat"
		fi
	fi
	eval "$cmd \$from ${conc:+| $conc}"
	rv=$?
	ubus send fwupgrade '{ "state": "flashing" }'
	return $rv
}


bli_field() {
	INPUT="$1"
	FIELD="$2"
	grep $FIELD $INPUT | sed 's/.*: //'
}

show_error() {
	ERRC=$1
	MSG="$2"
	logger -p daemon.crit -t "sysupgrade[$$]" "Sysupgrade failed: $MSG"
	v "sysupgrade error $ERRC: $MSG"
	echo ${ERRC} >/var/state/sysupgrade
	echo ${MSG} >/var/state/sysupgrade-msg
}

platform_check_bliheader() {
	local INFO="$1"

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

	# Product ID must match the RIP, unless it is the generic one (="0")
	if [ "`cat /proc/rip/8001`" != "0" ] && [ "`cat /proc/rip/8001`" != "`bli_field "$INFO" prodid`" ]; then
		show_error 7 "Incorrect Product ID"
		return 1
	fi

	# Variant ID must match exactly the RIP settings
	if [ "`cat /proc/rip/8003`" != "`bli_field "$INFO" varid`"  ] && ! grep -q skip_variantid_check /proc/efu/allowed; then
		show_error 8 "Incorrect Variant ID"
		return 1
	else
		v "Ignoring variant ID check."
	fi
}

# Actual implementation of the image check.
# Note that on dual bank platforms the inactive bank will be written to.
# (to avoid storing it in RAM and avoid out of memory conditions)
platform_check_image_imp() {
	rm -f /var/state/sysupgrade
	[ "$ARGC" -gt 1 ] && return 1

	rm -f $(get_cache_filename $1)

	BANK=$(platform_streaming_bank)
	if [ ! -z $BANK ]; then
		mtd erase $BANK
	else
		#single bank, no streaming
		stop_apps ${UPGRADE_MODE:-NO_GUI}
		if [ ${UPGRADE_SAFELY:-0} -eq 1 ]; then
			get_image "$1" >/dev/null
		fi
	fi

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

	# Prepare separate stream for signature check
	SIGCHECK_PIPE=$(mktemp)
	rm $SIGCHECK_PIPE
	mkfifo $SIGCHECK_PIPE
	add_temp_file $SIGCHECK_PIPE

	#create file for bli header info
	HDRINFO=$(mktemp)
	add_temp_file $HDRINFO

	#create pipe for writing to flash directly (or drop in case of single bank)
	MTDPIPE=$(mktemp)
	rm $MTDPIPE
	mkfifo -m 600 $MTDPIPE
	add_temp_file $MTDPIPE

	# Run signature check in background on second stream
	(signature_checker -b <$SIGCHECK_PIPE 2>/dev/null) &
	SIGCHECK_PID=$!

	#run mtd write
	if [ ! -z $BANK ]; then
		(mtd -n write - $BANK <$MTDPIPE) &
		MTD_PID=$!
	else
		(cat <$MTDPIPE >/dev/null) &
		MTD_PID=$!
	fi

	# start check/stream writing
	local CORRUPT=0
	UNSEAL_ERR=$(mktemp)
	rm -rf /tmp/getimageerr
	set -o pipefail
	RBIINFO=$( (get_image "$1" || (echo $? > /tmp/getimageerr && false))| tee $SIGCHECK_PIPE | (bli_parser > $HDRINFO && bli_unseal 2>$UNSEAL_ERR)|  tee $MTDPIPE | lua /lib/upgrade/rbi_vrss.lua)
	if [ $? -ne 0 ]; then
		E=$(head -1 $UNSEAL_ERR)
		if [ -n "$E" ]; then
			if [ $(echo $E | grep -c "platform") -ne 0 ]; then
				show_error 15 "Unseal error: $E"
			else
				show_error 9 "Unseal error: $E"
			fi
			return 1
		else
			# postpone reporting this error, it may be cause by a flash failure
			CORRUPT=1
		fi
	fi
	set +o pipefail
	rm -f $UNSEAL_ERR

	#obtain the results

	# Obtain signature result
	wait $SIGCHECK_PID
	SIGCHECK_RESULT=$?
	rm $SIGCHECK_PIPE

	#writing to flash
	wait $MTD_PID
	MTD_RESULT=$?
	rm $MTDPIPE

	if [ $MTD_RESULT -ne 0 ]; then
		show_error 16 "flash write failure"
		return 1
	fi

	if [ $CORRUPT -ne 0 ]; then
		# now report it, it was not a flash failure
		show_error 9 "File is corrupted"
		return 1
	fi

	platform_check_bliheader $HDRINFO
	E=$?
	rm $HDRINFO
	[ $E -ne 0 ] && return 1

	UNPACKEDSIZE=$(echo $RBIINFO | cut -d' ' -f1)
	VRSS=$(echo $RBIINFO | cut -d' ' -f2)
	if [ "$VRSS" = "-" ]; then
		show_error 14 "File is not a Homeware RBI"
		return 1
	fi

	if [ $SIGCHECK_RESULT -ne 0 ]; then
		if ! grep -q skip_signature_check /proc/efu/allowed; then
			show_error 10 "Signature check failed"
			return 1
		else
			v "Ignoring invalid signature"
		fi
	fi

	BANKSIZE=$((0x`cat /proc/mtd  | grep bank_1 | cut -d ' ' -f 2 `))
	if [ $UNPACKEDSIZE -ne $BANKSIZE ]; then
		show_error 11 "File does not match banksize"
		return 1
	fi

	return 0;
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

platform_check_image() {
	platform_check_image_imp "$@"
	if [ $? -ne 0 ]; then
		local BANK=$(platform_streaming_bank)
		if [ ! -z $BANK ]; then
			mtd erase $BANK
		fi
		return 1
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
		if [ ! -z $device ]; then
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

	if [ -z $(platform_streaming_bank) ]; then
		v "Programming..."
		(get_image "$1" | ((bli_parser > /dev/null ) && bli_unseal) | mtd write - $2 ) || {
			show_error 16 "Flash write failure"
			return 1;
		}
	else
		v "Image already flashed"
	fi

	v "Clearing FVP of $MTD..."
	dd bs=4 count=1 if=/dev/zero of=$MTD 2>/dev/null || {
		show_error 16 "Flash failure while clearing FVP"
		return 1;
	}

	v "Firmware upgrade done"
}
