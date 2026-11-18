#!/bin/sh
CONF_FILE=/var/etc/mud.conf

# To update the list of share_path in $CONF_FILE
read_sharepath() {
  local share_path="$1"
  local part_name="$2"
  echo "$part_name.share_path=$share_path" >> $CONF_FILE
}

# To read all the partition information and to update it in conf file
read_partitions() {
  local name=$1
  local part_name sharing share_all_folders active
  local serial share_name
  part_name=$name

  #get all the partition info from dlnad config
  config_get sharing "$name" sharing
  config_get share_all_folders "$name" share_all_folder
  config_get active "$name" active
  config_get serial "$name" serial
  config_get share_name "$name" share_name

  echo "partition_name=$part_name" >> $CONF_FILE
  echo "$part_name.sharing=$sharing" >> $CONF_FILE
  echo "$part_name.share_all_folder=$share_all_folders" >> $CONF_FILE
  echo "$part_name.active=$active" >> $CONF_FILE
  echo "$part_name.serial=$serial" >> $CONF_FILE
  echo "$part_name.share_name=$share_name" >> $CONF_FILE

  config_list_foreach "$name" share_path read_sharepath "$part_name"
}

update_mud_config() {
  if [ -f $CONF_FILE ]; then
    rm -f $CONF_FILE
  fi

  config_load dlnad
  local sharing share_all_folders max_sharedfolders

  config_get sharing config sharing
  config_get share_all_folders config share_all_folder
  config_get max_sharedfolders config max_sharedfolders
  echo "sharing=$sharing" >> $CONF_FILE
  echo "share_all_folder=$share_all_folders" >> $CONF_FILE
  echo "max_shared_folders=$max_sharedfolders" >> $CONF_FILE

  config_foreach read_partitions partitions
}
