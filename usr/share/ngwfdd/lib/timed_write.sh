#!/bin/sh

timed_exec()
{
   PID=$1
   WAIT_TIME=$2

   sleep ${WAIT_TIME}
   kill -9 ${PID}
}

IN_FILE=$1
OUT_FILE=$2

cat ${IN_FILE} > ${OUT_FILE}  &
BACK_GROUND_PID=$!
timed_exec ${BACK_GROUND_PID} 1 &
TIMER_PID=$!

wait ${BACK_GROUND_PID} > /dev/null

kill -9 ${TIMER_PID} 2> /dev/null

