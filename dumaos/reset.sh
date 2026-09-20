#!/bin/sh
#-- @depends procmanager
#-- @test test -e /etc/init.d/dumaos
/etc/init.d/dumaos stop

#-- @depends sleep
#-- @test sleep 0
sleep 3

/dumaos/data_reset.sh

dumaos_config_reset(){
  config set DumaOS_Eula=0
  config set DumaOS_Setup_Done=0
  config commit
  uci commit
  sync
}

if [ "$(cat /dumaossystem/model)" = "LH1000" ];then
sleep 3
dumaos_config_reset
mngcli commit
reboot
fi
if [ "$(cat /dumaossystem/odm)" = "TECHNICOLOR" ];then
rtfd
fi
