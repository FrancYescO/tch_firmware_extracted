#!/bin/sh

case "$1" in
	start)
		echo "Starting wanconf..."
		/bin/wanconf
		exit 0
		;;

	stop)
		echo "Stopping wancof..."
		exit 0
		;;

	*)
		echo "Starting wanconf with no args..."
		/bin/wanconf
		exit 1
		;;

esac

