#!/bin/sh
# status 0 = Dumaos disabled
# status 1 = Dumaos up and running
# status 2 = Dumaos temporarely paused
# status 3 = Dumaos starting
# status 4 = Invalid status

STATUS=0
UCI_DUMAOS_STATUS=$(uci get dumaos.tr69.dumaos_enabled)
PARAM_NOT_FOUND=$?
SM_DUMAOS_STATUS=$(cat /var/run/dumaos-status 2> /dev/null)
FILE_NOT_FOUND=$?


if [ "$PARAM_NOT_FOUND" = "0" ] && [ "$FILE_NOT_FOUND" = "0" ]; then
  if [ "$UCI_DUMAOS_STATUS" = "1" ]; then
    if [ "$SM_DUMAOS_STATUS" = "starting" ]; then
      STATUS=3
    elif [ "$SM_DUMAOS_STATUS" = "stopped" ] || [ "$SM_DUMAOS_STATUS" = "stopping" ]; then
      STATUS=2
    elif [ "$SM_DUMAOS_STATUS" = "running" ]; then
      STATUS=1
    else
      echo 4
      exit 1
    fi
  fi
fi

echo $STATUS
exit 0
