# common.lib
# Note no #!/bin/sh as this should not spawn 
# an extra shell.

# Set controller_credentials for FH
set_FH_credentials(){
  uci set multiap.cred0.ssid=`uci get env.var.ssid_prefix``uci get env.var.ssid_mac_postfix_r0`
  uci set multiap.cred2.ssid=`uci get env.var.ssid_prefix``uci get env.var.ssid_mac_postfix_r0`
  
  uci set multiap.cred0.wpa_psk_key=`uci get env.var.default_key_r0_s0`
  uci set multiap.cred2.wpa_psk_key=`uci get env.var.default_key_r0_s0`

  security_mode=`uci get env.var.default_security_mode_r0_s0`
  if [ -z $security_mode ] ; then
    uci set multiap.cred0.security_mode=wpa2-psk
    uci set multiap.cred2.security_mode=wpa2-psk
  else
    uci set multiap.cred0.security_mode=`uci get env.var.default_security_mode_r0_s0`
    uci set multiap.cred2.security_mode=`uci get env.var.default_security_mode_r0_s0`
  fi

  uci set multiap.cred0.fronthaul=1
  uci set multiap.cred2.fronthaul=1

  uci set multiap.cred0.backhaul=0
  uci set multiap.cred2.backhaul=0

  uci set multiap.cred0.frequency_bands=radio_2G,radio_5Gu,radio_5Gl
  uci set multiap.cred2.frequency_bands=radio_5Gu,radio_5Gl
  
  uci set multiap.cred2.state=0

  # Commit the changes

  uci commit multiap
}

# Set controller_credentials for BH
set_BH_credentials(){
  uci set multiap.cred1.ssid="BH-$(uci get env.var.ssid_mac_postfix_r0)"

  uci set multiap.cred1.wpa_psk_key=`uci get env.var.default_key_r1_s0`

  security_mode=`uci get env.var.default_security_mode_r1_s0`
  if [ -z $security_mode ] ; then
    uci set multiap.cred1.security_mode=wpa2-psk
  else
    uci set multiap.cred1.security_mode=`uci get env.var.default_security_mode_r1_s0`
  fi

  uci set multiap.cred1.fronthaul=0

  uci set multiap.cred1.backhaul=1

  uci set multiap.cred1.frequency_bands=radio_2G,radio_5Gu

  # Commit the changes

  uci commit multiap
}



