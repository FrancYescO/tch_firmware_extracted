#!/bin/sh
  /etc/init.d/nanocdn restart
enabled=$(uci get system.mabr.enabled)
if [ $enabled == "0" ]; then
  rm -f /tmp/minSession
  rm -f /tmp/maxSession
  rm -f /tmp/minBitRate
  rm -f /tmp/maxBitRate
else
  /usr/bin/nanocdnMinMax.lua &
fi
