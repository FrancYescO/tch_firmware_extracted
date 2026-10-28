pa_trimming_script_2G=/etc/wlan/apply_pa_trim_2G.sh
pa_trimming_script_5G=/etc/wlan/apply_pa_trim_5G.sh
nvram_set_radio_2G_prefix="2:"
nvram_set_radio_5G_prefix="1:"
ERIP_START_RADIO_2G=61440 #0xF000
ERIP_START_RADIO_5G=62464 #0xF400

HEX_ERIP_START_RADIO_2G=`printf '%x' $ERIP_START_RADIO_2G`
HEX_ERIP_START_RADIO_5G=`printf '%x' $ERIP_START_RADIO_5G`
RIP_FOLDER="/proc/rip"
CACHED_RIP_FOLDER="/etc/wlan/NVRAM"

if [ -f "$RIP_FOLDER/$HEX_ERIP_START_RADIO_2G" ] && [ -f "$RIP_FOLDER/$HEX_ERIP_START_RADIO_5G" ]; then
    echo "Fetching the eRIP PA parameters"

    rm $pa_trimming_script_2G
    ERIP_ENTRY=$ERIP_START_RADIO_2G
    HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    echo "Radio 2G:"
    while [ -f "$RIP_FOLDER/$HEX_ERIP_ENTRY" ]
    do
        line=$(head -n 1 $RIP_FOLDER/$HEX_ERIP_ENTRY)
        echo $line
        echo "nvram set "$nvram_set_radio_2G_prefix$line >> $pa_trimming_script_2G
        ERIP_ENTRY=`expr $ERIP_ENTRY + 1`
        HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    done

    rm $pa_trimming_script_5G
    ERIP_ENTRY=$ERIP_START_RADIO_5G
    HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    echo "Radio 5G:"
    while [ -f "$RIP_FOLDER/$HEX_ERIP_ENTRY" ]
    do
        line=$(head -n 1 $RIP_FOLDER/$HEX_ERIP_ENTRY)
        echo $line
        echo "nvram set "$nvram_set_radio_5G_prefix$line >> $pa_trimming_script_5G
        ERIP_ENTRY=`expr $ERIP_ENTRY + 1`
        HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    done
elif [ -f "$CACHED_RIP_FOLDER/$HEX_ERIP_START_RADIO_2G" ] && [ -f "$CACHED_RIP_FOLDER/$HEX_ERIP_START_RADIO_5G" ]; then
    echo "Fetching the cached eRIP PA parameters"
    rm $pa_trimming_script_2G
    ERIP_ENTRY=$ERIP_START_RADIO_2G
    HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    echo "Radio 2G:"
    while [ -f "$CACHED_RIP_FOLDER/$HEX_ERIP_ENTRY" ]
    do
        line=$(head -n 1 $CACHED_RIP_FOLDER/$HEX_ERIP_ENTRY)
        echo $line
        echo "nvram set "$nvram_set_radio_2G_prefix$line >> $pa_trimming_script_2G
        ERIP_ENTRY=`expr $ERIP_ENTRY + 1`
        HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    done
    rm $pa_trimming_script_5G
    ERIP_ENTRY=$ERIP_START_RADIO_5G
    HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    echo "Radio 5G:"
    while [ -f "$CACHED_RIP_FOLDER/$HEX_ERIP_ENTRY" ]
    do
        line=$(head -n 1 $CACHED_RIP_FOLDER/$HEX_ERIP_ENTRY)
        echo $line
        echo "nvram set "$nvram_set_radio_5G_prefix$line >> $pa_trimming_script_5G
        ERIP_ENTRY=`expr $ERIP_ENTRY + 1`
        HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    done
else
    echo "No PA Trimming for this board"

fi


