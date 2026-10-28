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

pppoerelay_log() {
  logger -t "pppoe-relay-tch" "$@"
}

do_cmd() {
  [ -n "${PPPOERELAY_DEBUG}" ] && echo "$@"
  "$@"
}

ebt_broute() {
  do_cmd ebtables -t broute "$@"
}

ebt_broute_check() {
  local chain="$1"
  shift
  # ebtables remove the first zero in the MAC address
  local pattern=$(echo "$@" | sed 's/:0/:/g')
  do_cmd ebtables -t broute -L ${chain} | grep -- "${pattern}" &> /dev/null
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

pppoerelay_get_state() {
  local option=$(echo "$1" | tr '.' '_')
  uci_get_state "network" "pppoerelay" "${option}" "$2"
}

pppoerelay_set_state() {
  local option=$(echo "$1" | tr '.' '_')
  uci_set_state "network" "pppoerelay" "${option}" "$2"
}

pppoerelay_delete_state() {
  local option=$(echo "$1" | tr '.' '_')
  uci_revert_state "network" "pppoerelay" "${option}"
}

pppoerelay_toggle_state() {
  local option=$(echo "$1" | tr '.' '_')
  uci_toggle_state "network" "pppoerelay" "${option}" "$2"
}

pppoerelay_init_state() {
  pppoerelay_delete_state
  pppoerelay_set_state "" "state"
}

pppoerelay_clear_state() {
  pppoerelay_delete_state
  UCI_STATE=''
}

pppoerelay_load_state() {
  UCI_STATE="$(pppoerelay_get_state)"
  [ -n "${UCI_STATE}" ] || return

  UCI_RELAY_BRIDGES="$(pppoerelay_get_state "bridges")"
  local bridge
  for bridge in "${UCI_RELAY_BRIDGES}"
  do
    eval UCI_RELAY_${bridge}=\"$(pppoerelay_get_state "${bridge}_relay")\"
    eval UCI_RELAY_UP_${bridge}=\"$(pppoerelay_get_state "${bridge}_relay_up")\"
  done
}

start_interface() {
  local intf=$1

  ! list_contains RELAY_BRIDGES ${intf} || return 0

  BRIDGE_MAC_ADDRESSES=''

  config_get iftype ${intf} "type"
  config_get pppoerelay ${intf} "pppoerelay"
  [ "${iftype}" = "bridge" -a -n "${pppoerelay}" ] && add_relay_bridge "${intf}" || return
  config_list_foreach "${intf}" "pppoerelay" add_relay_dev "${intf}"

  local tmp; eval tmp=\"\${RELAY_${intf}}\"
  pppoerelay_set_state "${intf}_relay" "${tmp}"
  local tmp; eval tmp=\"\${RELAY_UP_${intf}}\"
  pppoerelay_set_state "${intf}_relay_up" "${tmp}"
}

add_relay_bridge() {
  local bridge=$1

  network_get_device bridge_l2dev ${bridge} && [ -n "${bridge_l2dev}" ] || return
  pppoerelay_set_state "${bridge}" "${bridge_l2dev}"

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
  eval RELAY_${bridge}=''
  eval RELAY_UP_${bridge}=''

  # find all local mac addresses
  local addr name
  # get the bridge mac address
  read addr < "/sys/class/net/${bridge_l2dev}/address"
  append BRIDGE_MAC_ADDRESSES ${addr}
  # get bridge ports mac addresses
  for name in /sys/class/net/${bridge_l2dev}/brif/*
  do
    read addr < "/sys/class/net/${name##*/}/address"
    list_contains BRIDGE_MAC_ADDRESSES ${addr} || append BRIDGE_MAC_ADDRESSES ${addr}
  done

  # create relay bridge chains
  ebt_broute -N ppprelay_${bridge}
  ebt_broute -P ppprelay_${bridge} DROP
  ebt_broute -N broute_${bridge}
  for addr in ${BRIDGE_MAC_ADDRESSES}
  do
    ebt_broute -A ppprelay_${bridge} -d ${addr} -j DROP
  done
  ebt_broute -A ppprelay_${bridge} -j ppprelay
  ebt_broute -A BROUTING --logical-in ${bridge_l2dev} -j broute_${bridge}
  ebt_filter -N ppprelay_${bridge}
  ebt_filter -A FORWARD --logical-out ${bridge_l2dev} -j ppprelay_${bridge}
  ebt_filter -N pppcheck_${bridge}
  ebt_filter -A OUTPUT --logical-out ${bridge_l2dev} -j pppcheck_${bridge}
}

