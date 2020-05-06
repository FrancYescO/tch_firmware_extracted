#!/bin/sh

ENV_FILE=$1

if [ -z $ENV_FILE ] ; then
  echo env file needed
  exit 1
fi

if [ -e $ENV_FILE ] ; then
  exit 0
fi

#Set some Legacy variables (used by hostapd and wlan_dk)
_COMPANY_NAME=`uci get env.var.company_name`
_PROD_NAME=`uci get env.var.prod_name`
_PROD_NUMBER=`uci get env.var.prod_number`
_PROD_FRIENDLY_NAME=`uci get env.var.prod_friendly_name`
#variant_friendly_name does not always exist
_VARIANT_FRIENDLY_NAME=`uci get env.var.variant_friendly_name 2> /dev/null || echo $_PROD_FRIENDLY_NAME`
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

