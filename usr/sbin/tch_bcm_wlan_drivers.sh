#TODO: This script needs to be re-visited
# Stopping hostapd #
#/etc/init.d/hostapd stop

echo "START tch_bcm_wlan_drivers.sh" > /dev/console

PID_FILE=/var/run/hostapd.pid
RUNNING_FILE=/var/run/hostapd_running
  if [ ! -e "$PID_FILE" ] ; then
    echo Hostapd not running > /dev/console
  else
    echo Stopping hostapd > /dev/console
  fi
    PID=$(cat $PID_FILE)
    rm $PID_FILE
    rm $RUNNING_FILE
    kill -9 $PID

rmmod dhd > /dev/null
rmmod wl > /dev/null
rmmod wfd > /dev/null
rmmod igs > /dev/null
rmmod emf > /dev/null
rmmod hnd > /dev/null
rmmod wlcsm > /dev/null

# Re-inserting wireless kernel modules with proper kmod parameters #
/etc/init.d/wireless restart

# Deleting previous device nodes  #
rm /dev/dhd_event
rm /dev/wl_event

# Cleaning up files created in tmpfs #
rm /tmp/hostapd*



echo Starting hostapd > /dev/console
# Satrting hostapd #
/etc/init.d/hostapd start

sleep 5
/etc/init.d/network restart
