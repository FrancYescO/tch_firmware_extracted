#!/bin/sh
# This script is for getting related message from SFP

. $IPKG_INSTROOT/lib/functions.sh



print_help ()
{
  echo "sfp_get.sh -s pon/lan [option]"
  echo "-s                     : Select the port, it could be pon or lan, default is pon"
  echo "--allstats             : All SFP stats"
  echo "--state                : ONU state"
  echo "--sfp_sn               : SFP serial number"
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
  echo "--reboot               : Reboot SFP module "
  echo "--telnet_test          : Test current telnet profile"
  echo "--help                 : Dump the info text"
  exit 1
}

port=pon
TOPIC=config
test_security=0
test_usr=""
test_pwd=""
telnet_supported=1

for i in x x x x x x x x x x x x x x x # at most 15 '-' type arguments
do
  case "$1" in
    -s) port=$2;
	shift;
	shift;;
    --telnet_test) TOPIC=telnetTest;
        test_security=$2;
        test_usr=$3;
        test_pwd=$4;
        shift;
        shift;;
    --state) TOPIC=state;
        shift;;
    --sfp_sn) TOPIC=ont_sn;
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
    --reboot) TOPIC=reboot;
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

sfp_vendor_name=`/usr/sbin/sfpi2cctl -get -format vendname | cut -d ":" -f2`
if [ "$sfp_vendor_name" = "[SERCOMM         ]" ]; then
    telnet_supported=0
fi

config_load sfp
config_get telnet_security_mode device_defaults telnet_security_mode '0'
config_get enabled device_defaults enabled '0'

user=""
password=""
telnet_protected=0

if [ "$enabled" = "1" ]; then
        if [ "$telnet_security_mode" = "none" ]; then
                telnet_protected=0
	elif [ "$telnet_security_mode" = "pwd" ]; then
                telnet_protected=1
		user=`uci get sfp.device_defaults.username`
		password=`uci get sfp.device_defaults.password`
	fi
fi

diag_cmd="diag"
exit_cmd="exit"
reboot_cmd="reboot -d 3"
onu_state_cmd="gpon get onu-state"
ont_sn_cmd="gpon get serial-number-hex"
opt_all="mib dump counter port all nonZero"
optical_cmd="cat /proc/optical_info"

###### get the ip address of SFP ###start###
# There have two interfaces in /etc/config/network:
# "sfp" and "sfptag", each of them will include the
# SFP management IP which for telnet/manage SFP module.
###########################################
config_load network
config_get ip_addr sfptag ipaddr ''
if [ ! -n "$ip_addr" ] ; then
	config_get ip_addr sfp ipaddr ''
fi

if [ ! -n "$ip_addr" ] ; then
	connect_cmd="telnet 192.168.2.1 23"
else
	ip=$(echo $ip_addr | awk -F '.' '{print $1"."$2"."$3}')
	connect_cmd="telnet "$ip".1 23"
fi
###### get the ip address of SFP ###end###


if [ "$TOPIC" = "config" ] ; then
	print_help
fi

if [ "$TOPIC" = "telnetTest" ] ; then
     sfp_status=$(cat /proc/ethernet/sfp_status | awk -F ':' '{print $2}')
     if [ "$sfp_status" = "link up" ]; then
        if [ $test_security = 0 ]; then
           echo `(echo "uname -a"; sleep 1; echo "exit";)|${connect_cmd}`> /tmp/sfp_info
        elif [ $test_security = 1 ]; then
           echo `(echo "$test_usr"; sleep 1; echo "$test_pwd"; sleep 1;echo "uname -a"; sleep 1; echo "exit";)|${connect_cmd}`> /tmp/sfp_info
        fi

        if grep -q "BusyBox" /tmp/sfp_info ; then
           exit 0
        else
           exit 1
        fi
    else
        echo "sfp cannot connected, please make sure [sfp] [fiber] both connected"
        exit 2
    fi
fi


