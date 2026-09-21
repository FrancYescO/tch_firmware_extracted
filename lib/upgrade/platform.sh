RAMFS_COPY_BIN="/usr/bin/bli_parser /usr/bin/bli_unseal /usr/bin/bli_unseal_rsa /usr/bin/bli_unseal_rsa_helper /usr/bin/bli_unseal_aes128 /usr/bin/bli_unseal_aes128_helper /usr/bin/bli_unseal_sha1 /usr/bin/bli_unseal_sha1_helper /usr/bin/bli_unseal_sha256 /usr/bin/bli_unseal_aes256 /usr/bin/bli_unseal_aes256_helper /usr/bin/bli_unseal_zip /usr/bin/bli_unseal_zip_helper /usr/bin/bli_unseal_open /bin/busybox:/bin/sed:/usr/bin/tail:/usr/bin/cut:/bin/mkdir:/bin/mktemp:/bin/rm:/usr/bin/mkfifo:/usr/bin/sha256sum:/usr/bin/tee /usr/bin/curl `ls /etc/ssl/certs/*.0`"

#get rid of the fwtool* checks. they won't do anything usefull
#for us but may output errors that may be confusing
sysupgrade_image_check=platform_check_image

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

		if [ "$ssl_key_type" = "engine" ] && [ -n "$ssl_engine" ] && [ -n "$ssl_key" ]; then
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
		ftp://*) cmd="curl -f --connect-timeout 900 -m 1800 -S -s";;
		http://*) cmd="curl -f --connect-timeout 900 -m 1800 -S -s --anyauth";;
		https://*) cmd="curl -f --connect-timeout 900 -m 1800 -S -s --capath /etc/ssl/certs $(get_client_auth_arguments)";;
		tftp://*) cmd="curl -f --connect-timeout 300 -m 1800 -S -s";;
		tcp://*) cmd="tcp_cat";;
		*)
			cmd="cat"
			filetype=$(get_filetype $from)
		;;
	esac

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
	eval "$cmd \$from ${conc:+| $conc}"
	rv=$?
	ubus send fwupgrade '{ "state": "flashing" }'
	return $rv
}


bli_field() {
	grep $2 $1 | sed 's/.*: //'
}

show_error() {
	local code=$1
	local msg="$2"
	logger -p daemon.crit -t "sysupgrade[$$]" "Sysupgrade failed: $msg"
	v "sysupgrade error $code: $msg"
	echo ${code} >/var/state/sysupgrade
	echo ${msg} >/var/state/sysupgrade-msg
}

platform_check_bliheader() {
	local info="$1"

	# Only allow a BLI format
	if [ "BLI2" != "`bli_field "$info" magic_value`" ]; then
		show_error 3 "Incorrect magic"
		return 1
	fi

	# FIA must match the RIP
	if [ "`cat /proc/rip/0028`" != "`bli_field "$info" fia`" ]; then
		show_error 4 "Incorrect FIA"
		return 1
	fi

	# FIM must be 23
	if [ "23" != "`bli_field "$info" fim`" ]; then
		show_error 5 "Incorrect FIM"
		return 1
	fi

	# Boardname must match the RIP
	if [ "`cat /proc/rip/0040`" != "`bli_field "$info" boardname`" ]; then
		show_error 6 "Incorrect Boardname"
		return 1
	fi

	# Product ID must match the RIP, unless it is the generic one (="0")
	if [ "`cat /proc/rip/8001`" != "0" ] && [ "`cat /proc/rip/8001`" != "`bli_field "$info" prodid`" ]; then
		show_error 7 "Incorrect Product ID"
		return 1
	fi

	# Variant ID must match exactly the RIP settings
	if [ "`cat /proc/rip/8003`" != "`bli_field "$info" varid`"  ] && ! grep -q skip_variantid_check /proc/efu/allowed; then
		show_error 8 "Incorrect Variant ID"
		return 1
	else
		v "Ignoring variant ID check."
	fi

	return 0
}

