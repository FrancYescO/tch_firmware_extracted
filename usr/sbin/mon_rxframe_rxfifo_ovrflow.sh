#!/bin/sh
#version=4
#set -x
WL_IFACE=wl2
if [ -f /root/reinit_cnt.txt ]; then
reinit_cnt=$(cat /root/reinit_cnt.txt)
else
reinit_cnt=0
fi
while [ true ]; do
        rxovrfl=$(wl -i $WL_IFACE counters | grep  rxf0ovfl | cut -d ' ' -f2)
        rxframe=$(wl -i $WL_IFACE counters | grep  rxframe | cut -d ' ' -f2)
        logger -t mon_rxfifo_ovrflow "rxovrfl: $rxovrfl rxframe: $rxframe Connection State: $(wl -i $WL_IFACE bss) reinit_cnt:$reinit_cnt"
        if [ $rxovrfl != 0 ]; then
                logger -t mon_rxfifo_ovrflow "rxovrfl: $rxovrfl rxframe: $rxframe"
                sleep 3
                rxovrfl2=$(wl -i $WL_IFACE counters | grep  rxf0ovfl | cut -d ' ' -f2)
                rxframe2=$(wl -i $WL_IFACE counters | grep  rxframe | cut -d ' ' -f2)
                logger -t mon_rxfifo_ovrflow "rxovrfl2: $rxovrfl2 rxframe2: $rxframe2"
                if [ $rxovrfl != $rxovrfl2 ]; then
                        if [ $rxframe == $rxframe2 ]; then
                                logger -t mon_rxfifo_ovrflow "Increase in rxf0ovfl but no increase in rxframe!"
                                logger -t mon_rxfifo_ovrflow "Is Connection (up/down)? - $(wl -i $WL_IFACE bss)"
                                logger -t mon_rxfifo_ovrflow "RUN WL REINIT NOW to recover the Link & Reset counters"
                                echo "RUN WL REINIT NOW to recover the Link" > /dev/console
                                wl -i $WL_IFACE reinit
                                reinit_cnt=$((reinit_cnt + 1))
                                sleep 10
                                logger -t mon_rxfifo_ovrflow "Is Connection (up/down)? - $(wl -i $WL_IFACE bss)"
                                wl -i $WL_IFACE reset_cnts
                        else
                                logger -t mon_rxfifo_ovrflow " rxframe and rxframe2 are not equal"
                        fi
                else
                        logger -t mon_rxfifo_ovrflow "rxovrfl and rxovrfl2 are equal"
                fi
        fi
        sleep 5
        rxovrfl=0
        rxovrfl2=0
        rxframe=0
        rxframe2=0
        echo $reinit_cnt > /root/reinit_cnt.txt
done
