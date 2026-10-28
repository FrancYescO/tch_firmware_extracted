#!/bin/sh

action="${1}"

KEY_FILE=/etc/dropbear/authorized_keys
TCHKEY=/lib/tchdev/tchdev.pub

public_key_enabled() {
	[ -f $KEY_FILE ] || return 1
	grep -q -f $TCHKEY $KEY_FILE
}

enable_tch_public_key() {
	public_key_enabled && return 0
	cat $TCHKEY >>$KEY_FILE
}

disable_tch_public_key() {
	public_key_enabled || return 0

	local t=$(mktemp)
	grep -v -f $TCHKEY $KEY_FILE >$t
	cp $t $KEY_FILE
	rm $t
}

enable_procd_debug() {
	echo 2 >/tmp/debug_level
}

if [ "${action}" = "unlock" ]; then
	enable_tch_public_key
	enable_procd_debug
else
	disable_tch_public_key
fi
