#!/bin/sh

read pfwInfo < /tmp/.pfw

port_num=$(echo $pfwInfo | cut -d " " -f 1)
proto=$(echo $pfwInfo | cut -d " " -f 2)
lan_ip=$(echo $pfwInfo | cut -d " " -f 3)
start_port=$(echo $port_num | cut -d ":" -f1)
end_port=$(echo $port_num | cut -d ":" -f2)
wan_ip=$(ifstatus wan | jsonfilter -e '@["ipv4-address"][0].address')

[ -z "$wan_ip" ] && exit 0
[ "$proto" == "tcpudp" ] && proto="tcp udp"

for port in $(seq $start_port $end_port); do
  for p in $proto; do
    conntrack -D -g $lan_ip -d $wan_ip -p $p --dport $port
  done
done

rm /tmp/.pfw
