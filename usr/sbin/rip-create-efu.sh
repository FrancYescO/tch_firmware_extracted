#!/bin/sh

RIP_PATH="/proc/rip"
RIP_ID_CHIPID="0115"
RIP_ID_OSIK="0120"

SERIAL="$(uci get env.rip.factory_id)$(uci get env.rip.serial)"
[ -e "${RIP_PATH}/${RIP_ID_CHIPID}" ] && CHIPID="0x$(hexdump -v -n 4 -e '1/1 "%02X"' "${RIP_PATH}/${RIP_ID_CHIPID}")"

determine_signature_key() {
  [ -e "${RIP_PATH}/${RIP_ID_OSIK}" ] || return 1

  local md5_Technicolor="ada4cbd2a8e9d3c1175035e0fdf18399"
  local md5_Telia="4774d4ff5cddbb67eaf0bdd555f426a3"

  local md5_signkey="$(md5sum "${RIP_PATH}/${RIP_ID_OSIK}" | sed 's/ .*//')"

  case "${md5_signkey}" in
    ${md5_Technicolor})
      SIGNKEY="Technicolor"
      ;;
    ${md5_Telia})
      SIGNKEY="Telia"
      ;;
    *)
      SIGNKEY="Unknown (${md5_signkey})"
      ;;
  esac
}

determine_signature_key

echo "Serial Number : ${SERIAL}"
echo "Chip ID       : ${CHIPID:-'0x0'}"
echo "Signature Key : ${SIGNKEY:-'Not present'}"

