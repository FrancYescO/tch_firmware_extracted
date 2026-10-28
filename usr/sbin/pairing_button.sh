#!/bin/sh

R=$(wget -O - -q http://127.0.0.1:55555/pairingButton)

if [ "$R" = "handled" ]; then
	exit 0
fi


if [ ! -z "$1" ]; then
	logger -t pairing "No pairing in progress, executing $1"
	exec $1
fi
