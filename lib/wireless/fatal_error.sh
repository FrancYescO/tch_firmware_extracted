#!/bin/sh
logger -p crit $1
echo $1 > /dev/console

REBOOT=`uci get wireless.global.reboot_on_fatal_error`

if [ "$?" != "0" ] || [ "$REBOOT" != "0" ] ; then
  logger -p crit "REBOOTING BOARD"
  echo "REBOOTING BOARD" > /dev/console

  sleep 15

  #Reboot with reason...
  boot_srr UERR

fi