# Actual implementation of the image check.
# Note that on dual bank platforms the inactive bank will be written to.
# (to avoid storing it in RAM and avoid out of memory conditions)
platform_check_image_imp() {
	rm -f /var/state/sysupgrade
	[ "$ARGC" -gt 1 ] && return 1

	rm -f $(get_cache_filename $1)
        LIBRE_FILE=/usr/bin/libre_luci
        if [ -f "$LIBRE_FILE" ]; then
                v "Libre module is notified for flashing in progress..."
                libre_luci --server 172.16.234.2 --port 7778 --command host_frm_upgrade --progress HFWU_FLASH > /dev/null
        fi

	local bank=$(platform_streaming_bank)
	if [ -n $bank ]; then
		mtd erase $bank
	else
		# single bank, no streaming
		get_image "$1" >/dev/null
	fi

	local memfree=$(awk '/(MemFree|Buffers)/ {free+=$2} END {print free}' /proc/meminfo)
	if [ $memfree -lt 4096 ]; then
		# Having the kernel reclaim pagecache, dentries and inodes and check again
		echo 3 >/proc/sys/vm/drop_caches
		memfree=$(awk '/(MemFree|Buffers)/ {free+=$2} END {print free}' /proc/meminfo)
		if [ $memfree -lt 4096 ]; then
			show_error 1 "Not enough memory available to proceed"
			return 1
		fi
	fi

	# Prepare separate stream for signature check
	local sigcheck_pipe="$(mktemp)"
	rm $sigcheck_pipe
	mkfifo $sigcheck_pipe
	add_temp_file $sigcheck_pipe

	# Create file for bli header info
	local hdr_info="$(mktemp)"
	add_temp_file $hdr_info

	# Create pipe for writing to flash directly (or drop in case of single bank)
	local mtd_pipe="$(mktemp)"
	rm $mtd_pipe
	mkfifo -m 600 $mtd_pipe
	add_temp_file $mtd_pipe

	# Run signature check in background on second stream
	(signature_checker -b <$sigcheck_pipe 2>/dev/null) &
	local sigcheck_pid=$!

	# Run mtd write
	local mtd_pid
	if [ -n $bank ]; then
		(mtd -n write - $bank <$mtd_pipe) &
		mtd_pid=$!
	else
		(cat <$mtd_pipe >/dev/null) &
		mtd_pid=$!
	fi

	# start check/stream writing
	local corrupt=0
	local unseal_err="$(mktemp)"
	rm -rf /tmp/getimageerr
	set -o pipefail
	local rbiinfo=$( (get_image "$1" || (echo $? > /tmp/getimageerr && false))| tee $sigcheck_pipe | (bli_parser > $hdr_info && bli_unseal 2>$unseal_err)|  tee $mtd_pipe | lua /lib/upgrade/rbi_vrss.lua)
	if [ $? -ne 0 ]; then
		E=$(head -1 $unseal_err)
		if [ -n "$E" ]; then
			if [ $(echo $E | grep -c "platform") -ne 0 ]; then
				show_error 15 "Unseal error: $E"
			else
				show_error 9 "Unseal error: $E"
			fi
			return 1
		else
			# postpone reporting this error, it may be cause by a flash failure
			corrupt=1
		fi
	fi
	set +o pipefail
	rm -f $unseal_err

	# Obtain the results

	# Obtain signature result
	wait $sigcheck_pid
	local sigcheck_res=$?
	rm $sigcheck_pipe

	# Writing to flash
	wait $mtd_pid
	local mtd_res=$?
	rm $mtd_pipe

	if [ $mtd_res -ne 0 ]; then
		show_error 16 "flash write failure"
		return 1
	fi

	if [ $corrupt -ne 0 ]; then
		# now report it, it was not a flash failure
		show_error 9 "File is corrupted"
		return 1
	fi

	platform_check_bliheader $hdr_info
	E=$?
	rm $hdr_info
	[ $E -ne 0 ] && return 1

	local unpackedsize=$(echo $rbiinfo | cut -d' ' -f1)
	local vrss=$(echo $rbiinfo | cut -d' ' -f2)
	if [ "$vrss" = "-" ]; then
		show_error 14 "File is not a Homeware RBI"
		return 1
	fi

	if [ $sigcheck_res -ne 0 ]; then
		if ! grep -q skip_signature_check /proc/efu/allowed; then
			show_error 10 "Signature check failed"
			return 1
		else
			v "Ignoring invalid signature"
		fi
	fi

	local banksize=$((0x`cat /proc/mtd  | grep bank_1 | cut -d ' ' -f 2 `))
	if [ $unpackedsize -ne $banksize ]; then
		show_error 11 "File does not match banksize"
		return 1
	fi

	return 0
}

