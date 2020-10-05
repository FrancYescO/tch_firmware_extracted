#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handler for RESET query
#

CFG_DIRS="/etc/cm/main /etc/cm/notify /etc/cwmp"

logger -t "cm" -p 4 "Reset to default configuration"
cmclient STOP
rm -rf $CFG_DIRS
exit 0
