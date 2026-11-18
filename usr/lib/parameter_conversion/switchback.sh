#!/bin/sh

CONVERSION_FILE=/etc/parameter_conversion/switchback

if [ ! -f $CONVERSION_FILE ]; then
	echo "No conversion requested, done"
	exit
fi

TARGET_CONFIG=$1
if [ -z $TARGET_CONFIG ]; then
	BANK=$(cat /proc/banktable/notbooted)
	if [ -z $BANK ]; then
		echo "No bank to switch to, bailing out"
		exit
	fi
	TARGET_CONFIG=/overlay/$BANK
fi

if [ ! -d $TARGET_CONFIG ]; then
	echo "No config to update, done"
	exit
fi

BANK=$(cat /proc/banktable/booted)
if [ -z $BANK ]; then
	echo "No current bank, bailing out"
	exit
fi
SOURCE_CONFIG=/overlay/$BANK
if [ ! -d $SOURCE_CONFIG ]; then
	echo "This is an impossible situation, no source config"
	echo "bailing out of switchback parameter conversion"
	exit
fi

#mount the target config
mount -t overlayfs -o noatime,lowerdir=/rom,upperdir=$TARGET_CONFIG overlay $TARGET_CONFIG

# convert back
/usr/lib/parameter_conversion/parameter_conversion.sh $SOURCE_CONFIG $TARGET_CONFIG $CONVERSION_FILE

#unmount the target again
umount $TARGET_CONFIG

