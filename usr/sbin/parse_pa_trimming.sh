#defauts
ERIP_OFFSET_WL0=""
NVRAM_SET_PREFIX_RADIO_WL0=""
PA_TRIMMING_LOCAL_FILE_WL0=""
ERIP_OFFSET_WL1=""
NVRAM_SET_PREFIX_RADIO_WL1=""
PA_TRIMMING_LOCAL_FILE_WL1=""
ERIP_OFFSET_WL2=""
NVRAM_SET_PREFIX_RADIO_WL2=""
PA_TRIMMING_LOCAL_FILE_WL2=""
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
    echo "[ERROR] invalid NVRAM2RIP_CFG_FILE: $NVRAM2RIP_CFG_FILE. Stopping"
    exit 1
fi
if [ ! -d $RIP_FOLDER ]; then
    echo "[ERROR] invalid RIP_FOLDER: $RIP_FOLDER. Stopping"
    exit 1
fi
if [ ! -d $WLAN_FOLDER ]; then
    echo "[ERROR] invalid WLAN_FOLDER: $WLAN_FOLDER. Stopping"
    exit 1
fi

echo "[ENV] RIP_FOLDER=$RIP_FOLDER"

BOARD_SERIAL=""
if [  -d "/proc/rip" ]; then
    BOARD_SERIAL='CP'`cat /proc/rip/0012`
fi
echo "[ENV] BOARD_SERIAL=$BOARD_SERIAL"

check_offset() {
    ERIP_DEC=`printf '%d' 0x$1`
    if [ $ERIP_DEC -ne 61440 ] && [ $ERIP_DEC -ne 62464 ] && [ $ERIP_DEC -ne 63488 ]; then
        echo "[ERROR] invalid offset ERIP_OFFSET_WL$2: $1. Stopping"
        exit 1
    fi
}

if [ ! -z "$ERIP_OFFSET_WL0" ]; then
    ERIP_OFFSET_WL0=`printf '%x' $ERIP_OFFSET_WL0`
    check_offset $ERIP_OFFSET_WL0 0
fi
echo "[ENV] eRIP offset radio wl0: $ERIP_OFFSET_WL0"
echo "[ENV] nvram set prefix radio wl0: $NVRAM_SET_PREFIX_RADIO_WL0"
if [ ! -z $PA_TRIMMING_LOCAL_FILE_WL0 ]; then
    PA_TRIMMING_LOCAL_FILE_WL0="$WLAN_FOLDER/pa_trimming/$BOARD_SERIAL/$PA_TRIMMING_LOCAL_FILE_WL0"
fi
echo "[ENV] PA trimming local file radio wl0: $PA_TRIMMING_LOCAL_FILE_WL0"
if [ ! -z "$ERIP_OFFSET_WL1" ]; then
    ERIP_OFFSET_WL1=`printf '%x' $ERIP_OFFSET_WL1`
    check_offset $ERIP_OFFSET_WL1 1
fi
echo "[ENV] eRIP offset radio wl1: $ERIP_OFFSET_WL1"
echo "[ENV] nvram set prefix radio wl1: $NVRAM_SET_PREFIX_RADIO_WL1"
if [ ! -z $PA_TRIMMING_LOCAL_FILE_WL1 ]; then
    PA_TRIMMING_LOCAL_FILE_WL1="$WLAN_FOLDER/pa_trimming/$BOARD_SERIAL/$PA_TRIMMING_LOCAL_FILE_WL1"
fi
echo "[ENV] PA trimming local file radio wl1: $PA_TRIMMING_LOCAL_FILE_WL1"
if [ ! -z "$ERIP_OFFSET_WL2" ]; then
    ERIP_OFFSET_WL2=`printf '%x' $ERIP_OFFSET_WL2`
    check_offset $ERIP_OFFSET_WL2 2
fi
echo "[ENV] eRIP offset radio wl2: $ERIP_OFFSET_WL2"
echo "[ENV] nvram set prefix radio wl2: $NVRAM_SET_PREFIX_RADIO_WL2"
if [ ! -z $PA_TRIMMING_LOCAL_FILE_WL2 ]; then
    PA_TRIMMING_LOCAL_FILE_WL2="$WLAN_FOLDER/pa_trimming/$BOARD_SERIAL/$PA_TRIMMING_LOCAL_FILE_WL2"
fi
echo "[ENV] PA trimming local file radio wl2: $PA_TRIMMING_LOCAL_FILE_WL2"



parse_rip() {
WL=$1
ERIP_OFFSET_WL=$2
NVRAM_SET_PREFIX_RADIO_WL=$3
if [ ! -z "$ERIP_OFFSET_WL" ] && [ -f "$RIP_FOLDER/$ERIP_OFFSET_WL" ]; then
    echo "[ENV] Fetching PA parameters for wl$WL"
    PA_TRIMMING_SCRIPT_WL="$WLAN_FOLDER/set_nvram_radio_wl$WL.sh"
    if [ -f "$PA_TRIMMING_SCRIPT_WL" ]; then
        rm $PA_TRIMMING_SCRIPT_WL
    fi
    ERIP_ENTRY=`printf '%x' $((0x$ERIP_OFFSET_WL))`
    while [ -f "$RIP_FOLDER/$ERIP_ENTRY" ]
    do
        line=$(head -n 1 $RIP_FOLDER/$ERIP_ENTRY)
        echo "[LOG] $line"
        echo "nvram set $NVRAM_SET_PREFIX_RADIO_WL$line" >> $PA_TRIMMING_SCRIPT_WL
        ERIP_ENTRY=`printf '%x' $((0x$ERIP_ENTRY+0x1))`
    done
fi

}

parse_local() {
WL=$1
PA_TRIMMING_LOCAL_FILE_WL=$2
NVRAM_SET_PREFIX_RADIO_WL=$3
if [ -f "$PA_TRIMMING_LOCAL_FILE_WL" ]; then
    echo "[LOG] Fetching PA parameters for wl$WL from $PA_TRIMMING_LOCAL_FILE_WL"
    PA_TRIMMING_SCRIPT_WL="$WLAN_FOLDER/set_nvram_radio_wl$WL.sh"
    if [ -f "$PA_TRIMMING_SCRIPT_WL" ]; then
        rm $PA_TRIMMING_SCRIPT_WL
    fi
    while read -r line
    do
    echo "[LOG] $line"
        echo "nvram set $NVRAM_SET_PREFIX_RADIO_WL$line" >> $PA_TRIMMING_SCRIPT_WL
    done < $PA_TRIMMING_LOCAL_FILE_WL
fi
}

parse_rip 0 $ERIP_OFFSET_WL0 $NVRAM_SET_PREFIX_RADIO_WL0
parse_rip 1 $ERIP_OFFSET_WL1 $NVRAM_SET_PREFIX_RADIO_WL1
parse_rip 2 $ERIP_OFFSET_WL2 $NVRAM_SET_PREFIX_RADIO_WL2
parse_local 0 $PA_TRIMMING_LOCAL_FILE_WL0 $NVRAM_SET_PREFIX_RADIO_WL0
parse_local 1 $PA_TRIMMING_LOCAL_FILE_WL1 $NVRAM_SET_PREFIX_RADIO_WL1
parse_local 2 $PA_TRIMMING_LOCAL_FILE_WL2 $NVRAM_SET_PREFIX_RADIO_WL2


