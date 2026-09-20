#!/bin/sh

bcmvopi() { return 0; }
include /lib/network/system

network_system_start() {
	bcmvopi load
}

network_system_stop() {
	bcmvopi unload
}

network_system() {
	network_system_$1
}
