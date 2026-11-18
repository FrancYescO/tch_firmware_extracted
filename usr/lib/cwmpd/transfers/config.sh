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

TRIGGERS=$(cd $SCRIPTDIR/../triggers; pwd)

CONFIG=cwmp_transfer

get_usr_passwd()
{
  local username="$1"
  local password="$2"
  local usrinfo=
  if [ ! -z $username ]; then
    usrinfo="$username"
  fi
  if [ ! -z $password ]; then
    usrinfo="$usrinfo:$password"
  fi
  echo $usrinfo
}

# TRANSFER_URL, TRANSFER_USERNAME and TRANSFER_PASSWORD are passed as parameters to this function
get_url()
{
  local URL="$1"
  local usrinfo=$(get_usr_passwd "$2" "$3")

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

import_config() {
	local DLFILE=$1
	local STATEFILE=$2
	local importer=/usr/lib/lua/transformer/shared/ImportConfig.lua
	if [ -f $importer ]; then
		lua $importer $DLFILE $STATEFILE
		return $?
	fi
	echo "$importer not found"
	return 1
}

install_ispconfig() {
	local DLFILE=$1
	local SCRIPT=/etc/ispconfig/ispconfig.sts
	cp $DLFILE $SCRIPT
}

execute() {
  local DLFILE=$1
  local STATEFILE=$2
  local FIRSTLINE=$(head -n 1 $DLFILE)
  if [ "$FIRSTLINE" = "PREAMBLE=THENC" ]; then
    import_config $DLFILE $STATEFILE
  elif [ "$FIRSTLINE" = "ispconfig" ]; then
    install_ispconfig $DLFILE STATEFILE
  else
    # exclude mwan socket mark value
    ( unset SO_MARK ; lua $SCRIPTDIR/exec_config.lua $DLFILE $STATEFILE )
  fi
}

trigger() {
	local event=$1
	local script=${TRIGGERS}/${event}.sh
	if [ -x "$script" ]; then
		$script
	fi
}

#sanity checks
if [ "$TRANSFER_TYPE" != "download" ]; then
  echo "supports only download, not $TRANSFER_TYPE"
  exit 1
fi

if [ -z $TRANSFER_URL ]; then
  echo "no URL specified"
  ubus send FaultMgmt.Event '{ "Source":"cwmpd", "EventType":"ACS provisioning", "ProbableCause":"Download and apply config file error", "SpecificProblem":"no URL specified" }'
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
  E="0"
  STARTED=$(get_started $TRANSFER_ID)
  if [ "$STARTED" = "no" ]; then
    if [ ! -f $DLFILE ]; then
      echo "retrieve config $URL to $DLFILE"
      #wget -O $DLFILE $URL
      #wget $URL -O $DLFILE
      #replaced wget by curl to support https download
      local user_passwd=$(get_usr_passwd "$TRANSFER_USERNAME" "$TRANSFER_PASSWORD")
      if [ -n "$user_passwd" ]; then
         curl -u "$user_passwd" "$TRANSFER_URL"  -S -s --capath /etc/ssl/certs -o $DLFILE
      else
         curl "$TRANSFER_URL" -S -s --capath /etc/ssl/certs -o $DLFILE
      fi

      if [ $? -ne 0 ]; then
        E="1,download failed"
        echo $(echo $E | cut -d, -f2)
        rm -f $DLFILE 2>/dev/null
        # download failed, it must not be retried
        set_started "$TRANSFER_ID" yes $URL
        set_error "$TRANSFER_ID" "$E"
        exit 1
      fi
    fi

    # if the downloaded file is a .pem file install it as key/cert for nginx server
    if echo $URL | grep -q '\.pem$'; then
        cp $DLFILE /etc/nginx/server.crt && chmod 400 /etc/nginx/server.crt && ln -sf /etc/nginx/server.crt /etc/nginx/server.key
        if [ $? -ne 0 ]; then
          # installing cert/key failed
          E="1,pem installation failed"
          echo $(echo $E | cut -d, -f2)
          set_started "$TRANSFER_ID" yes $URL
          set_error "$TRANSFER_ID" "$E"
          exit 1
        else
          /etc/init.d/nginx reload
          trigger pem_updated
          exit 0
        fi
    fi

    STATEFILE=$(mktemp)
    execute $DLFILE $STATEFILE
    if [ $? -ne 0 ]; then
        # execute failed
        E="1,script execution failed"
        echo $(echo $E | cut -d, -f2)
        set_started "$TRANSFER_ID" yes $URL
        set_error "$TRANSFER_ID" "$E"
        exit 1
    else
        echo "setting started to yes for $TRANSFER_ID"
        set_started "$TRANSFER_ID" yes $URL
    fi
    # script executed correctly, see if we need to reboot
    REBOOT=$(grep REBOOT $STATEFILE | cut -d = -f2)
    if [ "$REBOOT" = "1" ]; then
        echo "reboot=$(which reboot)"
        if [ -f /lib/functions/reboot_reason.sh ]; then
            . /lib/functions/reboot_reason.sh
            set_reboot_reason "STS" && reboot
        else
            reboot
        fi
        if [ $? -ne 0 ]; then
            E="1,reboot failed, setting error"
            echo $(echo $E | cut -d, -f2)
            set_error "$TRANSFER_ID" "$E"
            exit 1
        fi
        # depending on the time it takes to initiate the reboot this may or may not
        # be executed. We should not return to cwmpd.
        sleep 3600
    else
        # reboot not wanted
        rm -f $STATEFILE
        # if neither error nor reboot, report success here since it won't go into start transfer_aciton again
        ubus send FaultMgmt.Event '{ "Source":"cwmpd", "EventType":"ACS provisioning", "ProbableCause":"Download and apply config file success", "SpecificProblem":"", "AdditionalText":"URL='"$TRANSFER_URL"'", "AdditionalInformation":"Need not reboot" }'
        exit 0
    fi
  else
    # transfer has already executed, return the error (if any)
    echo "transfer already executed"
    E=$(get_error "$TRANSFER_ID")
    echo "last error was \"$(echo $E | cut -d, -f2)\""
    if [ "$E" != "0" ]; then
      echo "but it failed previously"
      exit 1
    fi
    # go into start transfer_action again with started == yes, it's because system reboot after applied the config file
    ubus send FaultMgmt.Event '{ "Source":"cwmpd", "EventType":"ACS provisioning", "ProbableCause":"Download and apply config file success", "SpecificProblem":"", "AdditionalText":"URL='"$TRANSFER_URL"'", "AdditionalInformation":"Reboot completed"}'
    exit 0
  fi
fi
  
if [ "$TRANSFER_ACTION" = "cleanup" ]; then
  echo "cleanup after config apply"
  E=$(get_error "$TRANSFER_ID")
  if [ "$E" != "0" ]; then
    # if failed previously, it won't go into start transfer_action again, report error here when cleanup
    ubus send FaultMgmt.Event '{ "Source":"cwmpd", "EventType":"ACS provisioning", "ProbableCause":"Download and apply config file error", "SpecificProblem":"'"$(echo $E | cut -d, -f2)"'", "AdditionalText":"URL='"$TRANSFER_URL"'"}'
  fi
  set_started "$TRANSFER_ID" no
  rm -f $DLFILE
fi
