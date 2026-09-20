#!/bin/sh

# DumaOS shell helper library

if [ -f "/lib/functions.sh" ] && [ -f "/lib/config/uci.sh" ];then
  . /lib/functions.sh
else
  . /dumaos/api/libs/shell/uci.sh
fi

# All global variables to go here
export_global_variables(){
  export dumaos_status_lfile="/var/run/dumaos-status"
  export MODEL="$(cat /dumaossystem/model 2>/dev/null)"
  export VENDOR="$(cat /dumaossystem/vendor 2>/dev/null)"
  export ODM="$(cat /dumaossystem/odm 2>/dev/null)"
  export SDK="$(cat /dumaossystem/sdk 2>/dev/null)"
  export CHIPSET="$(cat /dumaossystem/chipset 2>/dev/null)"
  export DUMAOS_VERSION="$(cat /dumaossystem/version 2>/dev/null)"
}
export_global_variables

# Generate DumaOS uci parameters
generate_dumaos_config(){
if [ ! -e "/etc/config/dumaos" ];then
  touch /etc/config/dumaos
fi
uci set dumaos.tr69=tr69
uci set dumaos.tr69.dumaos_enabled=0
if [ "$(cat /dumaossystem/model)" = "LH1000" ];then
  uci set dumaos.tr69.UpstreamPlanRate=20000000
  uci set dumaos.tr69.DownstreamPlanRate=50000000
fi	
uci commit dumaos
}	

# Check lock file existence and add it if not existing
test_lock_file(){
  if [ ! -e "$dumaos_status_lfile" ];then
      touch $dumaos_status_lfile
      exec 150< $dumaos_status_lfile
      flock -x 150
      printf "stopped" > $dumaos_status_lfile
      flock -u 150
      printf "%s\n" "stopped"
  fi
    return 0
}

# Get current dumaos status
get_dumaos_status(){
  test_lock_file
  exec 150< $dumaos_status_lfile
  flock -x 150
  local status=$(cat $dumaos_status_lfile)
  flock -u 150
  printf "%s" "$status"
}

# Swap DumaOS status between old and new one
dumaos_swap_status(){
  test_lock_file

  local before_state=$1
  local after_state=$2
  exec 150< $dumaos_status_lfile  
  flock -x 150
  local old=$(cat $dumaos_status_lfile)
  if [ "$old" = "$before_state" ];then
    printf "%s" "$after_state" > $dumaos_status_lfile
  fi
  flock -u 150
  printf "%s" "$old"
}

# Change state is atomic manner
change_state(){
  test_lock_file
  local before_state=$1
  local after_state=$2
  local wait_state=$3
  
  local old_state=$(dumaos_swap_status "$before_state" "$after_state")
  while [ "$old_state" = "$wait_state" ]; do
      sleep 1
      old_state=$(dumaos_swap_status "$before_state" "$after_state")
  done

  # It was stopped we (and only we) swapped it to starting
  if [ "$old_state" = "$before_state" ]; then
      return 0		# Success!
  fi
  return 1
}
