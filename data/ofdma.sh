#!/bin/sh
#set -x

GetULConfig () {
    # MCS7
    case "$giltf $numheltf"  in
    "1 1")
    maxdur=5200
    ul_lsig_len=4084
    ;;
    *)
    maxdur=5200
    ul_lsig_len=4078
    esac
    # For HE-4.40.1 2.4G, manual assign
    #maxdur=5200
    #ul_lsig_len=4078
    echo "Use: $maxdur : $ul_lsig_len" >> $logfile
}

GetDefaultRUIDX () {
    if [ "$ruidx_fix" != "" ]; then
        ruidx=$ruidx_fix
    else
        case "$users $bw"  in
            "3 20" | "4 20")
            ruidx=37
            ;;
            "2 20" | "3 40" | "4 40")
            ruidx=53
            ;;
            "1 20" | "2 40" | "3 80" | "4 80")
            ruidx=61
            ;;
            "1 40" | "2 80")
            ruidx=65
            ;;
            "1 80")
            ruidx=67
            ;;
            *)
            ruidx=61
        esac
    fi
    echo "ruidx = $ruidx" >> $logfile
}

MCS2HEX () {
    if [ "$mcs" == "10" ]; then
        mcshex=a
    elif [ "$mcs" == "11" ]; then
        mcshex=b
    else
        mcshex=$mcs
    fi
}

PKTENG () {
    if [ "$ul" == 1 ]; then
	    wl -i $ifname pkteng_cmd -k txtrig_cnt 0
        echo "stop txtrig before init" >> $logfile
    fi
    sleep 1
    echo "wl pkteng_cmd --init" >> $logfile
    wl -i $ifname pkteng_cmd --init
    echo "wl pkteng_cmd pkteng_cmd -k updsta 1" >> $logfile
    wl -i $ifname pkteng_cmd -k updsta 1
    GetDefaultRUIDX
    if [ "$giltffix" == "" ]; then
        giltf=1
    else
        giltf=$giltffix
    fi
    if [ "$ul" == 1 ]; then
	    wl -i $ifname txpwr1 -o -d 10
	    if [ "$trig_type" == 4 ]; then
		wl -i $ifname pkteng_cmd -k txtrig_type 4
	    fi
	    wl -i $ifname pkteng_cmd -k ul_bw $bw
	    # numheltf 1 : 1/2ss.
	    numheltf=1
	    wl -i $ifname pkteng_cmd -k numheltf $numheltf
	    if [ "$lsigfix" != "" ]; then
		ul_lsig_len=$lsigfix
	    else
		GetULConfig
		#ul_lsig_len=4078
	    fi
	    #GetULConfig
	    wl -i $ifname pkteng_cmd -k ul_lsig_len $ul_lsig_len
	    #wl -i $ifname pkteng_cmd -k maxdur $maxdur
        # removed for ul_pe should always be 4. keep the defaults
	    # wl -i $ifname pkteng_cmd -k ul_pe 0
	    wl -i $ifname pkteng_cmd -k ul_cp_ltftype $giltf
    else
	    # DL
	    echo "wl pkteng_cmd -k mcs $mcs" >> $logfile
	    wl -i $ifname pkteng_cmd -k mcs $mcs
	    echo "wl pkteng_cmd -k ru $ruidx" >> $logfile
	    wl -i $ifname pkteng_cmd -k ru $ruidx
        echo "DL gi_ltf 2" >> $logfile
	    wl -i $ifname pkteng_cmd -k gi_ltf 2
    fi
}

