#!/bin/sh

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

usb_printers (){
  /usr/lib/cups/backend/usb | while read line
  do
    uri=`echo "$line" | grep "direct usb:" | cut -d ' ' -f 2`
    if [ -n "$uri" ] ; then
      #add the new printer
      convert_uri_to_printername $uri
      local find=`cat /tmp/printcap | grep $printer_name`
      if [ -z "$find" ] ; then
        lpadmin -p "$printer_name" -v $uri -E
        if [ $? -eq 0 ] ; then
          echo "$printer_name" >> /tmp/printcap
        fi
      fi
      echo "$printer_name"
    fi
  done
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
  printers=$(usb_printers)
  cat /tmp/printcap | while read line
  do
    printer=`echo "$line"`
    if [ -n "$printer" ]; then
      find=`echo "$printers" | grep "$printer"`
      if [ ! $find ] ; then
        lpadmin -x $printer
        sed -i "/$printer/d" /tmp/printcap
      fi
    fi
  done
}
