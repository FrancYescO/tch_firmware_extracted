#!/bin/sh

if [ "$1" = "UpTime" ]; then
	IFS=. read uptime _ < /proc/uptime
	echo "$uptime"
elif [ "$1" = "CurrentLocalTime" ]; then
	clt=`date +%FT%T%z`
	first=${clt%??}
	last=${clt#$first}
	echo "$first:$last"
fi

exit 0
