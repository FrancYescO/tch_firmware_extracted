#!/bin/sh
# This script is for getting related message from SFP
print_help ()
{
  echo "sfp_get.sh -s pon/lan [option]"
  echo "-s                     : Select the port, it could be pon or lan, default is pon"
  echo "--allstats             : All SFP stats"
  echo "--state                : ONU state"
  echo "--counter_reset        : SFP reset all counter"
  echo "--optical_info         : SFP optical info"
  echo "--bytes_sent           : SFP sent bytes "
  echo "--bytes_rec            : SFP received bytes "
  echo "--packets_sent         : SFP sent packets "
  echo "--packets_rec          : SFP received packets "
  echo "--errors_sent          : SFP sent errors "
  echo "--errors_rec           : SFP received errors "
  echo "--discardpackets_sent  : SFP sent discard  packets "
  echo "--discardpackets_rec   : SFP received discard packets "
  echo "--help                 : Dump the info text"
  exit 1
}

port=pon
TOPIC=config

for i in x x x x x x x x x x x x x x # at most 14 '-' type arguments
do
  case "$1" in
    -s) port=$2;
	shift;
	shift;;
    --state) TOPIC=state;
        shift;;
    --optical_info) TOPIC=optical;
        shift;;
    --counter_reset) TOPIC=reset;
        shift;;
    --bytes_sent) TOPIC=bytessent;
        shift;;
    --bytes_rec) TOPIC=bytesrec;
        shift;;
    --packets_sent) TOPIC=packetssent;
        shift;;
    --packets_rec) TOPIC=packetsrec;
        shift;;
    --errors_sent) TOPIC=errorssent;
        shift;;
    --errors_rec) TOPIC=errorsrec;
        shift;;
    --discardpackets_sent) TOPIC=discardpacketssent;
        shift;;
    --discardpackets_rec) TOPIC=discardpacketsrec;
        shift;;
    --allstats) TOPIC=allstats;
        shift;;
    -*) print_help;;
  esac
done

if [ "$port" = "pon" ] ; then
	opt_cmd="mib dump counter port 1 nonZero"
	counter_reset="mib reset counter port 1 "
elif [ "$port" = "lan" ] ; then
	opt_cmd="mib dump counter port 0 nonZero"
	counter_reset="mib reset counter port 0"
else
	print_help
fi


diag_cmd="diag"
exit_cmd="exit"
onu_state_cmd="gpon get onu-state"
opt_all="mib dump counter port all nonZero"
optical_cmd="cat /proc/optical_info"
connect_cmd="telnet 192.168.2.1 23"

if [ "$TOPIC" = "config" ] ; then
	print_help
fi

if [ "$TOPIC" = "state" -o "$TOPIC" = "allstats" ] ; then
	echo `(echo "$diag_cmd"; echo "$onu_state_cmd"; sleep 1; echo "$exit_cmd";)|${connect_cmd} | grep ONU` > /tmp/onu_state.txt
	onu_state=`cat /tmp/onu_state.txt | tr -cd "[0-9]"`
	if [ "${onu_state}" = "1" ]; then
		echo "INIT (O1)"
	fi
	if [ "${onu_state}" = "2" ]; then
		echo "STANDBY (O2)"
	fi
	if [ "${onu_state}" = "3" ]; then
		echo "SERIAL_NUMBER (O3)"
	fi
	if [ "${onu_state}" = "4" ]; then
		echo "RANGING (O4)"
	fi
	if [ "${onu_state}" = "5" ]; then
		echo "OPERATION (O5)"
	fi
	if [ "${onu_state}" = "6" ]; then
		echo "POPUP (O6)"
	fi
	if [ "${onu_state}" = "7" ]; then
		echo "EMERGENCY_STOP (O7)"
	fi
fi

if [ "$TOPIC" = "optical" -o "$TOPIC" = "allstats" ] ; then
	echo `(echo "$optical_cmd"; sleep 1; echo "$exit_cmd";)|${connect_cmd}`> /tmp/optical_info.txt
	sed -i 's/\r/\n/g' /tmp/optical_info.txt
	Optical=`cat /tmp/optical_info.txt | grep : | grep -v "BusyBox"`
	echo "$Optical"
fi

if [ "$TOPIC" = "reset" ] ; then
	echo `(echo "$diag_cmd"; echo "$counter_reset"; sleep 1; echo "$exit_cmd";)|${connect_cmd}`> /tmp/reset.txt
fi

