#!/bin/sh

enabled=$(uci get system.acotel.enabled)

if [ $enabled == "1" ]; then
  . /lib/functions/run_main.sh &
else
  [ -f /tmp/acotel/agent.pid ] && read agentpid < /tmp/acotel/agent.pid

  if [ ! -z "$agentpid" ]; then
    agentpid=$(ps | grep "$agentpid" | grep -v grep | awk '{print $1}')
    [[ -z $agentpid ]] && exit;
    kill -9 $agentpid
    rm -f /tmp/acotel/agent.pid
  fi
fi
