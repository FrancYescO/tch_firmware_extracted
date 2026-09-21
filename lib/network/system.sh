#!/bin/sh

network_system_start() { return 0; }
network_system_stop() { return 0; }

include /lib/network/system

network_system() {
	network_system_$1
}
