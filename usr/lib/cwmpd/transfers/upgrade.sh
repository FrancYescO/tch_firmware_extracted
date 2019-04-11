#!/bin/sh

. /lib/functions.sh

SCRIPT_DIR=$(dirname $0)
ERROR_FILE=$1
CONFIG=cwmp_transfer


char_encoding()
{
  lua <<EOF - $1
local name = arg[1]
local escapes = ":/?#[]@!$&'()*+;="
local function escape_char(x)
  if escapes:find(x, nil, true) then
    return ("%%%02X"):format(x:byte(1))
  else
    return x
  end
end
name =name:gsub(".", escape_char)
io.write(name)
EOF
}

get_url()
{
  local URL=$1
  local username=$2
  local password=$3

  local usrinfo=

  if [ ! -z $username ]; then
    usrinfo=$(char_encoding "$username")
  fi

  if [ ! -z $password ]; then
    password=$(char_encoding "$password")
    usrinfo="$usrinfo:$password"
  fi

  if [ ! -z $usrinfo ]; then
    local proto=$(echo $URL | awk -F// "{print \$1;}")
    local host=$(echo $URL | awk -F// "{print \$2;}")
    URL="$proto//$usrinfo@$host"
  fi

  echo $URL
}

get_uci_id()
{
  local cmdkey="$1"
  local id=$(uci show -q $CONFIG | grep ".id='$cmdkey$'" | cut -d. -f2)
  if [ $? -ne 0 ]; then
    id=
  fi
  echo $id
}

get_started()
{
  local cmdkey="$1"
  local started="no"

  local id=$(get_uci_id "$cmdkey")
  if [ ! -z $id ]; then
    started=$(uci -q get $CONFIG.$id.started)
    if [ $? -ne 0 ]; then
      started="no"
    fi
  fi
  echo $started
}

set_started()
{
  local cmdkey="$1"
  local value=$2
  local url=$3
  if [ -z $value ]; then
    value="yes"
  fi
  local id=$(get_uci_id "$cmdkey")
  if [ "$value" = "yes" ]; then
    if [ -z $id ]; then
      uci show $CONFIG >/dev/null 2>/dev/null
      if [ $? -ne 0 ]; then
        #config does not exist, create it
        lua -e "require('uci').cursor():create_config_file('$CONFIG')"
      fi
      id=$(uci add $CONFIG transfer)
      uci rename $CONFIG.$id=$id
      uci set $CONFIG.$id.id="$cmdkey"
    fi
    uci set $CONFIG.$id.started=yes
    if [ ! -z $url ]; then
      uci set $CONFIG.$id.url="$url"
    fi
    uci commit
    return
  fi
  if [ "$value" = "no" ]; then
    if [ ! -z $id ]; then
      uci delete $CONFIG.$id
      uci commit $CONFIG
    fi
    return
  fi
}

set_error()
{
  local cmdkey="$1"
  local error="$2"
  local id=$(get_uci_id "$cmdkey")
  uci set $CONFIG.$id.error="$error"
  uci commit $CONFIG
}

#sanity checks
if [ "$TRANSFER_TYPE" != "download" ]; then
  echo "supports only download, not $TRANSFER_TYPE"
  exit 1
fi

if [ -z $TRANSFER_URL ]; then
  echo "no URL specified"
  ubus send FaultMgmt.Event '{ "Source":"cwmpd", "EventType":"ACS provisioning", "ProbableCause":"Firmware upgrade error", "SpecificProblem":"no URL specified" }'

  if [ -f  /var/state/cwmpd ]; then
    local failure_count
    config_load cwmpd
    config_get failure_count cwmpd_config acs_upgrade_failures "0"
    failure_count=$(( failure_count + 1 ))
    sed -i "/cwmpd.cwmpd_config.acs_upgrade_failures/d" /var/state/cwmpd
    uci -P /var/state set cwmpd.cwmpd_config.acs_upgrade_failures="${failure_count}"
    uci -P /var/state commit cwmpd
  fi
  exit 1
fi

if [ -z $TRANSFER_ID ]; then
  #replace with something longer than 32 chars
  TRANSFER_ID="===Default==PlaceHolder==NULL==ID=="
else
  uciid=$(get_uci_id "$TRANSFER_ID")
  if [ -z $uciid ]; then
    TRANSFER_ID_DECODED=`echo $TRANSFER_ID | sed 's/../0x&\n/g' | awk '{ printf("%c",$0)}'`
    uciid=$(get_uci_id "$TRANSFER_ID_DECODED")
    if [ ! -z $uciid ]; then
      echo "FOUND matching TRANSFER_ID in DECODED form. Assuming upgraded from old build with transfer_id_space issue."
      TRANSFER_ID=$TRANSFER_ID_DECODED
    fi
  fi
fi

if [ "$TRANSFER_ACTION" = "start" ]; then
  E="0"
  STARTED=$(get_started "$TRANSFER_ID")
  if [ "$STARTED" != "yes" ]; then
    URL=$(get_url "$TRANSFER_URL" "$TRANSFER_USERNAME" "$TRANSFER_PASSWORD")
    set_started "$TRANSFER_ID" yes "$URL"
    id=$(get_uci_id "$TRANSFER_ID")
    ubus send cwmpd.transfer '{ "session": "begins", "type": "upgrade" }'

    E="$(bli_process /usr/lib/sysupgrade-tch/retrieve_image.sh "$SCRIPT_DIR/handle_image.sh" "$URL" "$SCRIPT_DIR" "$CONFIG.$id" "$TRANSFER_ID")"
    if [ -z "$E" ]; then
      E=0
    fi

    set_error "$TRANSFER_ID" "$E"
    ubus send cwmpd.transfer '{ "session": "ends", "type": "upgrade" }'
  else
    id="$(get_uci_id "$TRANSFER_ID")"
    if ! TARGET="$(uci get "$CONFIG.$id.target")"; then
      TARGET=gateway
    fi
    if ! echo "$TARGET" | grep -Eqx '[A-Za-z0-9_-]+'; then
      echo "Invalid target"
      exit 1
    fi

    GET_ERROR_PATH="$SCRIPT_DIR/target/$TARGET/get_error"
    if ! [ -x "$GET_ERROR_PATH" ]; then
      echo "Missing check_error script"
      exit 1
    fi

    STORED_ERROR="$(uci -q get "$CONFIG.$id.error")"
    if ! E="$("$GET_ERROR_PATH" "${STORED_ERROR:-0}" "$SCRIPT_DIR" "$CONFIG.$id" "$TRANSFER_ID")"; then
      echo "Unable to retrieve error"
      exit 1
    fi
  fi
  if [ "$E" != "0" ]; then
    local msg=$(echo $E | cut -d, -f2)
    echo "Upgrade error: $msg"
    if [ ! -z $ERROR_FILE ]; then
      echo $msg >$ERROR_FILE
    fi

    if [ -f  /var/state/cwmpd ]; then
      local failure_count
      config_load cwmpd
      config_get failure_count cwmpd_config acs_upgrade_failures "0"
      failure_count=$(( failure_count + 1 ))
      sed -i "/cwmpd.cwmpd_config.acs_upgrade_failures/d" /var/state/cwmpd
      uci -P /var/state set cwmpd.cwmpd_config.acs_upgrade_failures="${failure_count}"
      uci -P /var/state commit cwmpd
    fi

    ubus send FaultMgmt.Event '{ "Source":"cwmpd", "EventType":"ACS provisioning", "ProbableCause":"Firmware upgrade error", "SpecificProblem":"'"$(echo $E | cut -d, -f2)"'", "AdditionalText":"URL='"$TRANSFER_URL"'"}'
    exit 1
  fi
  ubus send FaultMgmt.Event '{ "Source":"cwmpd", "EventType":"ACS provisioning", "ProbableCause":"Firmware upgrade success", "SpecificProblem":"", "AdditionalText":"URL='"$TRANSFER_URL"'"}'

  if [ -f /var/state/cwmpd ]; then
    local upgrade_time=$(date "+%FT%TZ")
    sed -i "/cwmpd.cwmpd_config.acs_last_upgrade_time/d" /var/state/cwmpd
    uci -P /var/state set cwmpd.cwmpd_config.acs_last_upgrade_time="${upgrade_time}"
    uci -P /var/state commit cwmpd
  fi

  exit 0
fi

if [ "$TRANSFER_ACTION" = "cleanup" ]; then
  id=$(get_uci_id "$TRANSFER_ID")
  if ! TARGET="$(uci get "$CONFIG.$id.target")"; then
    TARGET=gateway
  fi
  if ! echo "$TARGET" | grep -Eqx '[A-Za-z0-9_-]+'; then
    echo "Invalid target"
    exit 1
  fi

  CLEANUP_PATH="$SCRIPT_DIR/target/$TARGET/cleanup"
  if ! [ -x "$CLEANUP_PATH" ]; then
    echo "Missing cleanup script"
    exit 1
  fi

  set_started "$TRANSFER_ID" no
  exec "$CLEANUP_PATH" "$SCRIPT_DIR" "$CONFIG.$id" "$TRANSFER_ID"
fi

echo "Unknown transfer action: $TRANSFER_ACTION"
exit 1
