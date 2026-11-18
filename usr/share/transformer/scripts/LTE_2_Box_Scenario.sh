#!/bin/sh

l2type=`uci get wansensing.global.l2type`

if [ "${l2type}" == "ETH" ]; then
  scenario=`uci get env.custovar_sensing.Scenario`

  oper_acs_url=`uci get cwmpd.cwmpd_config.acs_url`
  oper_acs_user=`uci get cwmpd.cwmpd_config.acs_user`
  oper_acs_pass=`uci get cwmpd.cwmpd_config.acs_pass`
  oper_connectionrequest_username=`uci get cwmpd.cwmpd_config.connectionrequest_username`
  oper_connectionrequest_password=`uci get cwmpd.cwmpd_config.connectionrequest_password`
  oper_periodicinform_enable=`uci get cwmpd.cwmpd_config.periodicinform_enable`
  oper_periodicinform_interval=`uci get cwmpd.cwmpd_config.periodicinform_interval`

  [ $scenario == "1" ] && section="operationalACS2" || section="operationalACS1"
  uci set cwmpd.${section}.acs_url=$oper_acs_url
  uci set cwmpd.${section}.acs_user=$oper_acs_user
  uci set cwmpd.${section}.acs_pass=$oper_acs_pass
  uci set cwmpd.${section}.connectionrequest_username=$oper_connectionrequest_username
  uci set cwmpd.${section}.connectionrequest_password=$oper_connectionrequest_password
  uci set cwmpd.${section}.periodicinform_enable=$oper_periodicinform_enable
  uci set cwmpd.${section}.periodicinform_interval=$oper_periodicinform_interval
fi
uci commit cwmpd
