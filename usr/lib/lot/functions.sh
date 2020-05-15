#!/bin/sh

LOT_LIB="$IPKG_INSTROOT/usr/lib/lot"

LOT_LOGDIR="/root/lot"
LOT_LOG="${LOT_LOGDIR}/extendedstatus.log"
LOT_LOGSIZE=1024

lot_log() {
  logger -p "daemon.notice" -t "lot" "$*"
}

lot_init_state() {
  uci_set_state "lot" "state" "" "state"
  uci_set_state "lot" "state" "status" "down"
}

# lot_state_get <param>
lot_state_get() {
  uci_get_state "lot" "state" "$1"
}

# lot_state_set <param> <value>
lot_state_set() {
  uci_revert_state "lot" "state" "$1"
  uci_set_state "lot" "state" "$1" "$2"
}

# lot_state_clear <param>
lot_state_clear() {
  uci_revert_state "lot" "state" "$1"
}

# bool_is_true <value)
bool_is_true() {
  case "$1" in
      1|on|true|enabled) return 0;;
  esac
  return 1
}

check_is_number() {
    case "$1" in
        ''|*[!0-9]*)
            return 1
        ;;
    esac
}

lot_trim_log() {
  local max_size="$((LOT_LOGSIZE * 2))"
  local log_size="$(wc -c ${LOT_LOG} | cut -d ' ' -f 1)"

  check_is_number "${log_size}" && [ ${log_size} -gt ${max_size} ] || return
  lot_log "trim_log log_size=$log_size max_size=$max_size"

  tail -c ${LOT_LOGSIZE} "${LOT_LOG}" | sed '1d' > "${LOT_LOG}_tmp"
  mv "${LOT_LOG}_tmp" "${LOT_LOG}"
}

lot_set_extendedstatus() {
  local new_extendedstatus="$1"
  local old_extendedstatus="$(lot_state_get extendedstatus)"

  [ "${old_extendedstatus}" = "${new_extendedstatus}" ] && return

  lot_state_set extendedstatus "${new_extendedstatus}"
  ubus send lot "{'ExtendedStatus':'ValueChange'}"
  lot_log "extendedstatus \"${new_extendedstatus}\""

  [ -d "${LOT_LOGDIR}" ] || return
  local strdate="$(date '+%Y%m%d-%H:%M:%S')"
  local entry="${strdate},${new_extendedstatus}"
  echo "${entry}" >> "${LOT_LOG}"

  lot_trim_log
}

lot_init() {
  lot_init_state

  mkdir -p "${LOT_LOGDIR}"
  lot_set_extendedstatus "DISABLED"
  lot_state_set extendedstatuslog "${LOT_LOG}"
}


# return 0 if all conditions are OK
lot_should_be_up() {
  local state_deploy="$(lot_state_get deploy)"
  if [ -z "${state_deploy}" ]; then
      lot_set_extendedstatus "DISABLED"
      return 1
  fi
  if ! bool_is_true "${state_deploy}"; then
      lot_set_extendedstatus "DISABLED_OPTOUT"
      return 1
  fi
  config_load "wireless"
  config_get_bool state "radio_2G" state
  if ! bool_is_true $state; then
    lot_set_extendedstatus "DISABLED_OWNER"
    return 1
  fi
  case "$(lot_state_get wan)" in
      up)
            lot_set_extendedstatus "LISTENING"
          return 0
      ;;
      slow)
          lot_set_extendedstatus "DISABLED_DSLBW"
          return 1
      ;;
      *)
          lot_set_extendedstatus "DISABLED_ACCESS"
          return 1
      ;;
  esac
}

# evaluate state parameters and update status if needed
lot_evaluate_state() {
  local old_status="$(lot_state_get status)"
  local new_status
  lot_should_be_up && new_status="up" || new_status="down"

  if [ "${old_status}" != "${new_status}" ]; then
    lot_state_set status "${new_status}"
  fi
}

lot_check_dsl_syncrate() {
    local rate_us="$(lua ${LOT_LIB}/sh_xdslctl.lua infoValue currentrate us)"
    if ! check_is_number "${rate_us}"; then
      lot_state_set wan "slow"
      lot_state_set syncrate "?"
      return
    fi

    local bw_thres="$(uci_get lot lot_config bandwidth_threshold)"
    if [ -z "${bw_thres}" ] || ! check_is_number "${bw_thres}"; then
      bw_thres=0
    fi
    local bw_hyst="$(uci_get lot lot_config bandwidth_hysteresis)"
    if [ -z "${bw_hyst}" ] || ! check_is_number "${bw_hyst}" || [ ${bw_hyst} -ge ${bw_thres} ] ; then
      bw_hyst=0
    fi

    local bw_min
    if [ "$(lot_state_get wan)" = "up" ]; then
      bw_min=$((${bw_thres} - ${bw_hyst}))
    else
      bw_min=$((${bw_thres} + ${bw_hyst}))
    fi

    if [ "${rate_us}" -lt ${bw_min} ]; then
      lot_state_set wan "slow"
    else
      lot_state_set wan "up"
    fi
    lot_state_set syncrate "${rate_us}"
}

lot_check_device() {
  local device

  network_get_physdev device "$1"

  if [ -z "${device}" ]; then
    lot_state_set wan "down"
    lot_state_clear syncrate
    return
  fi

  # strip vlan id
  device="$(echo ${device} | sed 's/\.[0-9]*$//')"
  # check if xtm device
  local xtm_type="$(uci_get xtm "${device}")"
  if [ "${xtm_type}" = "ptmdevice" ] || [ "${xtm_type}" = "atmdevice" ]; then
    lot_check_dsl_syncrate
    return
  fi

  # eth-wan
  lot_state_set wan "up"
  lot_state_clear syncrate
}

lot_checkwan() {
  local wan_intf="wan"

  if ! network_is_up "${wan_intf}"; then
    lot_state_set wan "down"
    lot_state_clear syncrate
    return
  fi

  lot_check_device "${wan_intf}"
}

# $1: action (ifup/ifdown)
# $2: interface name
# $3: physical device
lot_hotplug() {
  lot_log "hotplug \"$*\""
  [ $# -eq 3 ] || return
  local action="$1"
  local intf="$2"

  local wan_intf="wan"  # managed by wansensing, keeps things simple here
  # ignore unrelated interfaces
  [ "${intf}" = "${wan_intf}" ] || return

  case "${action}" in
      ifup)
          lot_check_device "${intf}"
      ;;
      ifdown)
          lot_state_set wan "down"
          lot_state_clear syncrate
      ;;
      *)
          return
      ;;
  esac
  lot_evaluate_state
}

