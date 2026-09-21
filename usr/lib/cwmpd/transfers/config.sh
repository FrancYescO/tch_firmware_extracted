#!/bin/sh

unset CDPATH

SCRIPT=$0
if [ -L $SCRIPT ]; then
  SCRIPT=$(readlink $SCRIPT)
  # double cd needed if link is relative,
  # harmless if link is absolute
  SCRIPTDIR=$(cd $(dirname $0); cd $(dirname $SCRIPT); pwd)
else
  # if SCRIPT was not a link, we can only do one cd as the dir named in SCRIPT
  # could be relative.
  SCRIPTDIR=$(cd $(dirname $SCRIPT); pwd)
fi

CONFIG=cwmp_transfer

get_url()
{
  local URL=$1
  local username=$2
  local password=$3

  local usrinfo=
  
  if [ ! -z $username ]; then
    usrinfo=$username
  fi

  if [ ! -z $password ]; then
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

get_error()
{
  local cmdkey="$1"
  local id=$(get_uci_id "$cmdkey")
  local value=$(uci -q get $CONFIG.$id.error)
  if [ -z $value ]; then
    value="0"
  fi
  echo $value
}

get_dldir()
{
  local value=$(uci get $CONFIG.global.dlstore 2>/dev/null)
  if [ -z $value ]; then
    value="/var"
  fi
  local linkname=$(readlink -f $value)
  if [ ! -z $linkname ]; then
    value=$linkname
  fi
  echo $value
}


#sanity checks
if [ "$TRANSFER_TYPE" != "download" ]; then
  echo "supports only download, not $TRANSFER_TYPE"
  exit 1
fi

if [ -z $TRANSFER_URL ]; then
  echo "no URL specified"
  exit 1
fi
URL=$(get_url "$TRANSFER_URL" "$TRANSFER_USERNAME" "$TRANSFER_PASSWORD")

if [ -z $TRANSFER_ID ]; then
  #replace with something longer than 32 chars
  TRANSFER_ID="===Default==PlaceHolder==NULL==ID=="
fi

echo "retrieve $CONFIG.global.dlstore"
DLFILE="$(get_dldir)/dl-config-$TRANSFER_ID"

if [ "$TRANSFER_ACTION" = "start" ]; then
  STARTED=$(get_started $TRANSFER_ID)
  if [ "$STARTED" = "no" ]; then
    if [ ! -f $DLFILE ]; then
      echo "retrieve config $URL to $DLFILE"
      #wget -O $DLFILE $URL
      #wget $URL -O $DLFILE
      #replaced wget by curl to support https download	 
      curl $URL -S -s --capath /etc/ssl/certs -o $DLFILE
      if [ $? -ne 0 ]; then
        echo "download failed"
        rm -f $DLFILE 2>/dev/null
        # download failed, it must not be retried
        set_started "$TRANSFER_ID" yes $URL
        set_error "$TRANSFER_ID" 1
        exit 1
      fi
    fi
    STATEFILE=$(mktemp)
    TYPE=$(sed -n '1p' $DLFILE)
    if [ $TYPE = 'PREAMBLE=THENC' ]; then
      lua /usr/lib/lua/transformer/shared/ImportConfig.lua $DLFILE $STATEFILE
    else
      lua $SCRIPTDIR/exec_config.lua $DLFILE $STATEFILE
    fi
    if [ $? -ne 0 ]; then
        # execute failed
        echo "script execution failed"
        set_started "$TRANSFER_ID" yes $URL
        set_error "$TRANSFER_ID" 1
        exit 1
    else
        echo "setting started to yes for $TRANSFER_ID"
        set_started "$TRANSFER_ID" yes $URL
    fi
    # script executed correctly, see if we need to reboot
    REBOOT=$(grep REBOOT $STATEFILE | cut -d = -f2)
    if [ "$REBOOT" = "1" ]; then
        echo "reboot=$(which reboot)"
        . /lib/functions/reboot_reason.sh
        set_reboot_reason "STS" && reboot
        if [ $? -ne 0 ]; then
            echo "reboot failed, setting error"
            set_error "$TRANSFER_ID" 1
            exit 1
        fi
        # depending on the time it takes to initiate the reboot this may or may not
        # be executed. We should not return to cwmpd.
        sleep 3600
    else
        # reboot not wanted
       rm -f $STATEFILE
       exit 0
    fi
  else
    # transfer has already executed, return the error (if any)
    echo "transfer already executed"
    E=$(get_error "$TRANSFER_ID")
    echo "last error was \"$E\""
    if [ "$E" != "0" ]; then
      echo "but it failed previously"
      exit 1
    fi
    exit 0
  fi
fi
  
if [ "$TRANSFER_ACTION" = "cleanup" ]; then
  echo "cleanup after config apply"
  set_started "$TRANSFER_ID" no
  rm -f $DLFILE
fi
