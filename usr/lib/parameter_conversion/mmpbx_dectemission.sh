#! /bin/sh
# Copyright (c) 2016 Technicolor

emission=$(uci get mmpbx.dectemission.state)

#  emission is 0 and DECT configuration is available: back-up has to be taken and dect config is removed

if [ "$emission" = 0 ] && [ -f "/etc/config/mmpbxdectdev" ];
then
  mkdir /etc/config/emission_bkup
  mkdir /etc/config/emission_bkup/etc
  mkdir /etc/config/emission_bkup/etc/config
  cp /etc/config/mmpbxdectdev /etc/config/emission_bkup/etc/config/mmpbxdectdev
  cp /etc/config/mmpbx /etc/config/emission_bkup/etc/config/mmpbx
  rm /etc/config/mmpbxdectdev
  /usr/bin/lua /usr/lib/lua/tch/mmpbxdect_backup.lua $emission

#  emission is 1 and DECT configuration is not available: config has to be restored from back-up
elif [ "$emission" = 1 ] && [ ! -f "/etc/config/mmpbxdectdev" ];
then
  mkdir /etc/config/emission_restore
  mkdir /etc/config/emission_restore/etc
  mkdir /etc/config/emission_restore/etc/config
  cp /etc/config/mmpbx /etc/config/emission_restore/etc/config/mmpbx
  if [ -d "/etc/config/emission_bkup" ];
  then
    /usr/lib/parameter_conversion/parameter_conversion.sh "/etc/config/emission_bkup" "/etc/config/emission_restore" /etc/parameter_conversion/conversion_dectemission
    cp /etc/config/emission_restore/etc/config/mmpbx /etc/config/mmpbx
    cp /etc/config/emission_bkup/etc/config/mmpbxdectdev /etc/config/mmpbxdectdev
    rm -rf /etc/config/emission_restore
    rm -rf /etc/config/emission_bkup
  else
    board=$(uci get env.var.hardware_version)
    /usr/lib/parameter_conversion/parameter_conversion.sh /rom/etc/boards/$board/config/ "/etc/config/emission_restore" /etc/parameter_conversion/conversion_dectemission
    cp /etc/config/emission_restore/etc/config/mmpbx /etc/config/mmpbx
    cp /rom/etc/boards/$board/config/etc/config/mmpbxdectdev /etc/config/mmpbxdectdev
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
