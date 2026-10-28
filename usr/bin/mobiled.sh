#!/bin/sh

TRACELEVEL=$(uci -q get mobiled.globals.tracelevel)
if [ -n "$TRACELEVEL" -a $TRACELEVEL -gt 5 ]; then
	exec "/usr/bin/mobiled" > /var/log/mobiled.log 2>&1
else
	exec "/usr/bin/mobiled" 2> /var/log/mobiled.log
fi
