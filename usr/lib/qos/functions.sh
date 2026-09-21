
qos_started() {
  /sbin/uci -q -p /var/state get qos.state > /dev/null
}

