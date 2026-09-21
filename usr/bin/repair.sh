#!/bin/sh

. "$IPKG_INSTROOT/lib/functions/reboot_reason.sh"
. "$IPKG_INSTROOT/lib/functions.sh"

path="/root"
action="$(uci_get system @kernel_crash[0] action compress)"

# Log the reboot in console
echo "WATCHDOG REBOOT with code $1" >/dev/console

# Backup logs
tmpfile="$(mktemp)"
filename="watchdog_$(date | tr ' ' '-')"

{ logread ; dmesg ; ps ; } > $tmpfile

case "${action}" in
	compress)
		echo "watchdog panic info dumped to ${path}/${filename}.gz" >/dev/console
		gzip -c "$tmpfile" > "${path}/${filename}.gz"
	;;
	store)
		echo "watchdog panic info dumped to ${path}/${filename}" >/dev/console
		cp "$tmpfile" "${path}/${filename}"
	;;
	upload)
		url="$(uci_get system @kernel_crash[0] url)"
		if [ -n "${url}" ]; then
			version="$(uci_get version @version[0] version unknown)"
			factory_id="$(uci_get env rip factory_id unknown)"
			board="$(uci_get env rip board_mnemonic unknown)"
			oid="$(uci_get version @version[0] oid unknown)"
			serial="$(uci_get env rip serial unknown)"

			# Insert the ngwfdd tag when uploading to Kibana
			tag="$(uci_get ngwfdd config tag)"

			echo "uploading watchdog panic info to ${url}" >/dev/console
			if ! curl -m 360 -X POST -F "exe=kernel_panic" -F "version=${version}" -F "oid=${oid}" -F "serial=${factory_id}${serial}" -F "board=${board}" -F "file=@$tmpfile" ${tag:+-F tag="$tag"} "${url}"; then
				echo "failed to upload watchdog panic info" >/dev/console
			else
				echo "watchdog panic info uploaded" >/dev/console
			fi
		else
			echo "invalid watchdog panic info upload url" >/dev/console
		fi
	;;
	*)
		echo "unknown watchdog panic info action" >/dev/console
	;;
esac
rm -rf "$tmpfile"


# Update reboot reason to WATCHDOG
set_reboot_reason WATCHDOG

# exit so that watchdog can now reboot
exit $1

