#!/bin/sh

REALM="ND3"

if [ -d "/media/dumaos_output/dumaossystem" ];then
  BASEDIR="/media/dumaos_output/"
else
  BASEDIR="/"
fi
  WEBROOT="$BASEDIR/www"
  URLROUTE="$BASEDIR/www/cgi-bin/url-routing.lua"
  NDHTTPD_BIN="$BASEDIR/usr/sbin/ndhttpd"

if [ "$(cat $BASEDIR/dumaossystem/model)" = "LH1000" -o "$(cat $BASEDIR/dumaossystem/odm)" = "TECHNICOLOR" -o "$(cat $BASEDIR/dumaossystem/model)" = "XB7" -o "$(cat $BASEDIR/dumaossystem/model)" = "SMARTHUB3" -o "$(cat $BASEDIR/dumaossystem/model)" = "XRE1200" -o "$(cat $BASEDIR/dumaossystem/model)" = "RPI3" ];then
  SERVER_PORT="81"
else
  SERVER_PORT="80"
fi
if [ "$(cat $BASEDIR/dumaossystem/odm)" = "SEAL" ]; then
	SERVER_PORT="$SEAL_PORT"
fi

if [ "$SERVER_PORT" != "80" ]; then
	SERVER_ACCESS=" -p localhost:$SERVER_PORT -p [::1]:$SERVER_PORT "
else
	SERVER_ACCESS=" -p 0.0.0.0:$SERVER_PORT -p [::]:$SERVER_PORT "
fi

if [ -f /tmp/sysinfo/board_name ]; then
  DEPENDENT_PARAMS="-u"
fi

if [ -f "/etc/ndhttpd.crt" ]; then
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
		$NDHTTPD_BIN $DEPENDENT_PARAMS -D -I ndindex.html -h $WEBROOT -r ${REALM} -x /cgi-bin -l /apps -L $URLROUTE -t 80 $SERVER_ACCESS $EXTRA_ARGS
	fi
  if [ "$(cat $BASEDIR/dumaossystem/model)" = "LH1000" ];then
    SET_PR=$(pgrep "$NDHTTPD_BIN" -l | cut -d' ' -f1)
    chrt -o -p 0 $SET_PR
  fi
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
