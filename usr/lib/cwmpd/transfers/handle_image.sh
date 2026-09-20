#!/bin/sh

image_url="$1"
script_dir="$2"
uci_section="$3"
transfer_id="$4"

# In case the target tag is not set (which is also the case if the image is not
# a BLI) assume that the image is a gateway image for backward compatitbility.
target="${BLI_TAG_TARGET:-gateway}"

# Make sure the target name does not contain characters that can cause scripts
# outside the target directory to be run.
if ! echo "$target" | grep -Eqx '[A-Za-z0-9_-]+'; then
	echo "Invalid target name: $target" >&2
	exit 1
fi

executable="$script_dir/target/$target/start"
if ! [ -x "$executable" ]; then
	echo "Unknown target: $target" >&2
	exit 1
fi

uci set "$uci_section.target=$target"
uci commit

exec "$executable" "$image_url" "$script_dir" "$uci_section" "$transfer_id"
