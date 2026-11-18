#!/bin/sh

# This script is a wrapper around the ubus wireless.radio.caldata object

# To parse ubus output
. /usr/share/libubox/jshn.sh

print_help ()
{
  echo "wireless_txtest.sh -r radio -s state -a addr -d duration -p packetsize --ampdu ampdu --prio priority -m modulation -i rateindex --nss vhtnss -b bandwidth"
  echo "  -r      : radio name (radio_2G or radio_5G (optional))"
  echo "  -s      : state (0 or 1)"
  echo "  -a      : macaddr of client"
  echo "  -d      : duration in seconds"
  echo "  -p      : packetsize in bytes"
  echo "  --ampdu : use ampdu (0 or 1)"
  echo "  --prio  : priority (802.1d: 0 to 7)"
  echo "  -m      : modulation (auto, cck, ofdmlegacy, ofdmmcs, ofdmvhtmcs)"
  echo "  -i      : rateindex"
  echo "  --nss   : vhtnss (1 to 4)"
  echo "  -b      : bandwidth (auto, 20, 40, 80)"
  exit 1
}

RADIO=radio_2G

CMD=get

json_init

for i in x x x x x x x x x x x  # at most 11 '-' type arguments
do
  case "$1" in
    -r) RADIO=$2;
        shift;
        shift;;
    -s) json_add_int state $2;
        CMD=set
        shift;
        shift;;
    -a) json_add_string macaddr $2;
        CMD=set
        shift; 
        shift;;
    -d) json_add_int duration $2;
        CMD=set
        shift;
        shift;;
    -p) json_add_int packetsize $2;
        CMD=set
        shift; 
        shift;;
    --ampdu) json_add_int ampdu $2;
        CMD=set
        shift; 
        shift;;
    --prio) json_add_int priority $2;
        CMD=set
        shift; 
        shift;;
    -m) json_add_string modulation $2;
        CMD=set
        shift; 
        shift;;
    -i) json_add_int rateindex $2;
        CMD=set
        shift; 
        shift;;
    --nss) json_add_int vhtnss $2;
        CMD=set
        shift;
        shift;;
    -b) json_add_string bandwidth $2;
        CMD=set
        shift;
        shift;;
    -*) print_help;;
  esac
done

json_add_string name "$RADIO"

UBUS_CMD="ubus -S call wireless.radio.txtest $CMD '$(json_dump)'"

OUTPUT=$(eval $UBUS_CMD)

if [ "$?" != "0" ] ; then
  echo Syntax error
  exit 1
fi

if [ "$CMD" == "get" ] ; then
  json_load "$OUTPUT"
  json_select "$RADIO"
  json_get_vars state macaddr duration packetsize ampdu priority modulation rateindex vhtnss bandwidth rate

  echo "hwaddr    : $macaddr"
  echo "state     : $state"
  echo "duration  : $duration seconds"
  echo "packetsize: $packetsize bytes"
  echo "ampdu     : $ampdu"
  echo "priority  : $priority"
  echo "phyrate   : $modulation index $rateindex vht_nss $vhtnss bandwidth $bandwidth"
  echo "rate      : $rate kbps (1 sec / 30 sec / test)"
fi

