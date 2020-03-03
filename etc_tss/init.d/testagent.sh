#!/bin/sh

START=15
STOP=97

start() {
  echo "Run cm..."

  [ ! -e /etc/ah ] && ln -s /etc_tss/ah /etc/ah
  [ ! -e /etc/cm ] && ln -s /etc_tss/cm /etc/cm

  cm >> /dev/null
  cmclient DOM Device /etc/cm/dom/ >> /dev/null
  cmclient DOM Device /etc/cm/domx/ >> /dev/null

  cmclient CONF /etc/cm/factory/ >> /dev/null
  cmclient CONF /etc/cm/version/ >> /dev/null
  cmclient CONF /etc/cm/conf/ >> /dev/null

  MACAddress=`cat /sys/class/net/br-lan/address`
  cmclient SET Ethernet.Interface.1.MACAddress "$MACAddress"
  cmclient SET X_ADB_FactoryData.BaseMACAddress "$MACAddress"
  cmclient SET IP.Diagnostics.X_ADB_Report.Interface Device.IP.Interface.1
  cmclient SET IP.Diagnostics.X_ADB_Report.Enable true >> /dev/null

  cmclient SET IP.Diagnostics.IPPing.Interface Device.IP.Interface.1
  cmclient SET IP.Diagnostics.DownloadDiagnostics.Interface Device.IP.Interface.1
  cmclient SET IP.Diagnostics.UploadDiagnostics.Interface Device.IP.Interface.1

  echo "Run ec..."
  ec2 & >> /dev/null

  echo "Run http deamon..."
  lighttpd -f /etc_tss/lighttpd/lighttpd.conf || lighttpd -f /etc_tss/lighttpd/lighttpd_lo.conf
}

stop() {
  killall cm
  killall ec2
  killall lighttpd
}
