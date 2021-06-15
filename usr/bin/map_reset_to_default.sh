#!/bin/sh

. /usr/bin/map_common_reset_credentials.sh

/etc/init.d/multiap_controller stop
/etc/init.d/multiap_agent stop

reset_type=$1

echo $reset_type

# Set controller_credentials for BH

if [ $reset_type == 2 ]; then
    echo "Reset BH also"
    set_BH_credentials
fi

/etc/init.d/multiap_controller start
/etc/init.d/multiap_agent start



