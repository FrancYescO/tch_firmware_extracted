ERIP_START_RADIO1=61440 #0xF000

#for debugging with shifted eRIP entries
#ERIP_START_RADIO1=`expr 61440 + 32` #0xF000


HEX_ERIP_START_RADIO1=`printf '%x' $ERIP_START_RADIO1`
RIP_FOLDER="/proc/rip"
CACHED_RIP_FOLDER="/etc/wlan/NVRAM"
#RIP_FOLDER="/Users/dragosi/Downloads/NVRAM2RIP"
NEW_ERIP_ID="new"
LOCK_ERIP_ID="lock"

CMD=$1

print_help() {
    echo "Available commands:"
    echo "help: prints this help"
    echo "      syntax: nvram2rip.sh help"
    echo "save: saves the NVRAM parameters to eRIP"
    echo "      syntax: nvram2rip.sh save <radio 5G NVRAM file>"
    echo "cache: saves the NVRAM parameters to local folder (not to eRIP) for debugging"
    echo "      syntax: nvram2rip.sh cache <radio 5G NVRAM file>"
    echo "dump: dumps existing NVRAM parameters saved to eRIP"
    echo "      syntax: nvram2rip.sh dump"
    echo "lock: locks (i.e. makes it read only) the eRIP entries containing the NVRAM parameters"
    echo "      syntax: nvram2rip.sh lock"
}

save_to_erip() {
    ERIP_ENTRY=$ERIP_START_RADIO1
    HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    # find the first available eRIP ID starting from 0xF000
    #while [ -f "$RIP_FOLDER/$HEX_ERIP_ENTRY" ]
    #do
    #    ERIP_ENTRY=`expr $ERIP_ENTRY + 1`
    #    HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    #done
    while read -r line
    do
        if [ ! -f "$RIP_FOLDER/$HEX_ERIP_ENTRY" ]; then
            echo "Creating eRIP entry $RIP_FOLDER/$HEX_ERIP_ENTRY"
            echo $HEX_ERIP_ENTRY > $RIP_FOLDER/$NEW_ERIP_ID
        fi
        echo $line
        printf $line > $RIP_FOLDER/$HEX_ERIP_ENTRY
        ERIP_ENTRY=`expr $ERIP_ENTRY + 1`
        HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    done < $NVRAM_FILE_RADIO1
}

cache_to_erip() {
    ERIP_ENTRY=$ERIP_START_RADIO1
    HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    # find the first available eRIP ID starting from 0xF000
    #while [ -f "$RIP_FOLDER/$HEX_ERIP_ENTRY" ]
    #do
    #    ERIP_ENTRY=`expr $ERIP_ENTRY + 1`
    #    HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    #done
    mkdir $CACHED_RIP_FOLDER
    while read -r line
    do
        if [ ! -f "$CACHED_RIP_FOLDER/$HEX_ERIP_ENTRY" ]; then
            echo "Creating cached eRIP entry $CACHED_RIP_FOLDER/$HEX_ERIP_ENTRY"
            touch $CACHED_RIP_FOLDER/$HEX_ERIP_ENTRY
        fi
        echo $line
        printf $line > $CACHED_RIP_FOLDER/$HEX_ERIP_ENTRY
        ERIP_ENTRY=`expr $ERIP_ENTRY + 1`
        HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    done < $NVRAM_FILE_RADIO1
}




dump_erip() {
    echo "Radio 5G:"
    ERIP_ENTRY=$ERIP_START_RADIO1
    HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    while [ -f "$RIP_FOLDER/$HEX_ERIP_ENTRY" ]
    do
        cat $RIP_FOLDER/$HEX_ERIP_ENTRY
        ERIP_ENTRY=`expr $ERIP_ENTRY + 1`
        HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    done
}

lock_erip() {
    ERIP_ENTRY=$ERIP_START_RADIO1
    HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    while [ -f "$RIP_FOLDER/$HEX_ERIP_ENTRY" ]
    do
        echo $HEX_ERIP_ENTRY > $RIP_FOLDER/$LOCK_ERIP_ID
        ERIP_ENTRY=`expr $ERIP_ENTRY + 1`
        HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    done
}

case $CMD in
    help)
        print_help
        ;;
    save)
        NVRAM_FILE_RADIO1=$2
        if [ -f "$NVRAM_FILE_RADIO1" ]; then
            save_to_erip
        else
            print_help
        fi
        ;;
    cache)
        NVRAM_FILE_RADIO1=$2
        if [ -f "$NVRAM_FILE_RADIO1" ]; then
            cache_to_erip
        else
            print_help
        fi
        ;;
    dump)
        dump_erip
        ;;
    lock)
        lock_erip
        ;;
    *)
        print_help
        ;;
esac