if [ "$TOPIC" != "state" -a "$TOPIC" != "optical" -a "$TOPIC" != "config" -a "$TOPIC" != "reset" ] ; then

	echo `(echo "$diag_cmd"; echo "$opt_cmd"; sleep 1; echo "$exit_cmd";)|${connect_cmd}` > /tmp/sfp_counter.txt

	sed -i 's/\r/\n/g' /tmp/sfp_counter.txt
	if [ "$TOPIC" = "bytessent" -o "$TOPIC" = "allstats" ] ; then
		ifOutOctets=`cat /tmp/sfp_counter.txt | grep ifOutOctets | tr -cd "[0-9]"`
		if [ ! $ifOutOctets ] ; then
			ifOutOctets=0
		fi
		echo "BytesSent:" "$ifOutOctets"
	fi

	if [ "$TOPIC" = "bytesrec" -o "$TOPIC" = "allstats" ] ; then
		ifInOctets=`cat /tmp/sfp_counter.txt | grep ifInOctets | tr -cd "[0-9]"`
		if [ ! $ifInOctets ] ; then
		ifInOctets=0
		fi
		echo "BytesReceived:" "$ifInOctets"
	fi

	if [ "$TOPIC" = "packetssent" -o "$TOPIC" = "allstats" ] ; then
		ifOutUcastPkts=`cat /tmp/sfp_counter.txt | grep ifOutUcastPkts | tr -cd "[0-9]"`
		if [ ! $ifOutUcastPkts ] ; then
			ifOutUcastPkts=0
		fi

		ifOutMulticastPkts=`cat /tmp/sfp_counter.txt | grep ifOutMulticastPkts | tr -cd "[0-9]"`
		if [ ! $ifOutMulticastPkts ] ; then
			ifOutMulticastPkts=0
		fi

		ifOutBroadcastPkts=`cat /tmp/sfp_counter.txt | grep ifOutMulticastPkts | tr -cd "[0-9]"`
		if [ ! $ifOutBroadcastPkts ] ; then
			ifOutBroadcastPkts=0
		fi

		ifOut=$(($ifOutUcastPkts + $ifOutMulticastPkts + $ifOutBroadcastPkts))
		echo "PacketsSent:" "$ifOut"
	fi

	if [ "$TOPIC" = "packetsrec" -o "$TOPIC" = "allstats" ] ; then
		ifInUcastPkts=`cat /tmp/sfp_counter.txt | grep ifInUcastPkts | tr -cd "[0-9]"`
		if [ ! $ifInUcastPkts ] ; then
			ifInUcastPkts=0
		fi

		ifInMulticastPkts=`cat /tmp/sfp_counter.txt | grep ifInMulticastPkts | tr -cd "[0-9]"`
		if [ ! $ifInMulticastPkts ] ; then
			ifInMulticastPkts=0
		fi

		ifInBroadcastPkts=`cat /tmp/sfp_counter.txt | grep ifInMulticastPkts | tr -cd "[0-9]"`
		if [ ! $ifInBroadcastPkts ] ; then
			ifInBroadcastPkts=0
		fi

		ifIn=$(($ifInUcastPkts + $ifInMulticastPkts + $ifInBroadcastPkts))
		echo "PacketsReceived:" "$ifIn"
	fi

	if [ "$TOPIC" = "errorssent" -o "$TOPIC" = "allstats" ] ; then
		echo "ErrorsSent: 0" #Currently SFP not include this message, just set it as "0"
	fi

	if [ "$TOPIC" = "errorsrec" -o "$TOPIC" = "allstats" ] ; then
		echo "ErrorsReceived: 0"  #Currently SFP not include this message, just set it as "0"
	fi

	if [ "$TOPIC" = "discardpacketssent" -o "$TOPIC" = "allstats" ] ; then
		ifOutDiscards=`cat /tmp/sfp_counter.txt | grep ifOutDiscards | tr -cd "[0-9]"`
		if [ ! $ifOutDiscards ] ; then
			ifOutDiscards=0
		fi
		echo "DiscardPacketsSent:" "$ifOutDiscards"
	fi

	if [ "$TOPIC" = "discardpacketsrec" -o "$TOPIC" = "allstats" ] ; then
		ifInDiscards=`cat /tmp/sfp_counter.txt | grep ifInDiscards | tr -cd "[0-9]"`
		if [ ! $ifInDiscards ] ; then
			ifInDiscards=0
		fi
		echo "DiscardPacketsReceived:" "$ifInDiscards"
	fi
fi

