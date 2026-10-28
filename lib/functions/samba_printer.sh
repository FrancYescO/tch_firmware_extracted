#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh

convert_uri_to_printername(){
  local uri=$1
  local temp_printer_name
  local printer_name_part_1
  local printer_name_part_2

  # a uri is like this: "usb://Lexmark/Lexmark%20E120n?serial=9943P88"
  # after the conversion, the printer name is "Lexmark_Lexmark-E120n_9943P88"
  temp_printer_name=${uri##*//}
  printer_name_part_1=${temp_printer_name%%/*}
  temp_printer_name=${temp_printer_name##*/}
  printer_name_part_2=${temp_printer_name/\?serial=/_}
  printer_name_part_2=${printer_name_part_2/\&interface=/_}

  printer_name="$printer_name_part_1""_""$printer_name_part_2"
  #replace '#' and "%20" with '-'; a printer name cannot include '#'
  printer_name=${printer_name//%20/-}
  printer_name=${printer_name//#/-}
}

convert_printername_to_serialnumber(){
  echo $1 | cut -d '_' -f3
}

check_printers() {
  local index=$1
  local uri
  config_get name "$index" name
  config_get uri "$index" uri
  config_get offline "$index" offline

  local new_uri=$2
  exist=0
  exist_name="$name"

  if ([[ "$uri" == "$new_uri" ]] && [[ "$offline" == "1" ]]); then
    exist=1
  fi
}

usb_printers (){
  /usr/lib/cups/backend/usb | while read line
  do
    uri=`echo "$line" | grep "direct usb:" | cut -d ' ' -f 2`
    if [ -n "$uri" ] ; then
      #add the new printer
      convert_uri_to_printername $uri
      local serial_number=$(convert_printername_to_serialnumber $printer_name)
      local find=`cat /tmp/printcap | grep $printer_name`
      config_load printersharing
      config_foreach check_printers printers $uri
      if [[ $exist == "1" ]]; then
        lpadmin -p "$exist_name" -v $uri -E
        uci set printersharing.$serial_number.offline='0'
        echo "$printer_name" >> /tmp/printcap
      elif [ -z "$find" ] ; then
        lpadmin -p "$printer_name" -v $uri -E
        echo "$printer_name" >> /tmp/printcap
        local fax_found=`echo $printer_name | grep "FAX"`
        if [ -z "$fax_found" ] ; then
          [ "$(uci -P /var/state -q get printersharing.$serial_number)" == "printers" ] ||
          uci set printersharing.$serial_number=printers
          uci set printersharing.$serial_number.name=$printer_name
          uci set printersharing.$serial_number.uri=$uri
          uci set printersharing.$serial_number.offline='0'
        fi
       uci commit
      fi
      echo "$printer_name"
    fi
  done
}

construct_printer_name(){
  local DevPath=${1}

  local manufacturer=$(cat $DevPath/../../manufacturer)
  manufacturer=${manufacturer// /-}
  local product=$(cat $DevPath/../../product)
  product=${product// /-}
  local serial=$(cat $DevPath/../../serial)
  serial=${serial// /-}
  local printer_name="$manufacturer"_"$product"_"$serial"

  echo $printer_name
}

add_printer_name(){
  local devPath=${1}
  local printerSerial=${2}

  local printer_name=$(construct_printer_name $devPath)

  config_load printersharing

  [ "$(uci -P /var/state -q get printersharing.$printerSerial)" == "printers" ] ||
  uci set printersharing.$printerSerial=printers
  uci set printersharing.$printerSerial.name=$printer_name
  uci set printersharing.$printerSerial.offline='0'
  uci commit
}

remove_printer(){
  local devPath=${1}

  local printerdevpath=$(uci -P /var/state -q show printersharing | grep $devPath)
  local printerDevPath=$(echo $printerdevpath | cut -d'=' -f1)
  local printer_dev_path=${printerDevPath/devpath/name}
  local printer_name=$(uci get $printer_dev_path)

  local serial=$(convert_printername_to_serialnumber $printer_name)

  uci set printersharing.$serial.offline='1'
  uci commit printersharing
  /usr/bin/nqcsctrl -S $printer_name
  uci_revert_state printersharing $serial
}

reload_printer_path(){
  grep -r ".devpath" /var/state/printersharing | while read line
  do
    local path=$(echo $line | cut -d'=' -f1)
    local devpath=$(uci -P /var/state -q get $path)
    add_printer_path "$devpath"
  done
}

add_printer_path(){
  local dev_path=${1}
  local device_path="/sys${1}/usbmisc"
  local printerpath=$(ls -1 ${device_path} | grep lp*)

  if [ -z "$printerpath" ] ; then
    remove_printer $dev_path
    reload_printer_path
  else
    printer_path="/dev/usb/${printerpath}"

    local printer_serial=$(cat ${device_path}/../../serial)

    local sambashare_printerpath=$(uci show samba | grep /var/spool/samba)
    local sambashare_printerPath=$(echo $sambashare_printerpath | cut -d'=' -f1)
    local sambashare_printer_path=${sambashare_printerPath/path/enabled}
    local sambashare_printer_enabled=$(uci get $sambashare_printer_path)

    add_printer_name $device_path $printer_serial

    if [ "$(uci -P /var/state -q get printersharing.$printer_serial)" == "printers" ] ; then
      uci_revert_state printersharing $printer_serial path
      uci_revert_state printersharing $printer_serial devpath
      uci_revert_state printersharing $printer_serial enabled
    fi
    uci_set_state printersharing $printer_serial path $printer_path
    uci_set_state printersharing $printer_serial devpath $dev_path
    uci_set_state printersharing $printer_serial enabled $sambashare_printer_enabled

    local printer_name=$(uci -P /var/state -q get printersharing.$printer_serial.name)

    local printersharingenabled=$(uci get printersharing.config.enabled)

    if [ "$sambashare_printer_enabled" == "1" ] && [ "$printersharingenabled" == "1" ] ; then
       local printer_present=$(/usr/bin/nqcsctrl ES | grep -c $printer_name)

       if [ $printer_present == 0 ] ; then
         /usr/bin/nqcsctrl +S $printer_name $printer_path $printer_name P
       else
         /usr/bin/nqcsctrl -S $printer_name
         /usr/bin/nqcsctrl +S $printer_name $printer_path $printer_name P
       fi
    fi
  fi
}

reload_printers(){
  local line
  local uri
  local printer
  local printers
  local find

  if [ ! -f /tmp/printcap ]; then
    touch /tmp/printcap
  fi
  if [ ! -f /tmp/printername ]; then
    touch /tmp/printername
  fi
  printers=$(usb_printers)
  cat /tmp/printcap | while read line
  do
    printer=`echo "$line"`
    if [ -n "$printer" ]; then
      local printername=`cat /tmp/printername`
      local serial=$(convert_printername_to_serialnumber $printer)
      local name=`uci get printersharing.$serial.name`
      uri=`uci get printersharing.$serial.uri`
      find=`echo "$printers" | grep "$printer"`
      if [ ! $find ] ; then
        lpadmin -x $name
        sed -i "/$printer/d" /tmp/printcap
        rm -rf /tmp/printername
      fi
      if ([[ -z "$printername" ]] && [[ "$name" != $printer ]]); then
       lpadmin -x $printer
       lpadmin -p "$name" -v "$uri" -E
       echo "$name" > /tmp/printername
      elif ([[ "$name" != $printer ]] && [[ "$name" != "$printername" ]]); then
       lpadmin -x "$printername"
       lpadmin -p "$name" -v "$uri" -E
       echo "$name" > /tmp/printername
      fi
    fi
  done
}
