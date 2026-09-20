#!/bin/sh

VENDOR=$(cat '/dumaossystem/vendor')

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
