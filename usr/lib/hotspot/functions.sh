#!/bin/sh

HOTSPOT_LIB="$IPKG_INSTROOT/usr/lib/hotspot"
HOTSPOT_NETWORK="fonopen"

HOTSPOT_LOGDIR="/root/hotspot"
HOTSPOT_LOG="${HOTSPOT_LOGDIR}/extendedstatus.log"
HOTSPOT_LOGSIZE=1024

hotspot_log() {
  logger -p "daemon.notice" -t "hotspot" "$*"
}

hotspot_init_state() {
  uci_set_state "hotspotd" "state" "" "state"
  uci_set_state "hotspotd" "state" "status" "down"
}

# hotspot_state_get <param>
hotspot_state_get() {
  uci_get_state "hotspotd" "state" "$1"
}

# hotspot_state_set <param> <value>
hotspot_state_set() {
  uci_revert_state "hotspotd" "state" "$1"
  uci_set_state "hotspotd" "state" "$1" "$2"
}

# hotspot_state_clear <param>
hotspot_state_clear() {
  uci_revert_state "hotspotd" "state" "$1"
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

hotspot_trim_log() {
  local max_size="$((HOTSPOT_LOGSIZE * 2))"
  local log_size="$(wc -c ${HOTSPOT_LOG} | cut -d ' ' -f 1)"

  check_is_number "${log_size}" && [ ${log_size} -gt ${max_size} ] || return
  hotspot_log "trim_log log_size=$log_size max_size=$max_size"

  tail -c ${HOTSPOT_LOGSIZE} "${HOTSPOT_LOG}" | sed '1d' > "${HOTSPOT_LOG}_tmp"
  mv "${HOTSPOT_LOG}_tmp" "${HOTSPOT_LOG}"
}

hotspot_set_extendedstatus() {
  local new_extendedstatus="$1"
  local old_extendedstatus="$(hotspot_state_get extendedstatus)"

  [ "${old_extendedstatus}" = "${new_extendedstatus}" ] && return

  hotspot_state_set extendedstatus "${new_extendedstatus}"
  ubus send hotspotd "{'ExtendedStatus':'ValueChange'}"
  hotspot_log "extendedstatus \"${new_extendedstatus}\""

  [ -d "${HOTSPOT_LOGDIR}" ] || return
  local strdate="$(date '+%Y%m%d-%H:%M:%S')"
  local entry="${strdate},${new_extendedstatus}"
  echo "${entry}" >> "${HOTSPOT_LOG}"

  hotspot_trim_log
}

hotspot_init() {
  hotspot_init_state

  mkdir -p "${HOTSPOT_LOGDIR}"
  hotspot_set_extendedstatus "DOWN_BOOT"
  hotspot_state_set extendedstatuslog "${HOTSPOT_LOG}"
}

parse_hotspotd_if() {
  local if="$1"

  config_get iface "${if}" iface
  [ -n "${iface}" ] || return

  if [ "${HOTSPOT_STATUS}" = "up" ] ; then
    config_get_bool enable "${if}" enable 0
    if [ ${enable} = 1 ] ; then
      append LIST_WL_IF_ENABLE ${iface}
      return 0
    fi
  fi
  append LIST_WL_IF_DISABLE ${iface}
}

parse_hotspotd_if_radio() {
  local if="$1"

  config_get iface "${if}" iface
  [ -n "${iface}" ] || return

  config_get_bool enable "${if}" enable 0
  if [ ${enable} = 1 ] ; then
      append LIST_WL_IF_ENABLE ${iface}
      return 0
  fi
}

parse_wireless_if_radio() {
  local if="$1"

  if list_contains LIST_WL_IF_ENABLE ${if} ; then
    config_get device "${if}" device
    [ -n "${device}" ] || return

    config_get_bool wifi_device_state "${device}" state
    if bool_is_true "$wifi_device_state" ; then
        HOTSPOT_RADIO_ENABLED=1
    fi
  fi
}

parse_wireless_if() {
  local if="$1"

  uci_revert_state "wireless" "${if}" "state"

  if list_contains LIST_WL_IF_ENABLE ${if} ; then
    uci_set_state "wireless" "${if}" "state" "1"
    uci_set "wireless" "${if}" "hotspot_timestamp" "${HOTSPOT_TIMESTAMP}"
  elif list_contains LIST_WL_IF_DISABLE ${if} ; then
    uci_set_state "wireless" "${if}" "state" "0"
    uci_set "wireless" "${if}" "hotspot_timestamp" "${HOTSPOT_TIMESTAMP}"
  fi
}

hotspot_apply_status() {
  LIST_WL_IF_ENABLE=
  LIST_WL_IF_DISABLE=
  HOTSPOT_STATUS="$(hotspot_state_get status)"
  HOTSPOT_TIMESTAMP="$(cat /proc/uptime)"

  # create lists with wireless interfaces to configure
  config_load "hotspotd"
  config_foreach parse_hotspotd_if wifi-iface

  # apply wireless ssid enable/disable
  config_load "wireless"
  config_foreach parse_wireless_if wifi-iface

  uci_commit "wireless"
  /etc/init.d/hostapd reload
  /etc/init.d/network reload

  if [ "${HOTSPOT_STATUS}" = "up" ]; then
    /usr/sbin/ebtables -A FORWARD --logical-out br-fonopen -j DROP
    /sbin/ifup ${HOTSPOT_NETWORK}
  else
    /sbin/ifdown ${HOTSPOT_NETWORK}
    /usr/sbin/ebtables -D FORWARD --logical-out br-fonopen -j DROP
  fi
}

hotspot_radio_enabled() {
  LIST_WL_IF_ENABLE=
  HOTSPOT_RADIO_ENABLED=

  # create lists with wireless interfaces to configure
  config_load "hotspotd"
  config_foreach parse_hotspotd_if_radio wifi-iface

  # check if at least 1 wifi radio is enabled
  config_load "wireless"
  config_foreach parse_wireless_if_radio wifi-iface

  [ "$HOTSPOT_RADIO_ENABLED" = "1" ] && return 0 || return 1
}


# return 0 if all conditions are OK
hotspot_should_be_up() {
  local state_deploy="$(hotspot_state_get deploy)"
  if [ -z "${state_deploy}" ]; then
      hotspot_set_extendedstatus "DOWN_ACS"
      return 1
  fi
  if ! bool_is_true "${state_deploy}"; then
      hotspot_set_extendedstatus "DOWN_OPTOUT"
      return 1
  fi
  if [ "$(hotspot_state_get hotspotdaemon)" != "up" ] || ! hotspot_radio_enabled; then
    hotspot_set_extendedstatus "DOWN_OWNER"
    return 1
  fi
  case "$(hotspot_state_get wan)" in
      up)
          if bool_is_true "$(hotspot_state_get hotspotdaemon_maxauthreached)"; then
            hotspot_set_extendedstatus "UP_MAXCON"
          else
            hotspot_set_extendedstatus "UP"
          fi
          return 0
      ;;
      slow)
          hotspot_set_extendedstatus "DOWN_DSLBW"
          return 1
      ;;
      *)
          hotspot_set_extendedstatus "DOWN_WAN"
          return 1
      ;;
  esac
}

