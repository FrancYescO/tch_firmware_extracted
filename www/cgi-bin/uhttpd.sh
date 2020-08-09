#!/bin/sh

REALM="netdumar2"
UHTTPD_BIN="/usr/sbin/uhttpd"

if [ -f /tmp/sysinfo/board_name ]; then
  DEPENDENT_PARAMS="-u"
fi

uhttpd_stop()
{
	# Wait till we know all uhttpd processes are killed
	while [ "$(pidof uhttpd)" ]; do
		killall -9 uhttpd
		sleep 1
	done
}

uhttpd_start()
{
	if [ "$(ps ww | grep "url-routing.lua" | grep -v grep | wc -l)" -lt 1 ];then
        	$UHTTPD_BIN $DEPENDENT_PARAMS -D -I ndindex.html -h /www -r ${REALM} -x /cgi-bin -l /apps -L /www/cgi-bin/url-routing.lua -t 40 -p 0.0.0.0:81
	fi
}

case "$1" in
	stop)
		uhttpd_stop
	;;
	start)
		uhttpd_start
	;;
	restart)
		uhttpd_stop
		uhttpd_start
	;;
	*)
		logger -- "usage: $0 start|stop|restart"
	;;
esac
