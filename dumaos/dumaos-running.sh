#!/bin/sh

if [ -d "/media/dumaos_output/dumaossystem" ];then
  BASEDIR="/media/dumaos_output/"
  export PATH=/media/dumaos_output/bin/:/media/dumaos_output/sbin/:/media/dumaos_output/usr/bin/:/media/dumaos_output/usr/sbin/:$PATH
else
  BASEDIR="/"
fi

VENDOR=$(cat $BASEDIR/dumaossystem/vendor)

running() {
  printf "true";
  exit 0;
}
stopped() {
  printf "false";
  exit 1;
}

#if test "$VENDOR" = "TELSTRA"
#then
#  if test "$(uci get dumaos.tr69.dumaos_started)" = "1"
#  then
#    running
#  else
#    stopped
#  fi
#else
  case $(ubus list | grep procmanager) in
    *com.netdumasoftware.procmanager*) running;;
    *) stopped;;
  esac
#fi
