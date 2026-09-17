#!/bin/sh
# version=4
# set -x
WL_IFACE=wl0

# Initialize reboot counter
reset_cnt=0

while true; do
    # Fetch reinit counter value
    reinit_counter1=$(wl -i $WL_IFACE counters | awk '/reinitreason_counts/ {print $4}' | awk -F'[()]' '{print $2}')

    if [ "$reinit_counter1" -ge 9 ]; then
        # Fetch txop value
        txop_value=$(wl -i $WL_IFACE chanim_stats | awk 'NR==3 {print $8}')
        echo "Mon_reinit: Txop Value: $txop_value" > /dev/console

        if [ "$txop_value" -eq 0 ]; then
            txop_cnt=1
            while [ "$txop_cnt" -le 6 ]; do
                sleep 5
                txop_value=$(wl -i $WL_IFACE chanim_stats | awk 'NR==3 {print $8}')
                if [ "$txop_value" -eq 0 ]; then
                    txop_cnt=$((txop_cnt + 1))
                else
                    txop_cnt=0
                    break
                fi
            done

	    # If txop count reaches 6(30sec), take action
            if [ "$txop_cnt" -ge 6 ]; then
                current_channel=$(wl -i $WL_IFACE channel | awk '/current mac channel/ {print $4}')
                reset_cnt=$((reset_cnt + 1))
                echo "Mon_reinit: PSM_WD exceeded and txop has been 0 for too long, so changing channel" > /dev/console
                wl -i $WL_IFACE down
                sleep 2
                if [ "$current_channel" -eq 1 ]; then
                    wl -i $WL_IFACE channel 6
                fi
                if [ "$current_channel" -eq 6 ]; then
                    wl -i $WL_IFACE channel 11
                fi
                if [ "$current_channel" -eq 11 ]; then
                    wl -i $WL_IFACE channel 1
                fi
                sleep 2
                wl -i $WL_IFACE up
                sleep 2
            fi
        fi
    fi
    sleep 10
done
