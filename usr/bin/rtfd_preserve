#!/bin/sh

CFG=/etc/rtfd_persistent_filelist.conf
SCRIPT=

preserve() {
  local path=$1
  local value=$(uci get $path 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "restore $path $value" >> /etc/rtfd/data/ucidata
  fi
}

persist_file() {
  local f=${1:-$SCRIPT}
  if [ $(grep -c ^$f $CFG) -eq 0 ]; then
    echo $f >>$CFG
  fi
}

for s in /etc/rtfd/scripts/*; do
  if [ -x $s ]; then
    $s
  else
    SCRIPT=s
    . $s
  fi
done

for f in /etc/rtfd/data/*; do
  persist_file $f
done
