#!/bin/sh

ENV_FILE=/tmp/hostapd.env
KEYGEN_OUTPUT=/tmp/hostapd_keygen.out

#Generate env
hostapd_env.sh $ENV_FILE

#Generate keys
if [ -f "/etc/wlan/brcm_country_map_radio2" ]; then
    RADIO=-3
fi

hostapd_keygen $RADIO -e $ENV_FILE > $KEYGEN_OUTPUT

#Read in keys
. $KEYGEN_OUTPUT

#Update UCI
#Radio 0
uci set env.var.ssid_mac_postfix_r0=$SSID_MAC_POSTFIX_R0

uci set env.var.default_key_r0_s0=$KEY_R0_S0
uci set env.var.default_wep_key_r0_s0=$WEP_KEY_R0_S0
uci set env.var.default_wps_ap_pin_r0_s0=$PIN_R0_S0

uci set env.var.default_key_r0_s1=$KEY_R0_S1
uci set env.var.default_wep_key_r0_s1=$WEP_KEY_R0_S1
uci set env.var.default_wps_ap_pin_r0_s1=$PIN_R0_S1

uci set env.var.default_key_r0_s2=$KEY_R0_S2
uci set env.var.default_wep_key_r0_s2=$WEP_KEY_R0_S2
uci set env.var.default_wps_ap_pin_r0_s2=$PIN_R0_S2

uci set env.var.default_key_r0_s3=$KEY_R0_S3
uci set env.var.default_wep_key_r0_s3=$WEP_KEY_R0_S3
uci set env.var.default_wps_ap_pin_r0_s3=$PIN_R0_S3

#Radio 1
uci set env.var.ssid_mac_postfix_r1=$SSID_MAC_POSTFIX_R1

uci set env.var.default_key_r1_s0=$KEY_R1_S0 
uci set env.var.default_wep_key_r1_s0=$WEP_KEY_R1_S0
uci set env.var.default_wps_ap_pin_r1_s0=$PIN_R1_S0

uci set env.var.default_key_r1_s1=$KEY_R1_S1 
uci set env.var.default_wep_key_r1_s1=$WEP_KEY_R1_S1
uci set env.var.default_wps_ap_pin_r1_s1=$PIN_R1_S1

uci set env.var.default_key_r1_s2=$KEY_R1_S2 
uci set env.var.default_wep_key_r1_s2=$WEP_KEY_R1_S2
uci set env.var.default_wps_ap_pin_r1_s2=$PIN_R1_S2

uci set env.var.default_key_r1_s3=$KEY_R1_S3 
uci set env.var.default_wep_key_r1_s3=$WEP_KEY_R1_S3
uci set env.var.default_wps_ap_pin_r1_s3=$PIN_R1_S3


#Radio 2
if [ "$SSID_MAC_POSTFIX_R2" != "" ]; then

  uci set env.var.ssid_mac_postfix_r2=$SSID_MAC_POSTFIX_R2

  uci set env.var.default_key_r2_s0=$KEY_R2_S0
  uci set env.var.default_wep_key_r2_s0=$WEP_KEY_R2_S0
  uci set env.var.default_wps_ap_pin_r2_s0=$PIN_R2_S0

  uci set env.var.default_key_r2_s1=$KEY_R2_S1
  uci set env.var.default_wep_key_r2_s1=$WEP_KEY_R2_S1
  uci set env.var.default_wps_ap_pin_r2_s1=$PIN_R2_S1

  uci set env.var.default_key_r2_s2=$KEY_R2_S2
  uci set env.var.default_wep_key_r2_s2=$WEP_KEY_R2_S2
  uci set env.var.default_wps_ap_pin_r2_s2=$PIN_R2_S2

  uci set env.var.default_key_r2_s3=$KEY_R2_S3
  uci set env.var.default_wep_key_r2_s3=$WEP_KEY_R2_S3
  uci set env.var.default_wps_ap_pin_r2_s3=$PIN_R2_S3

fi

uci commit env

rm $KEYGEN_OUTPUT
