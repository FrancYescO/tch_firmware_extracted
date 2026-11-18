#defauts
ERIP_OFFSET_WL0=""
ERIP_OFFSET_WL1=""
ERIP_OFFSET_WL2=""
RIP_FOLDER=""
WLAN_FOLDER=""

if [  -d "/proc/rip" ]; then
    NVRAM2RIP_CFG_FILE="/etc/wlan/nvram2rip.cfg"
else
    NVRAM2RIP_CFG_FILE="/home/dragosi/NVRAM2RIP/etc/wlan/nvram2rip.cfg"
fi




echo "[ENV] NVRAM2RIP_CFG_FILE=$NVRAM2RIP_CFG_FILE"


if [ -f "$NVRAM2RIP_CFG_FILE" ]; then
    source $NVRAM2RIP_CFG_FILE
else
    echo "invalid NVRAM2RIP_CFG_FILE: $NVRAM2RIP_CFG_FILE. Stopping"
    exit 1
fi
if [ ! -d $RIP_FOLDER ]; then
    echo "invalid RIP_FOLDER: $RIP_FOLDER. Stopping"
    exit 1
fi
if [ ! -d $WLAN_FOLDER ]; then
    echo "invalid WLAN_FOLDER: $WLAN_FOLDER. Stopping"
    exit 1
fi

echo "[ENV] RIP_FOLDER=$RIP_FOLDER"
echo "[ENV] WLAN_FOLDER=$WLAN_FOLDER"

NEW_ERIP_ID="new"
echo "[ENV] NEW_ERIP_ID=$NEW_ERIP_ID"

NVRAM_PA_FILE_WL0=""
NVRAM_PA_FILE_WL1=""
NVRAM_PA_FILE_WL2=""

check_offset() {
    ERIP_DEC=`printf '%d' 0x$1`
    if [ $ERIP_DEC -ne 61440 ] && [ $ERIP_DEC -ne 62464 ] && [ $ERIP_DEC -ne 63488 ]; then
        echo "invalid offset ERIP_OFFSET_WL$2: $1. Stopping"
        exit 1
    fi
}



if [ ! -z "$ERIP_OFFSET_WL0" ]; then
    ERIP_OFFSET_WL0=`printf '%x' $ERIP_OFFSET_WL0`
    check_offset $ERIP_OFFSET_WL0 0
fi
echo "[ENV] eRIP offset radio wl0: $ERIP_OFFSET_WL0"
if [ ! -z "$ERIP_OFFSET_WL1" ]; then
    ERIP_OFFSET_WL1=`printf '%x' $ERIP_OFFSET_WL1`
    check_offset $ERIP_OFFSET_WL1 1
fi
echo "[ENV] eRIP offset radio wl1: $ERIP_OFFSET_WL1"
if [ ! -z "$ERIP_OFFSET_WL2" ]; then
    ERIP_OFFSET_WL2=`printf '%x' $ERIP_OFFSET_WL2`
    check_offset $ERIP_OFFSET_WL2 2
fi
echo "[ENV] eRIP offset radio wl2: $ERIP_OFFSET_WL2"




print_help() {
    echo "[HELP] Available commands:"
    echo "[HELP] help: prints this help"
    echo "[HELP]       e.g: nvram2rip.sh help"
    echo "[HELP] save: saves the NVRAM parameters to eRIP"
    echo "[HELP]       e.g: nvram2rip.sh save -0 wl0_nvram_pa.txt -1 wl1_nvram_pa.txt -2 wl2_nvram_pa.txt"
    echo "[HELP] dump: dumps existing NVRAM parameters saved to eRIP or cache"
    echo "[HELP]       e.g.: nvram2rip.sh dump"
}

