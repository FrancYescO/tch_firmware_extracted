#!/bin/sh

ERROR_FILE=$1

LOCATION=/tmp/
FILENAME=vendor_config
generator=/usr/lib/lua/transformer/shared/VendorConfig.lua

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

log_info()
{
  echo "*info: $1"
}

log_error()
{
  E=$1
  if [ ! -z $ERROR_FILE ]; then
    echo $E >$ERROR_FILE
  fi
  echo "*error: $E"
}

log_info "Entering vendorconfig.sh with args $*"

#sanity checks
if [ "$TRANSFER_TYPE" != "upload" ]; then
  log_error "supports only upload, not $TRANSFER_TYPE"
  exit 1
fi

if [ $TRANSFER_FILETYPE_INSTANCE ]; then
  log_info "Filetype is $TRANSFER_FILETYPE"
  log_info "Instance number is $TRANSFER_FILETYPE_INSTANCE"
fi

if [ -z $TRANSFER_URL ]; then
  log_error "no URL specified"
  exit 1
fi


if [ "$TRANSFER_ACTION" = "start" ]; then
  log_info "TRANSFER_ACTION == start"
  E="0"

  FILE=$LOCATION$FILENAME

  URL=$(get_url "$TRANSFER_URL" "$TRANSFER_USERNAME" "$TRANSFER_PASSWORD")

  lua $generator $TRANSFER_FILETYPE_INSTANCE $LOCATION $FILENAME
  if [ $? != 0 ]; then
    E="Generate vendor config file failed"
  else
    if curl --fail --silent --anyauth -T "$FILE" "$URL"; then
      log_info "Upload vendor config file successed"
    else
      E="Upload vendor config file failed"
      rm -f $FILE 2>/dev/null
    fi
  fi
  if [ "$E" != "0" ]; then
    log_error "$E"
    exit 1
  fi
  log_info "TRANSFER_ACTION == done"
  exit 0
fi

if [ "$TRANSFER_ACTION" = "cleanup" ]; then
  log_info "TRANSFER_ACTION == cleanup"
  rm -f $FILE 2>/dev/null
  exit 0
fi

log_error "Unknown transfer action: $TRANSFER_ACTION"
exit 1
