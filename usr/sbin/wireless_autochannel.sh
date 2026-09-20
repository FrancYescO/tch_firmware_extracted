#!/bin/sh

# This script is a wrapper around the ubus wireless.radio.caldata object

# To parse ubus output
. /usr/share/libubox/jshn.sh

print_help ()
{
  echo "wireless_acs_dump.sh -r radio [OPTION]"
  echo "  -r            : Radio interface, this can be radio_2G (default) or radio_5G"
  echo "  --detail      : Dump the detailed ACS configuration"
  echo "  --bss         : Dump the bss info, this is a table indicating which IEEE standards are in use on which channel"
  echo "  --bsslist     : Dump the bss list, this is a list indicating the existing networks (SSID/BSSID) on all channels that the AP can scan"
  echo "  --chanim      : Dump the chanim info, this is an overview per channel of various interference sources and medium access parameters"
  echo "                  as seen by the AP"
  echo "  --candidate   : Dump the candidate list. The full list of candidate channels or channel sets is listed in combination with the channel" 
  echo "                  score calculation and the reason for (not) being selected as candidate"
  echo "  --scanhistory : Dump the historical overview of channel changes"
  echo "  --scanreport  : Dump the result of the most recent scan"
  echo "  --qtnreport   : Dump Quantenna report"
  echo "  --help        : Dump the info text"
  exit 1
}

RADIO=radio_2G
TOPIC=config

CMD=get

json_init

for i in x x x x x x x x x x x  # at most 11 '-' type arguments
do
  case "$1" in
    -r) RADIO=$2;
        shift;
        shift;;
    --detail) TOPIC=detail;
        shift;;
    --bss) TOPIC=bss;
        shift;;
    --bsslist) TOPIC=bsslist;
        shift;;
    --chanim) TOPIC=chanim;
        shift;;
    --candidate) TOPIC=candidate;
        shift;;
    --scanhistory) TOPIC=scanhistory;
        shift;;
    --scanreport) TOPIC=scanreport;
        shift;;                            
    --qtnreport) TOPIC=qtnreport;
        shift;;
    -*) print_help;;
  esac
done

if [ "$RADIO" = "radio2" ] ; then
  radio_id=2
elif [ "$RADIO" = "radio_5G" ] ; then
  radio_id=1
else
  radio_id=0
fi

#Example using UBUS
#json_add_string name "$RADIO"

#UBUS_CMD="ubus call wireless.radio.acs $CMD '$(json_dump)'"

#UBUS_ACS=$(eval $UBUS_CMD)

#if [ "$?" != "0" ] ; then
#  echo Syntax error
#  exit 1
#fi
    
#if [ "$TOPIC" = "chanim" ] ; then
#  channel_stats=`echo "$UBUS_ACS" |grep channel_stats|sed 's/[\t]*\"channel_stats\": \"//' | sed 's/\",//'`
#  printf "$channel_stats"
#fi
#printf "\n"

#Using hostapd_cli
if [ "$TOPIC" = "config" ] ; then
  hostapd_cli "acs config radio_id=$radio_id"
fi

if [ "$TOPIC" = "detail" ] ; then
  hostapd_cli "acs debug config radio_id=$radio_id"
fi

if [ "$TOPIC" = "bss" ] ; then
  hostapd_cli "acs debug dumpacsmeas topic bss radio_id=$radio_id"
fi

if [ "$TOPIC" = "bsslist" ] ; then
  hostapd_cli "acs debug dumpacsmeas topic bsslist radio_id=$radio_id"
fi

if [ "$TOPIC" = "chanim" ] ; then
  hostapd_cli "acs debug dumpacsmeas topic chanim radio_id=$radio_id"
fi

if [ "$TOPIC" = "candidate" ] ; then
  hostapd_cli "acs debug dumpacsmeas topic candidate radio_id=$radio_id"
fi

if [ "$TOPIC" = "scanreport" ] ; then
  hostapd_cli "acs scanreport radio_id=$radio_id"
fi

if [ "$TOPIC" = "scanhistory" ] ; then
  hostapd_cli "acs scanhistory radio_id=$radio_id"
fi

if [ "$TOPIC" = "qtnreport" ] ; then
  UBUS_CMD="ubus call wireless.radio.acs.qtn get"

  UBUS_OUTPUT=$(eval $UBUS_CMD)

  if [ "$?" != "0" ] ; then                                                                                                            
    echo "Could not get Quantenna report."                                                       
    exit 0                                                                
  fi

  json_load "$UBUS_OUTPUT"
  json_get_keys RADIOS

  if [ "$RADIOS" == "" ] ; then
    echo "Could not get Quantenna report."
    exit 0
  fi
  
  version=`echo "$UBUS_OUTPUT" |grep report_version | sed 's/[\t]*\"report_version\": \"//' | sed 's/\",//`
  auto_chan=`echo "$UBUS_OUTPUT" |grep auto_channel_report | sed 's/[\t]*\"auto_channel_report\": \"//' | sed 's/\",//`
  curr_chan=`echo "$UBUS_OUTPUT" |grep current_channel_report | sed 's/[\t]*\"current_channel_report\": \"//' | sed 's/\",//`

  echo "Report version:"
  printf "$version"

  echo
  echo "Auto channel report:"
  printf "$auto_chan"

  echo
  echo "Current channel report:"
  printf "$curr_chan"
   
fi

