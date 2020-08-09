#!/bin/sh

FILE=/etc/wlan_feature

if [ -e $FILE ] ; then
  cat $FILE
fi
  