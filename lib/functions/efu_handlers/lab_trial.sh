#!/bin/sh

action="${1}"
previous_pw_file=/etc/efu_handler/state_before_unlock/lab_trial.locked

mkdir -p $(dirname ${previous_pw_file})

. /lib/functions/provision.sh

config="clash"

user_exists_in_efu_file() {
  grep -qs "^USER=${1}####GID" "${previous_pw_file}"
}

# Change the user's password to GAK 1
change_password_to_gak1() {
  local usr="${1}"

  user_exists_in_efu_file "${usr}"
  local previously_unlocked=$?

  if [[ $previously_unlocked -eq 0 ]]; then
    # Nothing to do, already unlocked
    return 0
  fi

  local gid=$(uci get -q ${config}.$usr.gak_id)
  if [[ "$gid" = "1" ]]; then
    # User already has gak_id 1 configured, nothing to do
    return 0
  fi

  # Change the configured Clash GAK to 1
  uci set -q ${config}.$usr.gak_id=1
  uci commit ${config}

  # Track the old GAK and/or the old password
  echo "USER=${usr}####GID=${gid}####$(cat /etc/shadow | grep -s ""^${1}:"" | cut -d ':' -f 2-)" >> "${previous_pw_file}"

  user_exists "${usr}"
  local exists=$?

  # If the user already exists, change the password
  if [[ $exists -eq 0 ]]; then
    local key=$(get_access_key 1)
    set_pass "$usr" "$key" > /dev/null 2>&1
  fi
}

reset_password() {
  local usr="${1}"
  user_exists_in_efu_file "${usr}"
  local previously_unlocked=$?

  if [[ $previously_unlocked -eq 0 ]]; then
    # We've made changes during lab_trial unlocking for this user, revert them
    local old_pw=$(sed -n 's|^USER=\(.*\)####GID=\(.*\)####\(.*\)$|\3|p' "${previous_pw_file}")
    local gid=$(sed -n "s|^USER=${usr}####GID=\(.*\)####\(.*\)$|\1|p" "${previous_pw_file}")
    if [[ -n "${gid}" ]]; then
      # We've recorded a previous gak_id, put it back.
      uci set -q ${config}.$usr.gak_id=${gid}
      uci commit ${config}  
    fi
    if [[ -n "${old_pw}" ]]; then
      # We've recorded a previous password, this takes precedence over a recorded GAK
      sed -i "s|${usr}:.*|${usr}:${old_pw}|g" /etc/shadow
    elif [[ -n "${gid}" ]]; then
      # We only recorded a GAK, use it to restore the password
      local key=$(get_access_key ${gid})
      set_pass "$usr" "$key" > /dev/null 2>&1
    fi
    sed -i "/USER=${usr}####/d" ${previous_pw_file}
  fi
}

if [ "${action}" = "unlock" ]; then
  config_load "${config}"
  config_foreach change_password_to_gak1 user
elif [ "${action}" = "lock" ]; then
  config_load "${config}"
  config_foreach reset_password user
fi
chmod 0644 /etc/config/clash
