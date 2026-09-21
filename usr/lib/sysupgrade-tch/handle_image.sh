#!/bin/sh

# In case the target tag is not set (which is also the case if the image is not
# a BLI) assume that the image is a gateway image for backward compatitbility.
target="${BLI_TAG_TARGET:-gateway}"

# Make sure the target name does not contain characters that can cause scripts
# outside the target directory to be run.
if ! echo "$target" | grep -Eqx '[A-Za-z0-9_-]+'; then
	echo "Invalid target name: $target" >&2
	exit 1
fi

executable="/usr/lib/sysupgrade-tch/target/$target"
if ! [ -x "$executable" ]; then
	echo "Unknown target: $target" >&2
	exit 1
fi

exec "$executable" "$@"
