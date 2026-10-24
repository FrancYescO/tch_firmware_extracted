#!/bin/sh
interface=$(uci -q get tracingtool.tracingtool.device)

cmd_error() {
  uci set tracingtool.tracingtool.state="stop"
  uci set tracingtool.tracingtool.status="Error-Invalid Filter"
  echo "$(uci get tracingtool.tracingtool.tcp)--$(uci get tracingtool.tracingtool.status)"  >> /tmp/packet/Errorstring
}

inprogress_set() {
  uci set tracingtool.tracingtool.state="${1}"
  uci set tracingtool.tracingtool.status="${2}"
  uci commit tracingtool
}

tcp_start() {
  fileList="${capturePath}--${cmd}"
  packetdir="/tmp/packet/"
  if [ ! -d "${packetdir}" ]; then
    mkdir -p ${packetdir}
  fi
  echo $fileList >> /tmp/packet/captures
  uci set tracingtool.tracingtool.tcp="$cmd"
  inprogress_set "inprogress" "inprogress"
}

#create a folder in USB to store the captures
path=$(uci -q get mountd.mountd.path)
for entry in `ls $path`
do
 if [ -d $path$entry ]; then
   usbPath=$path$entry
   break
 fi
done

if [ "$usbPath" != "" ]; then
  if [ ! -d "$dirname" ]; then
    usbdir="$usbPath/packetcapture"
    mkdir -p ${usbdir}
  fi
  uci set tracingtool.tracingtool.mntpath="$usbPath/packetcapture"
  capturePath="${usbPath}/packetcapture/`date +%Y_%m_%d_%H_%M_%S`"
  touch $capturePath
else
  inprogress_set "stop" "stopped"
fi

#check for tcpdump tool
toolpresent=`tcpdump -h 2>&1`
if [ `echo "$toolpresent" | grep -c "tcpdump version"` -gt 0 ]; then
  #start the capture
    cmd=$(echo tcpdump -i $interface -w $capturePath)
    tcp_start
    output=`$cmd 2>&1 &`
    if [ `echo "$output" | grep -c "syntax error in filter expression"` -gt 0 ]; then
      cmd_error
    fi
    /usr/share/transformer/scripts/packetcapture_isr.sh $capturePath &
    cmd=$(echo tcpdump -i $interface -w $capturePath)

    if [ `echo "$output" | grep -c "packets captured"` -gt 0 -o `echo "$output" | grep -c "packet captured"` -gt 0 ]; then
      checkBytesPid=`ps w | grep "packetcapture_isr.sh" | awk '{print $1}'`
      if [ "$checkBytesPid" ]; then
        kill -9 $checkBytesPid
      fi
      inprogress_set "stop" "completed"
    elif [ `echo "$output" | grep -c "syntax error in filter expression"` -gt 0 ]; then
      cmd_error
    fi
else
  inprogress_set "stop" "Error-No tcpdump tool found"
fi

uci commit tracingtool

