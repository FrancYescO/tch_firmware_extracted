#!/bin/sh
filePath="$1"
#local limit=`uci -q get toolbox.PacketCapture.countervalue`

while :
do
  capturedBytes=`wc -c "$filePath" | awk '{print $1}'`
  # Convert bytes to mb and compare
  result=`echo $(($capturedBytes / 10000000))`
  if [ ${result} ]; then
    tcpdumpPid=`ps w | grep "tcpdump" | grep "$filePath" | awk '{print $1}'`
    kill -9 $tcpdumpPid
    break
  fi
  sleep 0.25
done

return 1

