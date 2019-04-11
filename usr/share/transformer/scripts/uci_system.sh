#!/bin/sh
# Copyright (c) 2013 Technicolor
tz=`uci get system.@system[0].timezone`
[ -n "${tz}" ] && echo "$tz" > /tmp/TZ
zonename=`uci get system.@system[0].zonename`
[ -n "$zonename" ] && [ -f "/usr/share/zoneinfo/$zonename" ] && rm -f /tmp/localtime && ln -s "/usr/share/zoneinfo/$zonename" /tmp/localtime
date -k
