# Copyright (c) 2015 Technicolor

. $IPKG_INSTROOT/lib/functions.sh

to_stop_samba()
{
    logger -t umount-usb "Stopping Samba"
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
    logger -t umount-usb "Restarting Samba"
    SMBD_STATUS=`ps |grep smbd|grep -v grep|wc -w`
    if [ $GSMBD_WAS_RUNNING = "yes" ] && [ "$SMBD_STATUS" -eq 0 ] ; then
        /etc/init.d/samba start
        GSMBD_WAS_RUNNING="x"
        echo "usb_storage:to_start_samba - samba has been started again"
    else
        echo "usb_storage:to_start_samba - Error: samba has not been started again !"
    fi
}

to_stop_minidlna()
{
    logger -t umount-usb "Stopping MiniDLNA"
    /etc/init.d/minidlna stop
}

to_start_minidlna()
{
    logger -t umount-usb "Restarting MiniDLNA"
    /etc/init.d/minidlna start
}

do_unmount()
{
   # ${1} is the value of option device.
   # Mountd mounts these devices inside the directory /tmp/run/mountd/ on the
   # directory 'device'.
   local device=${1}
   local mount="/tmp/run/mountd/${device}"

   logger -t umount-usb "Ejecting (unmount) ${mount}"
   /bin/umount ${mount}
}

#to process each mount point, do umount
to_stop_samba
to_stop_minidlna

config_load usb
config_list_foreach unmount device do_unmount
uci_set_state usb unmount device ""
uci_commit usb

to_start_minidlna
to_start_samba