remove_relay_bridge() {
  local bridge=$1
  local bridge_l2dev=$(pppoerelay_get_state "${bridge}")

  local tmp; eval tmp=\"\${UCI_RELAY_${bridge}}\"
  local dev
  for dev in ${tmp}
  do
    list_contains UCI_RELAY_UP_${bridge} ${dev} && disable_relay_dev ${dev} ${bridge} ${bridge_l2dev}
    pppoerelay_delete_state "${dev}_bridge"
  done

  # remove relay bridge chains
  ebt_broute -D BROUTING --logical-in ${bridge_l2dev} -j broute_${bridge}
  ebt_broute -X broute_${bridge}
  ebt_broute -X ppprelay_${bridge}
  ebt_filter -D FORWARD --logical-out ${bridge_l2dev} -j ppprelay_${bridge}
  ebt_filter -X ppprelay_${bridge}
  ebt_filter -D OUTPUT --logical-out ${bridge_l2dev} -j pppcheck_${bridge}
  ebt_filter -X pppcheck_${bridge}

  # clear state values
  pppoerelay_delete_state "${bridge}"
  pppoerelay_delete_state "${bridge}_relay"
  pppoerelay_delete_state "${bridge}_relay_up"
}

add_relay_dev() {
  local dev=$1
  local bridge=$2

  ! list_contains RELAY_DEVICES ${dev} || return
  append RELAY_DEVICES ${dev}
  append RELAY_${bridge} ${dev}
  pppoerelay_set_state "${dev}_bridge" "${bridge}"

  [ -e "/sys/class/net/${dev}" ] || return
  append RELAY_UP_${bridge} ${dev}
  enable_relay_dev ${dev} ${bridge} ${bridge_l2dev}
}

enable_relay_dev() {
  local dev=$1
  local bridge=$2
  local bridge_l2dev=${3:-$(pppoerelay_get_state "${bridge}")}

  pppoerelay_log "enabling relay via ${dev} for bridge ${bridge} (${bridge_l2dev})"

  # add mac address of relaying device to the list of bridge mac addresses
  local addr
  read addr < "/sys/class/net/${dev}/address"
  if [ -n "$BRIDGE_MAC_ADDRESSES" ] && ! list_contains BRIDGE_MAC_ADDRESSES ${addr} || \
      ! ebt_broute_check ppprelay_${bridge} -d ${addr} -j DROP; then
    append BRIDGE_MAC_ADDRESSES ${addr}
    ebt_broute -I ppprelay_${bridge} -d ${addr} -j DROP
  fi

  ebt_broute -A broute_${bridge} -i ${dev} -j ppprelay_${bridge}
  ebt_filter -A ppprelay_${bridge} -o ${dev} -j ppprelay
  ebt_filter -A pppcheck_${bridge} -o ${dev} -j DROP
  # last step: add relay device to bridge if not present (should never be)
  [ ! -e "/sys/class/net/${bridge_l2dev}/brif/${dev}" ] && ubus_device add ${dev} ${bridge}
}

disable_relay_dev() {
  local dev=$1
  local bridge=$2
  local bridge_l2dev=${3:-$(pppoerelay_get_state "${bridge}")}

  pppoerelay_log "disabling relay via ${dev} for bridge ${bridge} (${bridge_l2dev})"

  # first step: remove relay device from bridge if still present
  [ -e "/sys/class/net/${bridge_l2dev}/brif/${dev}" ] && ubus_device remove ${dev} ${bridge}

  ebt_broute -D broute_${bridge} -i ${dev} -j ppprelay_${bridge}
  ebt_filter -D ppprelay_${bridge} -o ${dev} -j ppprelay
  ebt_filter -D pppcheck_${bridge} -o ${dev} -j DROP
}

