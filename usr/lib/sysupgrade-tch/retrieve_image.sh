#!/bin/sh

case "$1" in
	ftp://*) exec wget -O- -q -T 300 "$1" ;;
	http://*) exec curl -f --connect-timeout 900 -m 1800 -S -s --anyauth "$1" ;;
	https://*) exec curl -f --insecure --connect-timeout 900 -m 1800 -S -s --capath /etc/ssl/cwmp "$1" ;;
	tftp://*) exec curl -f --connect-timeout 300 -m 1800 -S -s "$1" ;;
	*) exec cat "$1" ;;
esac
