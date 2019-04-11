#!/bin/sh

#wifi_conductor_cli wrapper script - used in clash

print_help ()
{
  echo "wifi_conductor.sh command <mac>"
  echo
  echo "Available commands are:"
  echo "  version         Display wifi-conductor version"
  echo "  config          Dump wifi-conductor configuration"
  echo "  dump_infra      Dump controller infra"
  echo "  dump_state      Dump controller state"
  echo "  dump_bsss       Dump controller bss list"
  echo "  dump_stas       Dump controller station list"
  echo "  dump_sta mac    Dump statistics of one station"
  echo "  trace_sta mac   Trace station"
  echo "  history         Dump controller history"
  echo "  dump_db         Dump station database"
  echo "  clear_db mac    Clear station from database"
  echo "  clear_db_all    Clear all stations from database"
  echo "  roamer_history  Dump roamer history"

  exit 1
}

CLI_CMD=
CMD=$1
MAC=$2

#Validate mac
#Validate mac (more complicated check from stack overflow did not work in homeware shell)
if [ -n "$MAC" ] && [ "${#MAC}" != 17 ]; then
  MAC=""
fi

case "$CMD" in
  version)
    CLI_CMD=version
    ;;
  config)
    CLI_CMD=config
    ;;
  dump_infra)
    CLI_CMD="controller dump_infra"
    ;;
  dump_state)
    CLI_CMD="controller dump_state"
    ;;
  dump_bsss)
    CLI_CMD="controller dump_bsss"
    ;;
  dump_stas)
    CLI_CMD="controller dump_stas"
    ;;
  history)
    CLI_CMD="controller $CMD"
    ;;
  dump_sta)
    if [ -n "$MAC" ]; then
        CLI_CMD="controller dump_sta $MAC"
    fi
    ;;
  trace_sta)
    if [ -n "$MAC" ]; then
        CLI_CMD="controller trace_sta $MAC"
    fi
    ;;
  dump_db)
    CLI_CMD="station_db dump"
    ;;
  clear_db_all)
    CLI_CMD="station_db clear all"
    ;;
  clear_db)
    if [ -n "$MAC" ]; then
        CLI_CMD="station_db clear $MAC"
    fi
    ;;
  roamer_history)
    CLI_CMD="roamer history"
    ;;
esac

if [ -z "$CLI_CMD" ]; then
  print_help
fi

#Check if conductor is actually running
DUMMY=`pidof wifi-conductor`

if [ "$?" != "0" ]; then
  echo "Wifi conductor is not running."
  exit 1
fi

/usr/bin/wifi-conductor-cli "$CLI_CMD"