reload_check_interface() {
  local intf=$1

  config_get iftype ${intf} "type"
  config_get pppoerelay ${intf} "pppoerelay"

  if [ "${iftype}" != "bridge" -o -z "${pppoerelay}" ] ; then
    # stop relay
    remove_relay_bridge ${intf}
    return
  fi

  # check for new relay devices
  eval RELAY_${bridge}=''
  RELAY_CHANGED=0
  config_list_foreach "${intf}" "pppoerelay" reload_check_dev "${intf}"

  if [ ${RELAY_CHANGED} != 0 ] ; then
    # stop relay, will be restarted
    remove_relay_bridge ${intf}
    return
  fi

  # check for removed relay devices
  local tmp ; eval tmp=\"\${UCI_RELAY_UP_${bridge}}\"
  local dev
  for dev in ${tmp}
  do
    if ! list_contains RELAY_${bridge} ${dev} ; then
      # stop relay, will be restarted
      remove_relay_bridge ${intf}
      return
    fi
  done

  # relay unchanged
  append RELAY_BRIDGES ${intf}
}

reload_check_dev() {
  local dev=$1
  local intf=$2

  local bridge=$(pppoerelay_get_state "${dev}_bridge")
  [ "${bridge}" = "${intf}" ] && append RELAY_${bridge} ${dev} || RELAY_CHANGED=1
}

######
# init.d
pppoerelay_start() {
  [ -z "${UCI_STATE}" ] || pppoerelay_stop
  pppoerelay_init_state

  RELAY_BRIDGES=''
  RELAY_DEVICES=''
  config_load "network"
  config_foreach start_interface "interface"

  # save relay bridges in state
  pppoerelay_toggle_state "bridges" "${RELAY_BRIDGES}"
}

pppoerelay_stop() {
  [ -n "${UCI_STATE}" ] || return

  if [ -n "${UCI_RELAY_BRIDGES}" ]; then
    local bridge
    for bridge in ${UCI_RELAY_BRIDGES}
    do
      remove_relay_bridge ${bridge}
    done

    # no longer needed
    ebt_broute -X ppprelay
    ebt_filter -X ppprelay
  fi

  pppoerelay_clear_state
}

pppoerelay_restart() {
  pppoerelay_stop
  pppoerelay_start
}

pppoerelay_reload() {
  [ -n "${UCI_STATE}" ] || return

  RELAY_BRIDGES=''
  RELAY_DEVICES=''
  config_load "network"

  # stop relay where needed
  local bridge
  for bridge in ${UCI_RELAY_BRIDGES}
  do
    reload_check_interface ${bridge}
  done

  if [ -z "${RELAY_BRIDGES}" ]; then
    # no longer needed
    ebt_broute -X ppprelay
    ebt_filter -X ppprelay
  fi

  # start relay where needed
  config_foreach start_interface "interface"

  # save relay bridges in state
  pppoerelay_toggle_state "bridges" "${RELAY_BRIDGES}"
}

pppoerelay_hotplug_add() {
  local devname=$1
  local bridge=$2

  eval RELAY_UP=\"\${UCI_RELAY_UP_${bridge}}\"
  ! list_contains UCI_RELAY_UP_${bridge} ${devname} || return

  [ -e "/sys/class/net/${devname}" ] || return
  append RELAY_UP ${devname}
  enable_relay_dev ${devname} ${bridge}
}

pppoerelay_hotplug_remove() {
  local devname=$1
  local bridge=$2

  [ ! -e "/sys/class/net/${devname}" ] || return
  RELAY_UP=''
  local tmp ; eval tmp=\"\${UCI_RELAY_UP_${bridge}}\"
  local found=0
  local dev
  for dev in ${tmp}
  do
    [ "${dev}" = "${devname}" ] && found=1 || append RELAY_UP dev
  done
  [ ${found} = 1 ] || return

  disable_relay_dev ${devname} ${bridge}
}

pppoerelay_hotplug() {
  local action=$1
  local devname=$2

  [ -n "${UCI_STATE}" -a -n "${UCI_RELAY_BRIDGES}" ] || return

  local bridge=$(pppoerelay_get_state "${devname}_bridge")
  [ -n "${bridge}" ] || return

  pppoerelay_log "hotplug action=${action} device=${devname} bridge=${bridge}"

  pppoerelay_hotplug_${action} ${devname} ${bridge} || return
  pppoerelay_toggle_state "${bridge}_relay_up" "${RELAY_UP}"
}


pppoerelay_load_state
