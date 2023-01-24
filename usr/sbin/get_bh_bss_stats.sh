
STA=$1
SSID=$2

echo "Scaning interface : $STA"
echo "Scanning SSID     : $SSID"

wl -i "$STA" scan --ssid="$SSID" --scan_type=passive --bss_type=bss --passive=400
echo "Scanning in progress..,"

sleep 10

BSS_LIST=`wl -i wl1 scanresults | grep BSSID | awk '{print $2}'`
RSSI_LIST=`wl -i wl1 scanresults | grep RSSI | awk '{print $4}'`
CHAN_LIST=`wl -i wl1 scanresults | grep "Primary channel" | awk '{print $3}'`

outstr=`echo $BSS_LIST | wc -l`
for BSSID in $(echo "$BSS_LIST" | tr "," "\n")
do
    for RSSI in $(echo "$RSSI_LIST" | tr "," "\n")
    do
        for CHAN in $(echo "$CHAN_LIST" | tr "," "\n")
        do
            outstr=`printf "$outstr,$BSSID|$RSSI|$CHAN"`

            #Cut the processed CHANNEL from the original list
            CHAN_LIST=`echo "$CHAN_LIST" | sed '1d' `
            break
        done

	#Cut the processed RSSI from the original list
	RSSI_LIST=`echo "$RSSI_LIST" | sed '1d' `

	break
    done
done

echo "$outstr"
echo "$outstr" > /tmp/"$STA"_"$SSID"_scan_result
