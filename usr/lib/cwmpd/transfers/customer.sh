#!/bin/sh
ERROR_FILE="${1}"

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

# Sanity checks
if [ "${TRANSFER_TYPE}" != "download" ]; then
  echo "supports only download, not ${TRANSFER_TYPE}"
  exit 1
fi

if [ "${TRANSFER_ACTION}" == "start" ]; then
  if [ -z "${TRANSFER_URL}" -o -z "${TRANSFER_FILETYPE}" ]; then
    echo "Not all required variables are set"
    exit 1
  fi

  CUSTOMER=$(echo "${TRANSFER_FILETYPE}" | cut -d ' ' -f 2 | awk '{print tolower($0)}')
  # Check if we have a script for this customer
  if [ ! -f "/usr/lib/cwmpd/transfers/${CUSTOMER}.sh" ]; then
    echo "No Customer script found for ${TRANSFER_FILETYPE}"
    exit 1
  fi

  # Download is handled here, file is passed to customer script
  URL=$(get_url "$TRANSFER_URL" "$TRANSFER_USERNAME" "$TRANSFER_PASSWORD")
  ubus send cwmpd.transfer '{ "session": "begins" }'

  if [ -z "${TRANSFER_TARGETFILE}" ]; then
    TRANSFER_TARGETFILE=$(echo "${URL}" | md5sum | cut -d ' ' -f 1)
  fi

  TMP_ERROR="/tmp/cwmp_error_${TRANSFER_TARGETFILE}"
  touch "${TMP_ERROR}"

  /usr/lib/sysupgrade-tch/retrieve_image.sh "${URL}" > "/tmp/${TRANSFER_TARGETFILE}" 2> "${TMP_ERROR}"
  E=$?
  if [ "${E}" == "0" ]; then
    /usr/lib/cwmpd/transfers/${CUSTOMER}.sh "/tmp/${TRANSFER_TARGETFILE}" 2> "${TMP_ERROR}"
    E=$?
  fi

  if [ "$E" != "0" ]; then
    echo "Download error: $E"
    echo "$(cat ${TMP_ERROR})"
    if [ ! -z "${ERROR_FILE}" ]; then
      echo "${E}" > "${ERROR_FILE}"
      cat "${TMP_ERROR}" >> "${ERROR_FILE}"
    fi
  fi

  rm -f "${TMP_ERROR}"
  ubus send cwmpd.transfer '{ "session": "ends" }'
fi

if [ "${TRANSFER_ACTION}" == "cleanup" ]; then
  URL=$(get_url "$TRANSFER_URL" "$TRANSFER_USERNAME" "$TRANSFER_PASSWORD")

  if [ -z "${TRANSFER_TARGETFILE}" ]; then
    TRANSFER_TARGETFILE=$(echo "${URL}" | md5sum | cut -d ' ' -f 1)
  fi
  find /tmp/ -iname "*${TRANSFER_TARGETFILE}*" -exec rm -f {} \;
fi
