#!/bin/sh
while read line;
do
        if [ -n "$line" ];then
                pid=$(COLUMNS=512 ps | grep odhcp | grep -w $line | awk '{print $1}')
                kill -SIGUSR2 $pid
                kill -SIGUSR1 $pid
        fi;
done < /tmp/.dhcpv4_release_renew_clients;
rm /tmp/.dhcpv4_release_renew_clients
