#!/bin/sh

read portNum < /tmp/.port
use=$(conntrack -L | grep ESTABLISHED | grep -w dport=$portNum | awk -F"mark=" '/mark/{print $2}'| awk -F"use=" '/use/{print $2}')
if [ $use == "1" ]; then
  echo "0" > /proc/sys/net/netfilter/nf_conntrack_tcp_loose && conntrack -D -p tcp --dport $portNum
else
  echo "0" > /proc/sys/net/netfilter/nf_conntrack_tcp_loose
  mark_value=$(conntrack -L | grep ESTABLISHED | grep -w dport=$portNum | awk -F"mark=" '/mark/{print $2}'| awk -F"use" '/use/{print $1}') && conntrack -D -m $mark_value
fi
rm /tmp/.port