#!/bin/sh /etc/rc.common

USE_PROCD=1

enable_udpecho() {
  local iptablesinscmd
  local interfaceIP
  config_get enable "$1" Enable
  config_get sourceip "$1" SourceIPAddress
  config_get port "$1" UDPPort
  config_get intf "$1" Interface
  if [ -z "$intf" ]; then
    iptables -D INPUT -j ACCEPT -p udp --dport ${port} -s ${sourceip} 2> /dev/null
    iptablesinscmd="iptables -I INPUT -j ACCEPT -p udp --dport ${port} -s ${sourceip}"
    interfaceIP="0.0.0.0"
  else
    iptables -D zone_${intf}_input -j ACCEPT -p udp --dport ${port} -s ${sourceip} 2> /dev/null
    iptablesinscmd="iptables -I zone_${intf}_input -j ACCEPT -p udp --dport ${port} -s ${sourceip}"
    interfaceIP="$(ubus call network.interface.${intf} status | jsonfilter -e "@['ipv4-address'][0].address" 2> /dev/null)"
  fi
  if [ "$enable" = "1" ]; then
    if [ -z "$interfaceIP" -o "$sourceip" = "0.0.0.0" -o "$port" = "0" ]; then
      uci_set udpechoconfig "$1" Enable 0
      uci_commit udpechoconfig
      return 0
    fi
    $iptablesinscmd
    mkdir -p /tmp/tr143
    rm -f /tmp/tr143/udp_echo_${1}.out
    config_get echoplusenabled "$1" EchoPlusEnabled
    procd_open_instance
    procd_set_param command /usr/bin/udp_echo ${interfaceIP} ${sourceip} ${port} ${echoplusenabled} /tmp/tr143/udp_echo_${1}.out
    procd_close_instance
  fi
}

start_service() {
  config_load udpechoconfig
  config_foreach enable_udpecho udpechoconfig
}
