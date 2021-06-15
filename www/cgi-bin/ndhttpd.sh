#!/bin/sh

REALM="ND3"
NDHTTPD_BIN="/usr/sbin/ndhttpd"
if [ "$(cat /dumaossystem/model)" = "LH1000" -o "$(cat /dumaossystem/model)" = "DJA0231" ];then
  SERVER_PORT="81"
else
  SERVER_PORT="80"
fi	
if [ -f /tmp/sysinfo/board_name ]; then
  DEPENDENT_PARAMS="-u"
fi

if [ "$(cat /dumaossystem/model)" = "XR500" ]; then
  EXTRA_ARGS="-C /etc/ndhttpd.crt -K /etc/ndhttpd.key -s 0.0.0.0:443"
fi

ndhttpd_stop()
{
	# Wait till we know all ndhttpd processes are killed
	while [ "$(pidof ndhttpd)" ]; do
		killall -9 ndhttpd
		sleep 1
	done
}

ndhttpd_start()
{
	if [ "$(ps ww | grep "url-routing.lua" | grep -v grep | wc -l)" -lt 1 ];then
		$NDHTTPD_BIN $DEPENDENT_PARAMS -D -I ndindex.html -h /www -r ${REALM} -x /cgi-bin -l /apps -L /www/cgi-bin/url-routing.lua -t 80 -p 0.0.0.0:$SERVER_PORT $EXTRA_ARGS
	fi
	SET_PR=$(pgrep "$NDHTTPD_BIN" -l | cut -d' ' -f1)
        chrt -o -p 0 $SET_PR
}

case "$1" in
	stop)
		ndhttpd_stop
	;;
	start)
		ndhttpd_start
	;;
	restart)
		ndhttpd_stop
		ndhttpd_start
	;;
	*)
		logger -- "usage: $0 start|stop|restart"
	;;
esac
