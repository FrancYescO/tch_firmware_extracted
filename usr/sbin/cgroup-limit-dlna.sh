#!/bin/ash

 # set -x

CGROUP_MINIDLNA="/cgroups/cpumemblk/minidlna_cgroup/"
CGROUP_MEMLIMIT_FILE="memory.limit_in_bytes"
CGROUP_MEMLIMIT="80M"

if [ -d $CGROUP_MINIDLNA ];
then
  # Set minidlna cgroup memory limitation
  echo $CGROUP_MEMLIMIT > $CGROUP_MINIDLNA$CGROUP_MEMLIMIT_FILE
  cat $CGROUP_MINIDLNA$CGROUP_MEMLIMIT_FILE > /tmp/memlimit

fi
