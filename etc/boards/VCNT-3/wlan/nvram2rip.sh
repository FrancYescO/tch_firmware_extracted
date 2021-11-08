ERIP_START_RADIO_2G=61440 #0xF000
ERIP_START_RADIO_5G=62464 #0xF400


HEX_ERIP_START_RADIO_2G=`printf '%x' $ERIP_START_RADIO_2G`
HEX_ERIP_START_RADIO_5G=`printf '%x' $ERIP_START_RADIO_5G`
RIP_FOLDER="/proc/rip"
CACHED_RIP_FOLDER="/etc/wlan/NVRAM"
NEW_ERIP_ID="new"
LOCK_ERIP_ID="lock"

CMD=$1

print_help() {
    echo "Available commands:"
    echo "help: prints this help"
    echo "      syntax: nvram2rip.sh help"
    echo "save: saves the NVRAM parameters to eRIP"
    echo "      syntax: nvram2rip.sh save <radio 2G NVRAM file> <radio 5G NVRAM file>"
    echo "cache: saves the NVRAM parameters to local folder (not to eRIP) for debugging"
    echo "      syntax: nvram2rip.sh cache <radio 2G NVRAM file> <radio 5G NVRAM file>"
    echo "dump: dumps existing NVRAM parameters saved to eRIP"
    echo "      syntax: nvram2rip.sh dump"
    echo "lock: locks (i.e. makes it read only) the eRIP entries containing the NVRAM parameters"
    echo "      syntax: nvram2rip.sh lock"
}

save_to_erip() {
	ERIP_ENTRY=$ERIP_START_RADIO_2G
	HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
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
	done < $NVRAM_FILE_RADIO_2G

	ERIP_ENTRY=$ERIP_START_RADIO_5G
	HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
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
	done < $NVRAM_FILE_RADIO_5G
}


cache_to_erip() {
    ERIP_ENTRY=$ERIP_START_RADIO_2G
    HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
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
    done < $NVRAM_FILE_RADIO_2G

    ERIP_ENTRY=$ERIP_START_RADIO_5G
    HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
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
    done < $NVRAM_FILE_RADIO_5G
}





dump_erip() {
	echo "Radio 1:"
	ERIP_ENTRY=$ERIP_START_RADIO_2G
	HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    while [ -f "$RIP_FOLDER/$HEX_ERIP_ENTRY" ]
	do
		cat $RIP_FOLDER/$HEX_ERIP_ENTRY
		ERIP_ENTRY=`expr $ERIP_ENTRY + 1`
		HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
	done
	echo "Radio 2:"
	ERIP_ENTRY=$ERIP_START_RADIO_5G
	HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    while [ -f "$RIP_FOLDER/$HEX_ERIP_ENTRY" ]
	do
		cat $RIP_FOLDER/$HEX_ERIP_ENTRY
		ERIP_ENTRY=`expr $ERIP_ENTRY + 1`
		HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
	done
}

lock_erip() {
	ERIP_ENTRY=$ERIP_START_RADIO_2G
	HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
    while [ -f "$RIP_FOLDER/$HEX_ERIP_ENTRY" ]
	do
		echo $HEX_ERIP_ENTRY > $RIP_FOLDER/$LOCK_ERIP_ID
		ERIP_ENTRY=`expr $ERIP_ENTRY + 1`
		HEX_ERIP_ENTRY=`printf '%x' $ERIP_ENTRY`
	done
	ERIP_ENTRY=$ERIP_START_RADIO_5G
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
		NVRAM_FILE_RADIO_2G=$2
		NVRAM_FILE_RADIO_5G=$3
		if [ -f "$NVRAM_FILE_RADIO_2G" ] && [ -f "$NVRAM_FILE_RADIO_5G" ]; then
			save_to_erip
		else
			print_help
		fi
		;;
	cache)
		NVRAM_FILE_RADIO_2G=$2
		NVRAM_FILE_RADIO_5G=$3
		if [ -f "$NVRAM_FILE_RADIO_2G" ] && [ -f "$NVRAM_FILE_RADIO_5G" ]; then
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

