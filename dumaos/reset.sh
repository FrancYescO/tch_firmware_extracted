#!/bin/sh
#-- @depends procmanager
#-- @test test -e /etc/init.d/dumaos
/etc/init.d/dumaos stop

#-- @depends sleep
#-- @test sleep 0
sleep 3

/dumaos/data_reset.sh

if [ "$(cat /dumaossystem/model)" = "LH1000" ];then
sleep 3
reboot
fi