PKTENG_2 () {
    if [ "$ldpcfix" != "" ]; then
	    ldpc=$ldpcfix
    else
	    #ldpc=$(wl -i $ifname ldpc_cap)
	    ldpc=$(wl -i $ifname sta_info $macaddr | grep "HE caps" | grep -c LDPC)
    fi

    nss=$(wl -i $ifname sta_info $macaddr | grep -c NSS)
    aidtmp=$(wl -i $ifname sta_info $macaddr | grep aid )
    aid=$(echo ${aidtmp:6})

    if [ "$mcsfix" == "" ]; then
	    mcstmp=$(wl -i $ifname sta_info $macaddr | grep NSS1| grep -oe -[0-9]*)
	    mcs=$(echo ${mcstmp:1:2})
    else
	    mcs=$mcsfix
    fi
    echo "$macaddr: aid:$aid, nss:$nss, mcs:$mcs" >> $logfile
    MCS2HEX
    
    if [ "$ul" == 1 ]; then
	    if [ "$sounding" == 1 ]; then
		    wl -i $ifname pkteng_cmd -u $((aid-1)) $macaddr $aid $((ruidx+cnt)) 0x$nss$mcshex $ldpc 0 0 65 255 
	    else
		    wl -i $ifname pkteng_cmd -u $((aid-1)) $macaddr $aid $((ruidx+cnt)) 0x$nss$mcshex $ldpc 0 0 65 -1
	    fi
	    if [ "$target_rssi" != "" ]; then
		    wl -i $ifname pkteng_cmd -k target_rssi $target_rssi
	    fi
    else
        wl -i $ifname pkteng_cmd -k nss $nss
    fi
}
PKTENG_3 () {
    wl -i $ifname pkteng_cmd -k ul_ap_txpwr 30
    wl -i $ifname pkteng_cmd -k manual_ul 1
    wl -i $ifname pkteng_cmd -k ul_cs_req 1
    wl -i $ifname pkteng_cmd -k sch 2
    wl -i $ifname pkteng_cmd -k txtrig_rate 6
    #wl -i $ifname pkteng_cmd -k txtrig_sch 1
    wl -i $ifname pkteng_cmd -k txtrig_sch 0
    echo "==pkteng_cmd==" >> $logfile
    wl -i $ifname pkteng_cmd >> $logfile
    echo "==start_trigger = $start_trigger ==" >> $logfile
    if [ "$start_trigger" == 1 ]; then
    	wl -i $ifname pkteng_cmd -k txtrig_cnt 0xffff
    elif [ "$start_trigger" == 2 ]; then
        while true; do
            wl -i $ifname pkteng_cmd -k txtrig_cnt 1
            cnt=40
            while true; do
                if [ "$cnt" -lt 1 ]; then
                    break
                fi
                cnt=$((cnt-1))
            done
        done
    elif [ "$start_trigger" == 3 ]; then
	cnt=0
        while true; do
	    wl -i $ifname pkteng_cmd -k txtrig_type 0
	    wl -i $ifname pkteng_cmd -k sch 2
	    wl -i $ifname pkteng_cmd -k txtrig_cnt 0xffff
	    sleep 2
	    wl -i $ifname pkteng_cmd -k txtrig_type 4 
	    wl -i $ifname pkteng_cmd -k sch 2
	    wl -i $ifname pkteng_cmd -k txtrig_cnt 0xffff
	    sleep 1
	done
    fi
    if [ "$trigger_interval" != "" ]; then
        wl -i $ifname pkteng_cmd -k txtrig_cnt 0xffff
        wl -i $ifname pkteng_trgtmr $trigger_interval
    fi
}


# start of main script

timeout=0
logfile=/data/ofdma.log
if [ -f $logfile ]; then
    cp $logfile ${logfile}.old
fi
echo "" > $logfile
echo "timeout: $timeout" >> $logfile

ul=1
ldpc=1
start_trigger=0


