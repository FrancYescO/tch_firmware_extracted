#!/bin/sh

. /usr/lib/cwmpd/transfers/common_functions.sh
ERROR_FILE=$1

LOCATION=/tmp/
FILENAME=vendor_log
generator=/usr/lib/lua/transformer/shared/VendorLog.lua

# Filename uses a new Template <serial>name<date>.log
# <serial> - Serial number of the CPE device.
# <date>   - Current date and time when the file is uploaded.
if [ ! -z $(uci get env.var.vendor_log 2>/dev/null) ]; then
	DATE=$(date +'%m-%d-%Y-%T')
	FILENAME=$(uci get env.var.vendor_log | sed 's/<serial>/'$(uci get env.var.serial)'/g' | sed 's/<date>/'$DATE'/g')
fi

get_usr_passwd()
{
  local username=$1
  local password=$2
  local usrinfo=
  if [ ! -z $username ]; then
    usrinfo=$username
  fi
  if [ ! -z $password ]; then
    usrinfo="$usrinfo:$password"
  fi
  echo $usrinfo
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

log_info "Entering vendorlog.sh with args $*"

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
  ubus send FaultMgmt.Event '{ "Source":"cwmpd", "EventType":"ACS provisioning", "ProbableCause":"Upload vendor log file error", "SpecificProblem":"no URL specified" }'
  exit 1
fi


if [ "$TRANSFER_ACTION" = "start" ]; then
  log_info "TRANSFER_ACTION == start"
  E="0"

  FILE=$LOCATION$FILENAME

  #send UBUS event at the start of the file transfer
  ubus send cwmpd.transfer '{ "session": "begins" }'

  lua $generator $TRANSFER_FILETYPE_INSTANCE $LOCATION $FILENAME
  if [ $? != 0 ]; then
    E="Generate vendor log file failed"
  else
    user_passwd=$(get_usr_passwd "$TRANSFER_USERNAME" "$TRANSFER_PASSWORD")
    client_auth_arguments=$(get_client_auth_arguments)
    if [ -n "$user_passwd" ]; then
        curl --fail --silent --anyauth -T "$FILE" -u "$user_passwd" "$TRANSFER_URL" $client_auth_arguments
    else
        curl --fail --silent --anyauth -T "$FILE" "$TRANSFER_URL" $client_auth_arguments
    fi

    if [ $? -eq 0 ]; then
      log_info "Upload vendor log file succeeded"
      if [ "$(uci -q get env.var.retaincrashfiles)" != "1" ]; then
        crash_file=$(readlink -f $FILE)
	if [ -n "$crash_file" ]; then
          case "$crash_file" in
            *core.gz*) rm -rf $crash_file 2>/dev/null; log_info "Coredump file deleted" ;;
            *kernel_crash.gz*)  rm -f $crash_file 2>/dev/null; log_info "Crash file deleted" ;;
            *) ;;
          esac
	fi
      fi
    else
      E="Upload vendor log file failed"
    fi
  fi
  rm -f $FILE 2>/dev/null
  if [ "$E" != "0" ]; then
    log_error "$E"
    ubus send cwmpd.transfer '{ "session": "ends" }'
    ubus send FaultMgmt.Event '{ "Source":"cwmpd", "EventType":"ACS provisioning", "ProbableCause":"Upload vendor log file error", "SpecificProblem":"'"$E"'", "AdditionalText":"URL='"$TRANSFER_URL"'"}'
    exit 1
  fi
  log_info "TRANSFER_ACTION == done"
  ubus send cwmpd.transfer '{ "session": "ends" }'
  ubus send FaultMgmt.Event '{ "Source":"cwmpd", "EventType":"ACS provisioning", "ProbableCause":"Upload vendor log file success", "SpecificProblem":"", "AdditionalText":"URL='"$TRANSFER_URL"'"}'
  exit 0
fi

if [ "$TRANSFER_ACTION" = "cleanup" ]; then
  log_info "TRANSFER_ACTION == cleanup"
  rm -f $FILE 2>/dev/null
  exit 0
fi

log_error "Unknown transfer action: $TRANSFER_ACTION"
exit 1
