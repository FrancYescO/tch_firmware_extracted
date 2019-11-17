#!/bin/sh

echo "DHCP action $1"
env

update_resolv_conf() {
  local resolv=/etc/resolv.conf
  echo "# $interface" >$resolv
  if [ -n "$dns" ]; then
    for ip in $dns ; do
      echo "nameserver $ip" >>$resolv
    done
  fi
  if [ -n "$domain" ]; then
    for d in $domain ; do
      echo "search $d" >>$resolv
    done
  fi
}

add_default_route() {
  route add default gw $router dev $interface
}

assign_address() {
  ifconfig $interface $ip ${subnet:-255.255.255.0}
}

update_config() {
  assign_address
  update_resolv_conf
  add_default_route
}

remove_config() {
  echo >/etc/resolv.conf
}

case $1 in
  renew|bound)
    update_config  
esac