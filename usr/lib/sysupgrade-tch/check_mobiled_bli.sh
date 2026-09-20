#!/bin/sh

# Exit as soon as a command fails.
set -e

temp_dir="$1"
image_url="$2"
current_version="$3"

check_bli_field() {
	local field_name="$1"
	local expected_value="$2"

	grep -Fqx "$1: $2" "$temp_dir/header_info"
}

# Remove the temporary directory as soon as this script exits.
trap "rm -rf '$temp_dir'" EXIT

# Just download http:// urls
case "$image_url" in
	http*://*)
		# HTTP URLs are assumed to be raw images in order to maintain backward compatibility.
		curl -s -o "$temp_dir/output_fifo" "$image_url"
	;;

	tcp://*)
		# Start a process that checks the BLI signature.
		mkfifo "$temp_dir/sigcheck_pipe"
		signature_checker -b <"$temp_dir/sigcheck_pipe" &
		sigcheck_pid="$!"

		# Strip the BLI header and unseal the BLI.
		echo "$image_url" | sed -n 's|^tcp://\(.\+\):\([^:]\+\)$|\1 \2|p' | xargs nc | tee "$temp_dir/sigcheck_pipe" | (bli_parser >"$temp_dir/header_info" && bli_unseal 2>"$temp_dir/unseal_error") >"$temp_dir/output_fifo"

		# Verify that the signature is correct.
		wait "$sigcheck_pid"

		check_bli_field magic_value BLI2
		check_bli_field fim 23
		check_bli_field boardname "$current_version"
	;;

	*)
		false
	;;
esac
