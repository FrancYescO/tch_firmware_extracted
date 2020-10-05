#!/bin/sh
. /usr/share/libubox/jshn.sh

#1) Check if all AP exist
for ap in $1 
do
    uci show wireless.$ap 2>/dev/null >/dev/null
    if [ "$?" -ne "0" ] 
    then
        echo "$ap is not a valid ap object"   
        exit 1 
    fi
done

#2) Stop WPS on all AP..
ubus -S call wireless.accesspoint.wps enrollee_pbc '{"event":"stop"}'

#3) Start WPS again...
for ap in $1
do
    json_init
    json_add_string name "$ap"
    cmd="ubus -S call wireless.accesspoint.wps enrollee_pbc '$(json_dump)'"   
    $(eval $cmd)
done

exit 0

