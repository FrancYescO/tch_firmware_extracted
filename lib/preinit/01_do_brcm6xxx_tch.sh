#!/bin/sh

do_brcm6xxx_tch() {
	. /lib/brcm6xxx_tch.sh

	brcm6xxx_tch_detect
}

boot_hook_add preinit_main do_brcm6xxx_tch
