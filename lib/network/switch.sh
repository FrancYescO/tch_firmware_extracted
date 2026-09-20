#!/bin/sh

setup_switch() {
	[ -d "/sys/class/net/bcmsw" ] || return

	bcmswconfig reset
	bcmswconfig load network
}
