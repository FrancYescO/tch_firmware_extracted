#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handler for REBOOT query
#

logger -t "cm" -p 7 "Reboot"
cmclient STOP
reboot
exit 0
