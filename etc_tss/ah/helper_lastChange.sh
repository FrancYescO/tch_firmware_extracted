#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handlers - helper functions to evaluate status LastChange parameters
#

# Establishes and prints value of lastChange property of given object to stdout.
# Input:
# $1 = object in DM
help_lastChange_get() {
	local uptime lastChange
	# Retrieve timestamp of the last status change
	lastChange=$(cmclient GETV "$1.X_ADB_LastChange")
	# Read current timestamp
	IFS=. read -r uptime _ < /proc/uptime
	# Calculate difference between timestamps, or simply return device uptime if the object hasn't changed status yet
	[ -n "$lastChange" ] && lastChange=$((uptime - lastChange)) || lastChange=$(cmclient GETV Device.DeviceInfo.UpTime)
	# Provide result
	echo $lastChange
}

# Stores current timestamp as a reference for computing value of lastChange.
# Call this function when object changes its status.
# Input:
# $1 = object in DM
help_lastChange_set() {
	local uptime
	# Read current timestamp
	IFS=. read -r uptime _ < /proc/uptime
	# Store timestamp inside X_ADB_LastChange property of the object
	cmclient SETE "$1.X_ADB_LastChange" $uptime
}
