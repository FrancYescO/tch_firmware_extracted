#!/bin/sh

add_cwmpd_fw_rule() {
  local state
  local interface
  local zone
  local port
  local ip

  # Ignore /var/state for cwmpd
  unset LOAD_STATE
  config_load "cwmpd"
  LOAD_STATE=1

  config_get state cwmpd_config state 0
  config_get interface cwmpd_config interface "wan"
  zone=$(fw3 -q network "$interface")
  config_get port cwmpd_config connectionrequest_port "51007"
  config_get ip cwmpd_config connectionrequest_allowedips ""

  [ "$zone" = "wan" ] && {
    [ "$(uci_get_state system.cwmpd)" = "wan-service" ] ||
      uci_set_state system cwmpd '' wan-service
    uci_set_state system cwmpd proto tcp
    uci_set_state system cwmpd ports "$port"
  }

  # We do not (always) follow the UCI syntax and it is possible
  # to create a comma separated list
  [ -n "$ip" ] && ip=$(echo "$ip" | tr ',' ' ')

  __add_cwmpd_fw_rule "$interface" "$zone" "$port" "$ip"
}

__add_cwmpd_fw_rule() {
  local interface="$1"
  local input_zone="$2"
  local port="$3"
  local ip="$4"

  procd_open_data

  json_add_array firewall

  # Put exception to exclude this service from DMZ rules/port forwarding rules
  json_add_object ""
  json_add_string type redirect
  json_add_string src "$input_zone"
  json_add_string family any
  json_add_string proto tcp
  json_add_string src_dport "$port"
  json_add_string target DNAT
  json_close_object

  # Accept connectionRequest messages initiated on this ZONE
  json_add_object ""
  json_add_string type rule
  json_add_string src "$input_zone"
  json_add_string family any
  json_add_string proto tcp
  [ -n "$ip" ] && json_add_string src_ip "$ip"
  json_add_string dest_port "$port"
  json_add_string target ACCEPT
  json_close_object

  [ "$interface" != "lan" ] && {
    input_zone=$(fw3 -q network 'lan')

    # Target 'reject' is equal to 'REJECT' with '--reject-with tcp-reset'
    json_add_object ""
    json_add_string type rule
    json_add_string src "$input_zone"
    json_add_string family any
    json_add_string proto tcp
    json_add_string dest_port "$port"
    json_add_string target reject
    json_close_object
  }

  json_close_array

  procd_close_data
}
