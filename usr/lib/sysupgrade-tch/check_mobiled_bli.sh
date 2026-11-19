#!/bin/sh

# Exit as soon as a command fails.
set -e -o pipefail

upgrade_dir="$1"
temp_dir="$2"
image_url="$3"
current_version="$4"

# Remove the temporary directory as soon as this script exits.
trap "rm -rf '$temp_dir'" EXIT

extract_image() {
	IFS= read -r -n 4 magic_number
	case "$magic_number" in
		# Combined images consist of:
		#    1. a magic number (4 bytes)
		#    2. a length field indicating the size of the image in base 10 ASCII,
		#       left-padded with zeroes (16 bytes)
		#    3. the image data (the amount of bytes indicated by the length field)
		#    4. a TAR file containing additional files (the remainig data)
		TCH1)
			# Read the size of the image and copy a chunk of that size to stdout so it will
			# be streamed to the module.
			IFS= read -r -n 16 image_size
			echo "$image_size" | grep -Eqx "[0-9]+"
			dd ibs=1 count="$image_size" obs=1024

			# Treat the remainder of the input as a tarball and extract it to the upgrade
			# directory.
			mkdir -p "$upgrade_dir"
			tar -x -C "$upgrade_dir"
		;;

		# An unknown magic number indicates a legacy image. Just copy the
		# entire input (including the magic number) over to stdout so it will
		# be streamed to the module.
		*)
			printf '%s' "$magic_number"
			dd
		;;
	esac
}

check_bli_field() {
	field_name="$1"
	expected_value="$2"

	grep -Fqx "$field_name: $expected_value" "$temp_dir/header_info"
}

extract_and_check_bli() {
	# Start a process that checks the BLI signature.
	mkfifo "$temp_dir/sigcheck_pipe"
	signature_checker -b <"$temp_dir/sigcheck_pipe" &
	sigcheck_pid="$!"

	# Strip the BLI header and unseal the BLI.
	tee "$temp_dir/sigcheck_pipe" \
		| (bli_parser >"$temp_dir/header_info" && bli_unseal 2>"$temp_dir/unseal_error") \
		| extract_image

	# Verify that the signature is correct.
	wait "$sigcheck_pid"

	check_bli_field magic_value BLI2
	check_bli_field fim 23
	check_bli_field boardname "$current_version"
}

case "$image_url" in
	http*://*)
		# HTTP URLs are assumed to be raw images in order to maintain backward
		# compatibility.
		curl -s "${image_url//<REVISION>/$current_version}"
	;;

	tcp://*)
		# TCP URLs are assumed to be BLIs.
		echo "$image_url" \
			| sed -n 's|^tcp://\(.\+\):\([^:]\+\)$|\1 \2|p' \
			| xargs nc \
			| extract_and_check_bli
	;;

	/*.bli)
		# Local files with a .bli extension are assumed to be BLIs.
		extract_and_check_bli <"$image_url"
	;;

	/*)
		# All other local files are assumed to be raw images.
		cat "$image_url"
	;;

	*)
		# All other URLs are not supported.
		false
	;;
esac
