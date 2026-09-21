#!/bin/sh /etc/rc.common
. $IPKG_INSTROOT/lib/functions/mud_config.sh

EXTRA_COMMANDS="insert_partition_section remove_partition_section reset_config_section"

exist=0
part_count=0
max_part_count=10
SMB_FILE=/var/state/samba
CONF_FILE=/var/etc/mud.conf

remove_inactive_partition_section() {
  local part_name=$1
  local share_name active

  config_get share_name "$part_name" share_name
  config_get active "$part_name" active

  if [ "$active" != "1" ]
  then
    logger -t dlnad "Partition $part_name is not active"
    uci delete dlnad."unknown_$share_name"
  fi
}

reset_section() {
  logger -t dlnad "Renaming $1 to unknown_<share_name>"
  local part_name=$1
  local share_name

  config_get share_name "$part_name" share_name
  uci set dlnad.$part_name.active='0'
  uci rename dlnad.$1="unknown_$share_name"
}

rename_partition_info() {
  local part_name=$1
  local command=$2
  local partitionName=$3
  local serial=$4
  local shareName=$5
  local share_name config_serial

  part_count=$((part_count+1))

  config_get share_name "$part_name" share_name
  config_get config_serial "$part_name" serial

  # Check for existance serialNo and ShareName
  if [[ "$command" == "insert" ]]; then
    if ([[ "$config_serial" == "$serial" ]] && [[ "$shareName" == "$share_name" ]]); then
      exist=1
      #if exists rename the section to partition name and active=1
      uci rename dlnad.$part_name=$partitionName
      uci set dlnad.$partitionName.active='1'
    fi
  elif [[ "$command" == "remove" ]]; then
    if [[ "$part_name" == "$partitionName" ]]; then
      #Set active=0 & sectionname to Unknown
      uci set dlnad.$1.active='0'
      uci rename dlnad.$1="unknown_$share_name"
    else
      logger -t dlnad "Partition is not available"
    fi
  fi
}

insert_partition_section() {
  local files file_name uevent line
  local partition
  local serial shareName
  local file_found

  #Iterating /sys/bus/usb/devices/ folder to match the partition name to
  #retrieve the Serial Number and Share Name
  for files in /sys/bus/usb/devices/[0-9]-[0-9];
  do
    file_found=0
    file_name=${files##*/}
    # Check whether ths inserted partition is connected via HUB or Directly.
    # If connected via Normal USB port.
    for uevent in /sys/bus/usb/devices/$file_name/*/host*/target*/*/block/sd*/$1/uevent;
    do
      if [[ -f $uevent ]]; then
        file_found=1
      fi
    done
    if [[ $file_found == 0 ]]; then
      # If a HDD/Pendrive is connected via USB HUB
      for uevent in /sys/bus/usb/devices/$file_name/*/*/host*/target*/*/block/sd*/$1/uevent;
      do
      if [[ -f $uevent ]]; then
       file_found=1
      fi
      done
    fi
    if [[ $file_found == 1 ]]; then
      if [[ -f $uevent ]]; then
        while read line
        do
          case $line in
            DEVNAME* )
              #$line will be on format "DEVNAME=sda1"
              line=${line##*=}
              # if $line matches sda1, sdb1, etc..
              if [[ $line == $1 ]]; then
                serial=$(cat /sys/bus/usb/devices/$file_name/serial)

                #Going through the Samba file to retrieve the ShareName
                if [[ -f $SMB_FILE ]]; then
                while read line
                do
                  case $line in
                    *device* )
                      #$line will be on format "samba.JetFlash_Transcend8GB_1_eb02.device='sda1'"
                      #Retriving ShareName and PartitionName from samba
                      shareName=${line%.*}
                      shareName=${shareName##*.}
                      partition=${line%\'*}
                      partition=${partition##*\'}
                      if [[ "$partition" == "$1" ]]; then
                        break
                      fi
                    ;;
                  esac
                done < $SMB_FILE
                fi

                config_load dlnad
                #Iterating every section to check if the partition is already connected
                config_foreach rename_partition_info partitions "insert" "$1" "$serial" "$shareName"

                #If more than 10 partitions are already inserted,
                #remove all unknown partitions from config which was already removed.
                if [ $part_count -gt $max_part_count ]; then
                  config_foreach remove_inactive_partition_section partitions
                fi

                #$exist is set in rename_partition_info
                if [[ $exist != "1" ]]; then
                  uci set dlnad.$1=partitions
                  uci set dlnad.$1.active='1'

                  local sharing share_all_folder

                  config_get sharing config sharing
                  config_get share_all_folder config share_all_folder

                  uci set dlnad.$1.sharing=$sharing
                  uci set dlnad.$1.share_all_folder=$share_all_folder
                  uci set dlnad.$1.serial=$serial
                  if [ ! -z $shareName ]; then
                    uci set dlnad.$1.share_name=$shareName
                  fi
                fi
              fi
            ;;
          esac
        done < $uevent
      fi
      uci commit
   fi
  done
  update_mud_config
}

remove_partition_section() {
  config_load dlnad
  config_foreach rename_partition_info partitions "remove" "$1"
  uci commit
  update_mud_config
}

# reset_config_section is called during bootup/mud restart scenario.
# It would reset all the available partition sections name to unknown-<share_name>
reset_config_section() {
  config_load dlnad
  config_foreach reset_section partitions
}
