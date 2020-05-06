#!/bin/sh

# Qeo config file holds the following variables
# QEO_REGISTRATION_FILE --> location of fifo registration file
# QEO_DIR --> location of the .qeo directory
# QEO_LOCK --> locking file of the qeo registration scripts
# QEO_INTERFACE --> interface that qeo will use
# QEO_TCP_PORT --> location where the tcp port will be written to
# QEO_FWD --> name of the application and firewall rule

QEO_CONFIG_FILE=/etc/qeo/qeo.conf
source ${QEO_CONFIG_FILE}

QEO_UTIL_FILE=/etc/qeo/qeo_util.sh
source ${QEO_UTIL_FILE}

REG_WINDOW_NAME=`uci get wireless.wl0.ssid`
REG_WINDOW_TIME=180

# Lock the qeo registration by taking a locked file here

lock ${QEO_LOCK}

# Check if the .qeo/truststore.p12 file exists
# This will only exist if the app is already registered
# If it exists, there is no use to execute the rest of the script
if [ -e ${QEO_DIR}/truststore.p12 ];
then
    echo ".qeo/truststore.p12 already exists, no need to open the remote registration window"
    lock -u ${QEO_LOCK}
    exit 1
fi

# The registration name and window can be set by the caller
if [ $# -eq 2 ]
then
    REG_WINDOW_NAME=${1}
    REG_WINDOW_TIME=${2}
fi

# Check if fifo file exists, must succeed, else problem
# -e: check if file exists
# -f: check if file exists and regular file
# -p: check if file exists and fifo file
if [ ! -p ${QEO_REGISTRATION_FILE} ];
then
    echo "Could not find the qeo registration fifo file"
    lock -u ${QEO_LOCK}
    exit 1
fi
# Qeo registration fifo file exists

# Write registration parameters to the file
echo "${REG_WINDOW_NAME} ${REG_WINDOW_TIME}" > ${QEO_REGISTRATION_FILE}

# Show a blinking power led
ubus send qeo.power_led '{"state":"inprogress"}'

# Wait till we know the port the forwarder has chosen, to open the port in the firewall
read -t ${REG_WINDOW_TIME} TCP_PORT <> ${QEO_TCP_PORT}

if [ ! -z ${TCP_PORT} ]
then
    # Remove all qeo ports
    firewall_remove_all_qeo_ports

    # Add new one
    firewall_add_port ${TCP_PORT}

    # Restart the firewall
    /etc/init.d/firewall restart
fi

# stop the blinking power led
ubus send qeo.power_led '{"state":"idle"}'

# Free the lock file again as to make the qeo registration available
lock -u ${QEO_LOCK}
