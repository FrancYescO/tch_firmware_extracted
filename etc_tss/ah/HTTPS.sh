#!/bin/sh

resetLighttpd()
{
  sleep 2
  killall lighttpd &> /dev/null
  lighttpd -f /etc_tss/lighttpd/lighttpd.conf || lighttpd -f /etc_tss/lighttpd/lighttpd_lo.conf
  cmclient SETE Device.X_ADB_QoE.HTTPS.RefreshCredentials false
}

if [ "$newRefreshCredentials" = "true" -a "$oldRefreshCredentials" = "false" ]; then
  resetLighttpd &
fi

exit 0