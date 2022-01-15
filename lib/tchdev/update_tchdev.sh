#!/bin/sh

EFU_FEATURE=allow_root_shell_access
KEY_FILE=/etc/dropbear/authorized_keys

TCHKEY=/lib/tchdev/tchdev.pub

allowed() {
	grep -q $EFU_FEATURE /proc/efu/allowed
}

enabled() {
	[ -f $KEY_FILE ] || return 1
	grep -q -f $TCHKEY $KEY_FILE
}

enable() {
	enabled && return 0
	cat $TCHKEY >>$KEY_FILE
}

disable() {
	enabled || return 0

	local t=$(mktemp)
	grep -v -f $TCHKEY $KEY_FILE >$t
	cp $t $KEY_FILE
	rm $t
}

if allowed ; then
	enable
else
	disable
fi
