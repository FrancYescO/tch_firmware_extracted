#!/bin/sh
# Copyright (c) 2015 Technicolor

FILE=/tmp/toumountusb
if [[ ! -f $FILE ]]; then
    return
fi

to_stop_samba()
{
    logger -t umount-usb "=====to stop samba====="
    SMBD_STATUS=`ps |grep smbd|grep -v grep|wc -w`
    if [ "$SMBD_STATUS" -ne 0 ]; then
        GSMBD_WAS_RUNNING="yes"
        echo "usb_storage:to_stop_samba - samba was running"
        /etc/init.d/samba stop
        sleep 2
    else
        echo "usb_storage:to_stop_samba - samba was NOT running"
    fi
}

to_start_samba()
{
    logger -t umount-usb "=====to start samba====="
    SMBD_STATUS=`ps |grep smbd|grep -v grep|wc -w`
    if [ $GSMBD_WAS_RUNNING = "yes" ] && [ "$SMBD_STATUS" -eq 0 ] ; then
        /etc/init.d/samba start
        GSMBD_WAS_RUNNING="x"
        echo "usb_storage:to_start_samba - samba has been started again"
    else
        echo "usb_storage:to_start_samba - Error: samba has not been started again !"
    fi
}


#to process each mount point, do umount
to_stop_samba

logger -t umount-usb "======to do umount usb====="

for i in `cat $FILE`
do
    /usr/bin/fuser -km $i
    /bin/umount -l $i
    rm -rf $i
done

to_start_samba

rm $FILE

logger -t umount-usb "======to run content-sharing====="
SUBSYSTEM=usb /usr/bin/content-sharing
