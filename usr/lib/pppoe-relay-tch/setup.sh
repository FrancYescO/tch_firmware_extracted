#!/bin/sh

# Copyright (c) 2016 Technicolor
# All Rights Reserved
#
# This program contains proprietary information which is a trade
# secret of TECHNICOLOR and/or its affiliates and also is protected as
# an unpublished work under applicable Copyright laws. Recipient is
# to retain this program in confidence and is not permitted to use or
# make copies thereof other than as permitted in a written agreement
# with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS.
#

. $IPKG_INSTROOT/usr/share/libubox/jshn.sh

do_cmd() {
  [ -n "${PPPOERELAY_DEBUG}" ] && echo "$@"
  "$@"
}

ebt_broute() {
  do_cmd ebtables -t broute "$@"
}

ebt_filter() {
  do_cmd ebtables -t filter "$@"
}

ubus_device() {
  local cmd=$1
  local dev=$2
  local bridge=$3

  json_init
  json_add_string name "$dev"
  json_add_boolean link-ext 0
  json_close_object

  do_cmd ubus call "network.interface.${bridge}" ${cmd}_device "$(json_dump)"
}

pppoerelay_uci_init() {
  uci_revert_state "network" "pppoerelay"
  uci_set_state "network" "pppoerelay" "" "state"
}

pppoerelay_uci_clear() {
  uci_revert_state "network" "pppoerelay"
  UCI_STATE=''
}

pppoerelay_load_state() {
  UCI_STATE="$(uci_get_state "network" "pppoerelay")"
  [ -n "${UCI_STATE}" ] || return

  UCI_RELAY_BRIDGES="$(uci_get_state "network" "pppoerelay" "bridges")"
  local bridge
  for bridge in "${UCI_RELAY_BRIDGES}"
  do
    eval UCI_RELAY_${bridge}=\"$(uci_get_state "network" "pppoerelay" "${bridge}_dev")\"
  done
}

add_relay_bridge() {
  local bridge=$1

  network_get_device bridge_dev ${bridge} && [ -n "${bridge_dev}" ] || return
  uci_set_state "network" "pppoerelay" "${bridge}" "${bridge_dev}"

  if [ -z "${RELAY_BRIDGES}" ]; then
    ebt_broute -N ppprelay
    ebt_broute -P ppprelay DROP
    ebt_broute -A ppprelay -p PPP_SES -j ACCEPT
    ebt_broute -A ppprelay -p PPP_DISC -j ACCEPT

    ebt_filter -N ppprelay
    ebt_filter -P ppprelay DROP
    ebt_filter -A ppprelay -p PPP_SES -j ACCEPT
    ebt_filter -A ppprelay -p PPP_DISC -j ACCEPT
  fi
  append RELAY_BRIDGES ${bridge}

  ebt_broute -N ppprelay_${bridge}
  ebt_broute -A BROUTING --logical-in ${bridge_dev} -j ppprelay_${bridge}

  ebt_filter -N ppprelay_${bridge}
  ebt_filter -A FORWARD --logical-out ${bridge_dev} -j ppprelay_${bridge}
  ebt_filter -N pppcheck_${bridge}
  ebt_filter -A OUTPUT --logical-out ${bridge_dev} -j pppcheck_${bridge}
  eval RELAY_${bridge}=''
}

add_relay_dev() {
  local dev=$1
  local bridge=$2

  ! list_contains RELAY_${bridge} ${dev} && [ -e "/sys/class/net/${dev}" ] || return
  append RELAY_${bridge} ${dev}

  ebt_broute -A ppprelay_${bridge} -i ${dev} -j ppprelay
  ebt_filter -A ppprelay_${bridge} -o ${dev} -j ppprelay
  ebt_filter -A pppcheck_${bridge} -o ${dev} -j DROP
  # last step: add relay device to bridge
  ubus_device add ${dev} ${bridge}
}

start_interface() {
  local intf=$1

  ! list_contains RELAY_BRIDGES ${intf} || return

  config_get iftype ${intf} "type"
  config_get pppoerelay ${intf} "pppoerelay"
  [ "${iftype}" = "bridge" -a -n "${pppoerelay}" ] && add_relay_bridge "${intf}" || return
  config_list_foreach "${intf}" "pppoerelay" add_relay_dev "${intf}"

  local tmp; eval tmp=\"\${RELAY_${intf}}\"
  uci_set_state "network" "pppoerelay" "${intf}_dev" "${tmp}"
}

stop_interface() {
  local bridge=$1

  local tmp; eval tmp=\"\${UCI_RELAY_${bridge}}\"
  local dev
  for dev in ${tmp}
  do
    # first remove relay devices from bridge if still member
    local bridge_dev=$(uci_get_state "network" "pppoerelay" "${bridge}")
    [ -e "/sys/class/net/${bridge_dev}/brif/${dev}" ] && ubus_device remove ${dev} ${bridge}
  done
  # remove relay chains
  ebt_broute -X ppprelay_${bridge}
  ebt_filter -X ppprelay_${bridge}
  ebt_filter -X pppcheck_${bridge}
}

######
# init.d
pppoerelay_start() {
  [ -z "${UCI_STATE}" ] || pppoerelay_stop
  pppoerelay_uci_init

  RELAY_BRIDGES=''
  config_load "network"
  config_foreach start_interface "interface"

  uci_toggle_state "network" "pppoerelay" "bridges" "${RELAY_BRIDGES}"
}

pppoerelay_stop() {
  [ -n "${UCI_STATE}" ] || return

  if [ -n "${UCI_RELAY_BRIDGES}" ]; then
    # disable all bridging while removing relay devices
    ebt_broute -P BROUTING DROP
    ebt_filter -P FORWARD DROP
    ebt_filter -P OUTPUT DROP

    # currently safe because no other users for these chains
    ebt_broute -F BROUTING
    ebt_filter -F FORWARD
    ebt_filter -F OUTPUT

    local bridge
    for bridge in ${UCI_RELAY_BRIDGES}
    do
      stop_interface ${bridge}
    done

    # enable bridging again
    ebt_broute -P BROUTING ACCEPT
    ebt_filter -P FORWARD ACCEPT
    ebt_filter -P OUTPUT ACCEPT
    # no longer needed
    ebt_broute -X ppprelay
    ebt_filter -X ppprelay
  fi

  pppoerelay_uci_clear
}

pppoerelay_restart() {
  pppoerelay_stop
  pppoerelay_start
}

pppoerelay_reload() {
  pppoerelay_restart
}

pppoerelay_load_state
