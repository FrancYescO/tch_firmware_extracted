#!/bin/ash

 # set -x

CGROUP_MINIDLNA="/cgroups/cpumemblk/minidlna_cgroup/"
CGROUP_MEMLIMIT_FILE="memory.limit_in_bytes"
CGROUP_MEMLIMIT="40M"
CGROUP_BLKIOLIMIT_FILE="blkio.throttle.read_bps_device"
CGROUP_BLKIOLIMIT="12582912"

if [ -d $CGROUP_MINIDLNA ];
then
  # Set minidlna cgroup memory limitation
  echo $CGROUP_MEMLIMIT > $CGROUP_MINIDLNA$CGROUP_MEMLIMIT_FILE
  cat $CGROUP_MINIDLNA$CGROUP_MEMLIMIT_FILE > /tmp/memlimit

  # Set minidlna cgroup blkio limitation for each usb block device
  for i in /dev/sd[a-z];
  do
    major=`ls -al $i | awk '/brw/{ print substr($5, 1, length($5)-1) }'`
    minor=`ls -al $i | awk '/brw/{ print $6 }'`
    echo "$major:$minor $CGROUP_BLKIOLIMIT" > $CGROUP_MINIDLNA$CGROUP_BLKIOLIMIT_FILE
    cat $CGROUP_MINIDLNA$CGROUP_BLKIOLIMIT_FILE > /tmp/blkiolimit
  done
fi
