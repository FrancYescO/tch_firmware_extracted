#!/bin/sh

# (C) 2017 NETDUMA Software
# Method for R-Apps to restart DumaOS including themselves. Run this command
# in the background. Very hacky at the moment, fully based on timing mechanisms
# meaning potential race condtions. But in practice large timeouts should 
# work.

# Wait for R-Apps rpc call to finish. Could be more sophisticated
# e.g. flock held by all rpc.
sleep 2

/etc/init.d/dumaos stop > /dev/null 2>&1
/etc/init.d/miniupnpd stop > /dev/null 2>&1
rm /var/upnp.leases > /dev/null 2>&1

/etc/init.d/network restart > /dev/null 2>&1
/etc/init.d/firewall reload > /dev/null 2>&1

# wait for all to die
sleep 5

/etc/init.d/miniupnpd start
/etc/init.d/dumaos start
