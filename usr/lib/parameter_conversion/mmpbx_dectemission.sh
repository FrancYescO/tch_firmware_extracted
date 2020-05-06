#! /bin/sh
# Copyright (c) 2016 Technicolor

emission=$(uci get mmpbx.dectemission.state)
if [ "$emission" = 0 ]
then
mkdir /etc/config/emission_bkup
mkdir /etc/config/emission_bkup/etc
mkdir /etc/config/emission_bkup/etc/config
cp /etc/config/mmpbxbrcmdectdev /etc/config/emission_bkup/etc/config/mmpbxbrcmdectdev
cp /etc/config/mmpbx /etc/config/emission_bkup/etc/config/mmpbx
rm /etc/config/mmpbxbrcmdectdev
/usr/bin/lua /usr/lib/lua/tch/mmpbxdect_backup.lua $emission
else
mkdir /etc/config/emission_restore
mkdir /etc/config/emission_restore/etc
mkdir /etc/config/emission_restore/etc/config
cp /etc/config/mmpbx /etc/config/emission_restore/etc/config/mmpbx
if [ -d "/etc/config/emission_bkup" ]; then
  /usr/lib/parameter_conversion/parameter_conversion.sh "/etc/config/emission_bkup" "/etc/config/emission_restore" /etc/parameter_conversion/conversion_dectemission
  cp /etc/config/emission_restore/etc/config/mmpbx /etc/config/mmpbx
  cp /etc/config/emission_bkup/etc/config/mmpbxbrcmdectdev /etc/config/mmpbxbrcmdectdev
  rm -rf /etc/config/emission_restore
  rm -rf /etc/config/emission_bkup
else
  board=$(uci get env.var.hardware_version)
  /usr/lib/parameter_conversion/parameter_conversion.sh /rom/etc/boards/$board/config/ "/etc/config/emission_restore" /etc/parameter_conversion/conversion_dectemission
  cp /etc/config/emission_restore/etc/config/mmpbx /etc/config/mmpbx
  cp /rom/etc/boards/$board/config/etc/config/mmpbxbrcmdectdev /etc/config/mmpbxbrcmdectdev
  rm -rf /etc/config/emission_restore
fi
maxprofile=7
for var in `seq 0 $maxprofile`
do
        filename="/etc/config/mmpbx"
        if (egrep -wl sip_profile_$var "$filename" 1>/dev/null); then
           filename1="/etc/config/mmpbxrvsipnet"
           if !(egrep -wl sip_profile_$var "$filename1" 1>/dev/null); then
		/usr/bin/lua /usr/lib/lua/tch/mmpbxdect_backup.lua $emission sip_profile_$var
           fi
        fi
done
fi
