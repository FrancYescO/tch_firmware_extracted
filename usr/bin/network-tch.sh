#!/bin/sh /etc/rc.common

exec_init() {
  local script="/etc/init.d/$1"
  if [ ! -f "${script}" ] ; then
    echo "-- Not present : $1 --"
    return 1
  fi

  echo "##" "$@" "##"
  shift
  ${script} "$@" &>/dev/null
}

_start_physical() {
  exec_init xdsl start
  exec_init xtm start
  exec_init ethernet start
}

_stop_physical() {
  exec_init ethernet stop
  exec_init xtm stop
  exec_init xdsl stop
}

_start() {
  exec_init hostapd start

  exec_init pppoe-relay start
  exec_init pppoe-relay-tch start

  exec_init firewall start
  exec_init intercept start
  exec_init qos start

  exec_init mwan start
  exec_init dnsmasq start
  exec_init mcsnooper start
  exec_init igmpproxy start
  exec_init mldproxy start
}

_stop() {
  exec_init mldproxy stop
  exec_init igmpproxy stop
  exec_init mcsnooper stop
  exec_init dnsmasq stop
  exec_init mwan stop

  exec_init qos stop
  exec_init intercept stop
  exec_init firewall stop

  exec_init pppoe-relay-tch stop
  exec_init pppoe-relay stop

  exec_init hostapd stop  
}

# Problematic (NG-73786)
stop() {
  _stop
  exec_init network stop
  [ "${PHYSICAL}" != "y" ] || _stop_physical
}

# Problematic (NG-73786)
start() {
  [ "${PHYSICAL}" != "y" ] || _start_physical
  exec_init network start
  _start
}

restart() {
  _stop
  if [ "${PHYSICAL}" = "y" ] ; then
    _stop_physical
    _start_physical
  fi
  exec_init network restart
  _start
}