save_to_erip() {
    WL=$1
    ERIP_OFFSET_WL=$2
    NVRAM_PA_FILE_WL=$3

    if [ ! -z "$ERIP_OFFSET_WL" ]  && [ -f "$NVRAM_PA_FILE_WL" ]; then
        echo "[ENV] eRIP offset for radio wl$WL: $ERIP_OFFSET_WL"
        echo "[ENV] PA file for radio wl$WL: $NVRAM_PA_FILE_WL"
        ERIP_ENTRY=`printf '%x' $((0x$ERIP_OFFSET_WL))`
        while read -r line
        do
            echo "[LOG] ERIP_ENTRY="$RIP_FOLDER/$ERIP_ENTRY""
            if [ ! -f "$RIP_FOLDER/$ERIP_ENTRY" ]; then
                echo "[LOG] Creating eRIP entry $RIP_FOLDER/$ERIP_ENTRY"
                echo $ERIP_ENTRY > $RIP_FOLDER/$NEW_ERIP_ID
            fi
            echo "[LOG] $line"
            echo $line > $RIP_FOLDER/$ERIP_ENTRY
            ERIP_ENTRY=`printf '%x' $((0x$ERIP_ENTRY+0x1))`
        done < $NVRAM_PA_FILE_WL
    else
        echo "[ENV] Skipping PA trimming for radio wl$WL"
        if [ -z "$ERIP_OFFSET_WL" ]; then
            echo "[ENV] invalid eRIP offset for radio wl$WL: $ERIP_OFFSET_WL"
        fi
        if [ ! -f "$NVRAM_PA_FILE_WL" ]; then
            echo "[ENV] invalid PA file for radio wl$WL: $NVRAM_PA_FILE_WL"
        fi
    fi
}

dump_erip() {
    WL=$1
    ERIP_OFFSET_WL=$2
    if [ ! -z "$ERIP_OFFSET_WL" ]; then
        echo "[ENV] radio: wl$WL"
        ERIP_ENTRY=`printf '%x' $((0x$ERIP_OFFSET_WL))`
        while [ -f "$RIP_FOLDER/$ERIP_ENTRY" ]
        do
            cat $RIP_FOLDER/$ERIP_ENTRY
            ERIP_ENTRY=`printf '%x' $((0x$ERIP_ENTRY+0x1))`
        done
    else
        echo "[ENV] invalid eRIP offset for radio wl$WL: $ERIP_OFFSET_WL"
    fi
}

CMD=$1
case $CMD in
    help)
        print_help
        ;;
    save)
        shift # remove save from argument list
        while getopts ":0:1:2:" opt; do
            case $opt in
                0 )
                    echo "[ENV] wl0 PA trimming file: $OPTARG"
                    NVRAM_PA_FILE_WL0=$OPTARG
                    if [ ! -f "$NVRAM_PA_FILE_WL0" ]; then
                        echo "[ERROR] invalid PA file for wl0: $NVRAM_PA_FILE_WL0. Stopping."
                        exit 1
                    fi
                ;;
                1 )
                    echo "[ENV] wl1 PA trimming file: $OPTARG"
                    NVRAM_PA_FILE_WL1=$OPTARG
                    if [ ! -f "$NVRAM_PA_FILE_WL1" ]; then
                        echo "[ERROR] invalid PA file for wl1: $NVRAM_PA_FILE_WL1. Stopping."
                        exit 1
                    fi
                    ;;
                2 )
                    echo "[ENV] wl2 PA trimming file: $OPTARG"
                    NVRAM_PA_FILE_WL2=$OPTARG
                    if [ ! -f "$NVRAM_PA_FILE_WL2" ]; then
                        echo "[ERROR] invalid PA file for wl2: $NVRAM_PA_FILE_WL2. Stopping."
                        exit 1
                    fi
                    ;;
            esac
        done
        save_to_erip 0 $ERIP_OFFSET_WL0 $NVRAM_PA_FILE_WL0
        save_to_erip 1 $ERIP_OFFSET_WL1 $NVRAM_PA_FILE_WL1
        save_to_erip 2 $ERIP_OFFSET_WL2 $NVRAM_PA_FILE_WL2
      ;;
    dump)
        dump_erip 0 $ERIP_OFFSET_WL0
        dump_erip 1 $ERIP_OFFSET_WL1
        dump_erip 2 $ERIP_OFFSET_WL2
        ;;
    *)
        print_help
        ;;
esac
