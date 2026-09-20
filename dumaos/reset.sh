#!/bin/sh

. /dumaos/api/libs/shell/dumaos_helper.sh

#-- @depends procmanager
#-- @test test -e /etc/init.d/dumaos
/etc/init.d/dumaos stop

#-- @depends sleep
#-- @test sleep 0
sleep 3

/dumaos/data_reset.sh

dumaos_config_reset(){
  ndconfig set DumaOS_Eula=0
  ndconfig set DumaOS_Setup_Done=0
  ndconfig set DumaOS_Web_Setup_Done=0
  ndconfig commit
  uci commit
  sync
}

nvram_configs_unset(){
input="/tmp/dumaos-nvram"
nvram show | grep -i "com.netdumasoftware" | grep -v "INSERT" | cut -d "=" -f 1 > $input
while IFS= read -r var
do
  nvram unset $var
done < "$input"
}

##########
#  main  #
##########
if [ "$MODEL" = "LH1000" ];then
sleep 3
dumaos_config_reset
mngcli commit
reboot
fi
if [ "$ODM" = "TECHNICOLOR" ];then
dumaos_config_reset
reboot
fi
if [ "$ODM" = "DNI" ];then
nvram_configs_unset
fi

if [ "$VENDOR" = "BT" ];then
  dumaos_config_reset
  sleep 5
  $(/etc/init.d/dumaos start)
fi