if [ "$TOPIC" = "reboot" ] ; then
	if [ $telnet_protected = 1 ]; then
		echo `(echo "$user"; sleep 1; echo "$password"; sleep 1; echo "$reboot_cmd"; sleep 1;)|${connect_cmd}` > /tmp/sfp_reboot_log.txt
	else
		echo `(echo "$reboot_cmd"; sleep 1;)|${connect_cmd}` > /tmp/sfp_reboot_log.txt
	fi
fi

if [ "$TOPIC" = "ont_sn" ] ; then
	if [ $telnet_protected = 1 ]; then
		echo `(echo "$user"; sleep 1; echo "$password"; sleep 1; echo "$diag_cmd" "$ont_sn_cmd"; sleep 1; echo "$exit_cmd";)|${connect_cmd} | grep serial` > /tmp/ont_sn.txt
	else
		echo `(echo "$diag_cmd" "$ont_sn_cmd"; sleep 1; echo "$exit_cmd";)|${connect_cmd} | grep "serial number"` > /tmp/ont_sn.txt
        fi
	sed -i 's/\r/\n/g' /tmp/ont_sn.txt
	ont_sn_get=`cat /tmp/ont_sn.txt | awk -F ' ' '{print $3 $4}' | sed s/0x//g`
	echo "serial number : $ont_sn_get"
fi

if [ "$TOPIC" = "state" -o "$TOPIC" = "allstats" ] ; then
    if [ $telnet_supported = 1 ]; then
	    if [ $telnet_protected = 1 ]; then
		    echo `(echo "$user"; sleep 1; echo "$password"; sleep 1; echo "$diag_cmd" "$onu_state_cmd"; sleep 1; echo "$exit_cmd";)|${connect_cmd} | grep ONU` > /tmp/onu_state.txt
	    else
		    echo `(echo "$diag_cmd" "$onu_state_cmd"; sleep 1; echo "$exit_cmd";)|${connect_cmd} | grep ONU` > /tmp/onu_state.txt
	    fi
	    onu_state=`cat /tmp/onu_state.txt | tr -cd "[0-9]"`
    else
        gpon_state=`/usr/sbin/sfpi2cctl -get -raw 1 130 1 | grep -v bankId`
        onu_state=$( printf '%d' $gpon_state )
    fi
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
	if [ $telnet_protected = 1 ]; then
		echo `(echo "$user"; sleep 1; echo "$password"; sleep 1; echo "$optical_cmd"; sleep 1; echo "$exit_cmd";)|${connect_cmd}`> /tmp/optical_info.txt
	else
		echo `(echo "$optical_cmd"; sleep 1; echo "$exit_cmd";)|${connect_cmd}`> /tmp/optical_info.txt
	fi
	sed -i 's/\r/\n/g' /tmp/optical_info.txt
	Optical=`cat /tmp/optical_info.txt | grep : | grep -v "BusyBox" | grep -v "login"`
	echo "$Optical"
fi

if [ "$TOPIC" = "reset" -a $telnet_supported = 1 ] ; then
	if [ $telnet_protected = 1 ]; then
		echo `(echo "$user"; sleep 1; echo "$password"; sleep 1; echo "$diag_cmd" "$counter_reset"; sleep 1; echo "$exit_cmd";)|${connect_cmd}`> /tmp/reset.txt
	else
		echo `(echo "$diag_cmd" "$counter_reset"; sleep 1; echo "$exit_cmd";)|${connect_cmd}`> /tmp/reset.txt
	fi
fi

if [ "$TOPIC" != "state" -a "$TOPIC" != "optical" -a "$TOPIC" != "config" -a "$TOPIC" != "reset" -a "$TOPIC" != "reboot" -a "$TOPIC" != "telnetTest" -a "$TOPIC" != "ont_sn" -a $telnet_supported = 1 ] ; then
	if [ $telnet_protected = 1 ]; then
		echo `(echo "$user"; sleep 1; echo "$password"; sleep 1; echo "$diag_cmd" "$opt_cmd"; sleep 1; echo "$exit_cmd";)|${connect_cmd}` > /tmp/sfp_counter.txt
	else
		echo `(echo "$diag_cmd" "$opt_cmd"; sleep 1; echo "$exit_cmd";)|${connect_cmd}` > /tmp/sfp_counter.txt
	fi
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

