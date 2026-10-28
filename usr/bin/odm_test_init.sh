#!/bin/sh

#Do everything needed to bring board in correct state for ODM tests

if [ -e "/usr/sbin/wireless_odm_test_init.sh" ] ; then
  /usr/sbin/wireless_odm_test_init.sh
fi
