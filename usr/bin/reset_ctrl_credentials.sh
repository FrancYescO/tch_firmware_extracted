#!/bin/sh

# init env

##wireless_init_uci_env.sh


# Set controller_credentials for FH

uci set multiap.cred0.ssid=`uci get env.var.ssid_prefix``uci get env.var.ssid_mac_postfix_r0`

uci set multiap.cred0.wpa_psk_key=`uci get env.var.default_key_r0_s0`

security_mode=`uci get env.var.default_security_mode_r0_s0`
if [ -z $security_mode ] ; then
  uci set multiap.cred0.security_mode=wpa2-psk
else
  uci set multiap.cred0.security_mode=`uci get env.var.default_security_mode_r0_s0`
fi

uci set multiap.cred0.fronthaul=1

uci set multiap.cred0.backhaul=0

uci set multiap.cred0.frequency_bands=radio_2G,radio_5Gu,radio_5Gl


# Set controller_credentials for BH

uci set multiap.cred1.ssid=`uci get env.var.ssid_prefix``uci get env.var.ssid_mac_postfix_r1`

uci set multiap.cred1.wpa_psk_key=`uci get env.var.default_key_r1_s0`

security_mode=`uci get env.var.default_security_mode_r1_s0`
if [ -z $security_mode ] ; then
  uci set multiap.cred1.security_mode=wpa2-psk
else
  uci set multiap.cred1.security_mode=`uci get env.var.default_security_mode_r1_s0`
fi

uci set multiap.cred1.fronthaul=0

uci set multiap.cred1.backhaul=1

uci set multiap.cred1.frequency_bands=radio_2G,radio_5Gu,radio_5Gl


# Commit the changes

uci commit multiap

