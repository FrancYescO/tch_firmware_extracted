#!/bin/sh
AH_NAME=WebTest

get_ms() {
  local value=$1
  [ "$value" = "0.000" ] && return 0
  value=${value//.}
  while [ ${value:0:1} -eq 0 ]; do
    value=${value##0}
  done
  echo $value
}

doTest() {
  local url=$1 result success=1

  st=`date -u +%FT%TZ`
  cmclient SETE "${obj}.StartTime" "$st"

  if [ -z ${url} ]; then
    cmclient SET ${obj}.DiagnosticState Error_NoURL
    return
  fi

  result=`curl ${url} -k -s -o /dev/null -w DnsTime=%{time_namelookup}:TCPOpenTime=%{time_starttransfer}:LoadTime=%{time_total}:HTTPcode=%{http_code}`
  IFS=$':'
  for result in $result; do
        case $result in
        "DnsTime"*)
          cmclient SETE "${obj}.DnsTime" $(get_ms ${result##*=})
        ;;
        "TCPOpenTime"*)
          cmclient SETE "${obj}.TCPOpenTime" $(get_ms ${result##*=})
        ;;
        "LoadTime"*)
          cmclient SETE "${obj}.LoadTime" $(get_ms ${result##*=})
        ;;
        "HTTPcode"*)
          result=${result##*=}
          if [ "$result" != "000" ]; then
            cmclient SETE "${obj}.HttpCode" ${result##*=}
          else
            success=0
            cmclient SETE "${obj}.HttpCode" "0"
          fi
        ;;
        esac
  done
  unset IFS
  [ $success -eq 1 ] && cmclient SET ${obj}.DiagnosticsState Completed || cmclient SET ${obj}.DiagnosticsState "Error_NoResponse"

}

[ "$setDiagnosticsState" = "1" -a \
  "$newDiagnosticsState" != "Requested" -a \
  "$newDiagnosticsState" != "None" ] && exit 0

[ "$user" = "${AH_NAME}${obj}" ] && exit 0

. /etc/ah/helper_serialize.sh && help_serialize > /dev/null
. /etc/ah/helper_functions.sh

if [ "$setDiagnosticsState" = "1" -a "$newDiagnosticsState" = "Requested" ]; then
  doTest $newURL &
fi

exit 0