# evaluate state parameters and update status if needed
hotspot_evaluate_state() {
  local old_status="$(hotspot_state_get status)"
  local new_status

  hotspot_should_be_up && new_status="up" || new_status="down"

  if [ "${old_status}" != "${new_status}" ]; then
    hotspot_state_set status "${new_status}"
    hotspot_apply_status
  fi
}

hotspot_check_dsl_syncrate() {
    local rate_ds="$(lua ${HOTSPOT_LIB}/sh_xdslctl.lua infoValue currentrate ds)"
    if ! check_is_number "${rate_ds}"; then
      hotspot_state_set wan "slow"
      hotspot_state_set syncrate "?"
      return
    fi

    local bw_thres="$(uci_get hotspotd main bandwidth_threshold)"
    if [ -z "${bw_thres}" ] || ! check_is_number "${bw_thres}"; then
      bw_thres=0
    fi
    local bw_hyst="$(uci_get hotspotd main bandwidth_hysteresis)"
    if [ -z "${bw_hyst}" ] || ! check_is_number "${bw_hyst}" || [ ${bw_hyst} -ge ${bw_thres} ] ; then
      bw_hyst=0
    fi

    local bw_min
    if [ "$(hotspot_state_get wan)" = "up" ]; then
      bw_min=$((${bw_thres} - ${bw_hyst}))
    else
      bw_min=$((${bw_thres} + ${bw_hyst}))
    fi

    if [ "${rate_ds}" -lt ${bw_min} ]; then
      hotspot_state_set wan "slow"
    else
      hotspot_state_set wan "up"
    fi
    hotspot_state_set syncrate "${rate_ds}"
}

hotspot_check_device() {
  local device

  network_get_physdev device "$1"

  if [ -z "${device}" ]; then
    hotspot_state_set wan "down"
    hotspot_state_clear syncrate
    return
  fi

  # strip vlan id
  device="$(echo ${device} | sed 's/\.[0-9]*$//')"
  # check if xtm device
  local xtm_type="$(uci_get xtm "${device}")"
  if [ "${xtm_type}" = "ptmdevice" ] || [ "${xtm_type}" = "atmdevice" ]; then
    hotspot_check_dsl_syncrate
    return
  fi

  # eth-wan
  hotspot_state_set wan "up"
  hotspot_state_clear syncrate
}

hotspot_checkwan() {
  local wan_intf="wan"

  if ! network_is_up "${wan_intf}"; then
    hotspot_state_set wan "down"
    hotspot_state_clear syncrate
    return
  fi

  hotspot_check_device "${wan_intf}"
}

# $1: action (ifup/ifdown)
# $2: interface name
# $3: physical device
hotspot_hotplug() {
  hotspot_log "hotplug \"$*\""
  [ $# -eq 3 ] || return
  local action="$1"
  local intf="$2"

  local wan_intf="wan"  # managed by wansensing, keeps things simple here
  # ignore unrelated interfaces
  [ "${intf}" = "${wan_intf}" ] || return

  case "${action}" in
      ifup)
          hotspot_check_device "${intf}"
      ;;
      ifdown)
          hotspot_state_set wan "down"
          hotspot_state_clear syncrate
      ;;
      *)
          return
      ;;
  esac
  hotspot_evaluate_state
}

