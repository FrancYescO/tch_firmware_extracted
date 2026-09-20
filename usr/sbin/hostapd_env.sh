#!/bin/sh

ENV_FILE=$1

if [ -z $ENV_FILE ] ; then
  echo env file needed
  exit 1
fi

if [ -e $ENV_FILE ] ; then
  exit 0
fi

uci_get_2_opt()
{
  VAR=`uci get $1 2> /dev/null`
  if [ "$?" != "0" ]; then
    VAR=`uci get $2 2> /dev/null`
  fi
  echo "$VAR"
}

#Set some Legacy variables (used by hostapd and wlan_dk)
#For the first 5: try wireless specific value, then use env
_COMPANY_NAME=$(uci_get_2_opt wireless.global.wfa_manufacturer env.var.company_name)
_PROD_NAME=$(uci_get_2_opt wireless.global.wfa_model_name env.var.prod_name)
_PROD_NUMBER=$(uci_get_2_opt wireless.global.wfa_model_number env.var.prod_number)
_PROD_FRIENDLY_NAME=$(uci_get_2_opt wireless.global.wfa_device_name env.var.prod_friendly_name)
#variant_friendly_name: use hostapd default if not set
_VARIANT_FRIENDLY_NAME=`uci get wireless.global.wfa_friendly_name 2> /dev/null || echo "WPS Access Point"`
_SSID_SERIAL_PREFIX=`uci get env.var.ssid_prefix`
_BOARD_NAME=`uci get env.rip.board_mnemonic`
_BOARD_SERIAL_NBR=`uci get env.rip.serial`
_PROD_SERIAL_NBR=`uci get env.rip.factory_id`$_BOARD_SERIAL_NBR

#Get mac and replace : by -
_MACADDR=`uci get env.rip.eth_mac | sed -e "s/:/-/g"`
_WL_MACADDR=`uci get env.rip.wifi_mac | sed -e "s/:/-/g"`

echo "_COMPANY_NAME=$_COMPANY_NAME
_PROD_NAME=$_PROD_NAME
_PROD_NUMBER=$_PROD_NUMBER
_PROD_FRIENDLY_NAME=$_PROD_FRIENDLY_NAME
_VARIANT_FRIENDLY_NAME=$_VARIANT_FRIENDLY_NAME
_SSID_SERIAL_PREFIX=$_SSID_SERIAL_PREFIX
_BOARD_NAME=$_BOARD_NAME
_BOARD_SERIAL_NBR=$_BOARD_SERIAL_NBR
_PROD_SERIAL_NBR=$_PROD_SERIAL_NBR
_MACADDR=$_MACADDR
_WL_MACADDR=$_WL_MACADDR" > $ENV_FILE

