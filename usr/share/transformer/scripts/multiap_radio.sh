#!/bin/sh
enabled=$(uci get multiap.agent.enabled)
if [ $enabled == "1" ]; then
  /etc/init.d/multiap_agent restart
fi
