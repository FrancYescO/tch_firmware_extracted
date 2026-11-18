#!/bin/sh

# This script is a wrapper around the ubus wireless.radio.caldata object

# To parse ubus output
. /usr/share/libubox/jshn.sh

print_help ()
{
  echo "wireless_caldata.sh -r radio -c cmd -p param"
  echo "  -r radio : radio_2G or radio_5G (optional)"
  echo "  -c cmd   : init, set, get, dump, reset, store, lock"
  echo "  -p param : set: offset=value; get: offset"

  exit 1
}

RADIO=radio_2G

for i in x x x  # at most 3 '-' type arguments
do
  case "$1" in
    -r) RADIO=$2;
        shift;
        shift;;
    -c) CMD=$2;
        shift;
        shift;;
    -p) PARAM=$2
        shift;
        shift;;
    -*) print_help;;
  esac
done

#Validate input
if [ -z $CMD ] ; then
  print_help
fi

OK=0
if [ "$CMD" = "init" ] || [ "$CMD" = "reset" ] || [ "$CMD" = "store" ] || [ "$CMD" = "lock" ] || [ "$CMD" = "dump" ]; then
  OK=1
fi

if [ "$CMD" = "set" ] || [ "$CMD" = "get" ] ; then
  if [ ! -z $PARAM ] ; then
    OK=1
  fi
fi

if [ "$OK" = "0" ] ; then
  print_help
fi

#Create ubus command
json_init
json_add_string name "$RADIO"
if [ ! -z $PARAM ] ; then
  json_add_string param "$PARAM"
fi

UBUS_CMD="ubus -S call wireless.radio.caldata $CMD '$(json_dump)'"

OUTPUT=$(eval $UBUS_CMD)

if [ "$?" != "0" ] ; then
  echo Syntax error
  exit 1
fi

#Using the json script does not work (because of /r/n??)
#json_load "$OUTPUT"
#json_get_var RESULT result
#Use SED in place
OUTPUT=`echo "$OUTPUT" | sed 's/{\"result\":\"//'`
OUTPUT=`echo "$OUTPUT" | sed 's/\"}//`

printf "$OUTPUT"
