#!/bin/sh
if [ -f /etc/init.d/dropbear -a "${PREINIT}" != "1" ]; then
  /etc/init.d/dropbear restart > /dev/null
fi
