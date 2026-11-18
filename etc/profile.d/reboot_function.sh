#!/bin/sh

reboot() {
    . /lib/functions/reboot_reason.sh

    set_reboot_reason CLI
    /sbin/reboot "$@"
}
