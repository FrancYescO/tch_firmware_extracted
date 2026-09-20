#!/bin/sh
# Copyright (c) 2015 Technicolor

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/functions/syslog.sh
. $IPKG_INSTROOT/usr/lib/mwan/functions.sh

# (1) This reloads syslogd with latest settings; can cause a crash : comment it out for now; modified syslogd parameter will take effect after next reboot
#/etc/init.d/boot reload

# (2a) syslog_fwd restart, 1st phase
/etc/init.d/syslog_fwd restart

# (2b) syslog_fwd restart, 2nd phase
# Must toggle syslog interface to trigger the hotplug syslog-fwd script
get_syslog_iface syslog_iface
# ifup is sufficient to toggle the interface
ifup $syslog_iface
