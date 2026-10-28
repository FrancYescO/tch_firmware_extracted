#!/bin/sh

read portNum < /tmp/.port

start_port="$(echo $portNum | cut -d ":" -f1)"
end_port="$(echo $portNum | cut -d ":" -f2)"
if [ $start_port != $end_port ]; then
  while [ $start_port -le $end_port ]
  do
    range_use=$(conntrack -L | grep ESTABLISHED | grep -w dport=$start_port | awk -F"mark=" '/mark/{print $2}'| awk -F"use=" '/use/{print $2}')
    if [ $range_use == "1" ]; then
      echo "0" > /proc/sys/net/netfilter/nf_conntrack_tcp_loose && conntrack -D -p tcp --dport $start_port
    elif [ $range_use -gt 1 ]; then
      echo "0" > /proc/sys/net/netfilter/nf_conntrack_tcp_loose
      range_mark=$(conntrack -L | grep ESTABLISHED | grep -w dport=$start_port | awk -F"mark=" '/mark/{print $2}'| awk -F"use" '/use/{print $1}') && conntrack -D -m $range_mark
    fi
    start_port=`expr $start_port + 1`
  done
else
  use=$(conntrack -L | grep ESTABLISHED | grep -w dport=$portNum | awk -F"mark=" '/mark/{print $2}'| awk -F"use=" '/use/{print $2}')
  if [ $use == "1" ]; then
    echo "0" > /proc/sys/net/netfilter/nf_conntrack_tcp_loose && conntrack -D -p tcp --dport $portNum
  else
    echo "0" > /proc/sys/net/netfilter/nf_conntrack_tcp_loose
    mark_value=$(conntrack -L | grep ESTABLISHED | grep -w dport=$portNum | awk -F"mark=" '/mark/{print $2}'| awk -F"use" '/use/{print $1}') && conntrack -D -m $mark_value
  fi
fi
rm /tmp/.port
