#!/bin/sh
while read line;
do
        if [ -n "$line" ];then
                pid=$(COLUMNS=512 ps | grep odhcp6 | grep -w $line | awk '{print $1}')
                kill -SIGUSR2 $pid
                kill -SIGUSR1 $pid
        fi;
done < /tmp/.dhcpv6_release_renew_clients;
rm /tmp/.dhcpv6_release_renew_clients