while [[ $# -gt 0 ]]
do
key="$1"

case $key in
-r|--ruidx_fix)
ruidx_fix="$2"
shift # past argument
shift # past value
;;
-i|--ifname)
ifname="$2"
shift # past argument
shift # past value
;;
-m|--mcs)
mcsfix="$2"
shift # past argument
shift # past value
;;
-b|--bw)
bw="$2"
shift # past argument
shift # past value
;;
-l|--ldpc)
ldpcfix="$2"
shift # past argument
shift # past value
;;
-u|--ul)
ul="$2"
shift # past argument
shift # past value
;;
-lsig|--ul_lsig_len)
lsigfix="$2"
shift # past argument
shift # past value
;;
-maxdur|--maxdur)
maxdurfix="$2"
shift # past argument
shift # past value
;;
-giltf|--giltf)
giltffix="$2"
shift # past argument
shift # past value
;;
--start_trigger)
start_trigger="$2"
shift # past argument
shift # past value
;;
--trigger_interval)
trigger_interval="$2"
shift # past argument
shift # past value
;;
--target_rssi)
target_rssi="$2"
shift # past argument
shift # past value
;;
-snd|--sounding)
sounding="$2"
shift # past argument
shift # past value
;;
-trig_type|--trigger_type)
trig_type="$2"
shift # past argument
shift # past value
;;
*)    # unknown option
shift # past argument
shift # past value
;;
esac
done

if [ "$mcsfix" != "" ]; then
    mcs=$mcsfix
else
    mcs=7
fi
if [ "$maxdurfix" != "" ]; then
	maxdur=$maxdurfix
	#else
	#maxdur=5200
fi

users=0
stalen=0
echo "init pkteng" >> $logfile
wl -i $ifname pkteng_cmd --init
wl -i $ifname txbf_rateset -b -v 0xfff 0xfff 0xfff 0xfff
wl -i $ifname txbf_rateset -v 0xfff 0xfff 0xfff 0xfff
echo "==txbf_rateset==" >> $logfile
wl -i $ifname txbf_rateset >> $logfile
# check associate list, kick-in pkteng
while true
do
stas=$(wl -i $ifname assoclist)
echo "# of stas = ${#stas}" >> $logfile
echo "sta list = $stas" >> $logfile

if [ "$stas" == "$staold" ]; then
	echo "timeout: $timeout" >> $logfile
	if [ "$timeout" -gt 3600 ]; then
        echo "stop trig because of timeout" >> $logfile
		wl -i $ifname pkteng_cmd -k txtrig_cnt 0
		break
	else
		sleep 1
		timeout=$((timeout+1))
	fi
else
	staold=$stas
	if [ "${#stas}" -eq 27 ]; then
		users=1
		sta1=$(echo ${stas:10:17})
		allsta="$sta1"
		echo "1 STA assoc" >> $logfile
	elif [ "${#stas}" -eq 55 ]; then
		users=2
		sta1=$(echo ${stas:10:17})
		sta2=$(echo ${stas:38})
		allsta="$sta2 $sta1"
		echo "2 STA assoc" >> $logfile
	elif [ "${#stas}" -eq 83 ]; then
		users=3
		sta1=$(echo ${stas:10:17})
		sta2=$(echo ${stas:38:17})
		sta3=$(echo ${stas:66:17})
		allsta="$sta3 $sta2 $sta1"
		echo "3 STA assoc" >> $logfile
	elif [ "${#stas}" -gt 110 ]; then
		users=4
		sta1=$(echo ${stas:10:17})
		sta2=$(echo ${stas:38:17})
		sta3=$(echo ${stas:66:17})
		sta4=$(echo ${stas:94:17})
		allsta="$sta4 $sta3 $sta2 $sta1"
		echo "4 STA assoc" >> $logfile
	elif [ "${#stas}" -eq 0 ]; then
		wl -i $ifname pkteng_cmd -k txtrig_cnt 0
		echo "stop trig in 0 assco " >> $logfile
		break
	fi

	# Get STA aid and nss first then set accordingly
	PKTENG
	cnt=0
	for macaddr in $allsta ; do
		PKTENG_2
		cnt=$((cnt+1))
	done
	if [ "$ul" == 1 ]; then
	    PKTENG_3
    else
        echo "wl pkteng_cmd -k sch 1" >> $logfile
        wl -i $ifname pkteng_cmd -k sch 1
	fi
	#ruidx=""
fi
done
