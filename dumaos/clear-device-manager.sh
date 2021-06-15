#!/bin/sh

case "`cat /dumaossystem/model`" in
  XR300|XR1000)
    data_path=/tmp/media/nand/dumaos/rapp-data/
    ;;
  *)
    data_path=/dumaos/apps/
    ;;
esac

/etc/init.d/dumaos stop
rm ${data_path}/com.netdumasoftware.devicemanager/data/database.db
/dumaos/resetconfig.lua "com.netdumasoftware.devicemanager.database" 

sync

echo "You can safely pull the plug now!"
