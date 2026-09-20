#!/bin/sh

. "$IPKG_INSTROOT"/lib/functions.sh

vendor_config="vendorextensions"

reset_agent_software_images() {
  if [ -z "${1##*"static_agent"*}" ];
  then
    uci_set $vendor_config $1 eligible_model ''
    uci_set $vendor_config $1 file_size ''
    uci_set $vendor_config $1 url ''
    uci_set $vendor_config $1 password ''
    uci_set $vendor_config $1 username ''
    uci_set $vendor_config $1 eligible_hardware_version ''
    uci_set $vendor_config $1 software_version ''
    uci_set $vendor_config $1 eligible_software_version ''
  else
    uci delete $vendor_config.$1
  fi
}

reset_agent_alias_name() {
    uci delete $vendor_config.$1
}

config_load vendorextensions
config_foreach reset_agent_software_images agent_sw_image
config_foreach reset_agent_alias_name alias_name

uci commit $vendor_config
