#!/bin/sh

# UCI fixes custo 

need_commit=0

#Use the wan IP for RADIUS AVP nas-ip
nas_wan_ip=`uci get network.wan.ipaddr 2> /dev/null`
if [ "$?" = "0" ] ; then    
    for ap in ap0 ap1 ap2 ap3
    do
        #Check if the ap exists
        uci get wireless.$ap 1>/dev/null 2>/dev/null
        if [ "$?" != "0" ] ; then
            continue
        fi
        cur_nas_wan_ip=`uci get wireless.$ap.nas_wan_ip 2> /dev/null`
        rv=$?
        # Change the value if the option is not set yet, or the value is different
        if [ "$rv" == "1" ] || ([ "$rv" == "0" ] && [ "$cur_nas_wan_ip" != "$nas_wan_ip" ]) ; then
            echo "Updating the nas_wan_ip for ap $ap" > /dev/console
            uci set wireless.$ap.nas_wan_ip=$nas_wan_ip 2>/dev/null
            need_commit=1
        fi 
    done
fi        

# Commit if needed
if [ "$need_commit" = "1" ]; then
    echo "Fixed wireless uci config custo" > /dev/console
    uci commit wireless
fi