mount_overlay_if_necessary() {
	local device

	if ! ( (mount | grep '/dev/mtdblock[0-9] on /overlay type jffs2' >/dev/null) || (mount | grep '/dev/ubi0_1 on /overlay type ubifs' > /dev/null) ) ; then
		# Running from RAM fs, the jffs2 isn't mounted...
		mkdir -p /overlay
		if (grep -E "ubi" /proc/mtd > /dev/null) ; then
			device=/dev/ubi0_1
                        mount $device /overlay -t ubifs
               else
			device=/dev/mtdblock$(grep -E "(rootfs_data|userfs)" /proc/mtd | sed 's/mtd\([0-9]\):.*\(rootfs_data\|userfs\).*/\1/')
			mount $device /overlay -t jffs2
		fi
		sleep 1
		mount -o remount,rw /overlay
		sleep 1
	fi

	echo $device
}

platform_check_image() {
	if ! platform_check_image_imp "$@"; then
		local bank=$(platform_streaming_bank)
		if [ -n $bank ]; then
			mtd erase $bank
		fi
		return 1
	fi

	return 0
}

platform_do_upgrade() {
	if platform_is_dualbank; then
		local target_bank=$(cat /proc/banktable/notbooted)
		platform_do_upgrade_bank $1 $target_bank || exit 1
		local device=$(mount_overlay_if_necessary)

		if [ -d /overlay/$target_bank ]; then
			# Mark target configuration as removeable
			mv /overlay/$target_bank /overlay/${target_bank}.remove_due_to_upgrade
		fi

		[ ! -z $device ] && umount $device

		if [ "$SWITCH_BANK" -eq 1 ]; then
			echo $target_bank > /proc/banktable/active
		fi
	else
		platform_do_upgrade_bank $1 bank_1 || exit 1
		mount_overlay_if_necessary
		mkdir -p /overlay/homeware_conversion
	fi
}

platform_do_upgrade_bank() {
	local image="$1"
	local bank="$2"

	if [ "$bank" != "bank_1" -a "$bank" != "bank_2" ]; then
		show_error 12 "Only upgrading bank_1 or bank_2 is allowed"
		return 1
	fi

	local mtd=/dev/`cat /proc/mtd  | grep \"$bank\" | sed 's/:.*//'`

	if [ -z $mtd ]; then
		show_error 13 "Could not find bank $bank in /proc/mtd"
		return 1
	fi

	if [ -z $(platform_streaming_bank) ]; then
		LIBRE_FILE=/usr/bin/libre_luci
		if [ -f "$LIBRE_FILE" ]; then
			v "Libre module is notified for flashing in progress..."
			libre_luci --server 172.16.234.2 --port 7778 --command host_frm_upgrade --progress HFWU_FLASH > /dev/null
		fi

		v "Programming..."
		(get_image "$image" | ((bli_parser > /dev/null ) && bli_unseal) | mtd write - $bank ) || {
			show_error 16 "Flash write failure"
			return 1
		}
	else
		v "Image already flashed"
	fi

	v "Clearing FVP of $mtd..."
	dd bs=4 count=1 if=/dev/zero of=$mtd 2>/dev/null || {
		show_error 16 "Flash failure while clearing FVP"
		return 1;
	}
}
