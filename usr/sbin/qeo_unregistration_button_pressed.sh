#!/bin/sh

# Qeo config file holds the following variables
# QEO_REGISTRATION_FILE --> location of fifo registration file
# QEO_DIR --> location of the .qeo directory
# QEO_LOCK --> locking file of the qeo registration scripts
# QEO_INTERFACE --> interface that qeo will use

QEO_CONFIG_FILE=/etc/qeo/qeo.conf
source ${QEO_CONFIG_FILE}

QEO_UTIL_FILE=/etc/qeo/qeo_util.sh
source ${QEO_UTIL_FILE}

# Delete the qeo directory
rm -rf ${QEO_DIR}

# Start the blinking qeo unregistration led 
ubus send qeo.power_led '{"state":"unreg"}'

# Restart all the qeo programs
# forwarder
/etc/init.d/qeo-forwarder stop
/etc/init.d/qeo-forwarder start

# mytribe / mmpbx
#/etc/init.d/mmpbxd stop
#/etc/init.d/mmpbxd start

# Remove all qeo ports in the firewall
firewall_remove_all_qeo_ports

sleep 2

# Stop the blinking qeo unregistration led
ubus send qeo.power_led '{"state":"idle"}'
