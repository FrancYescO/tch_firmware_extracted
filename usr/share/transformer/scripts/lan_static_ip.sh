#!/bin/sh
# Copyright (c) 2016 Technicolor

local cmd
cmd="ifconfig br-lan:0"
if [ -f /tmp/.lanStaticIP ]; then
  $cmd $(cat /tmp/.lanStaticIP)
fi
rm /tmp/.lanStaticIP
