#
# (C) 2018 NETDUMA Software
# Kian Cross <kian.cross@netduma.com>
#

SUB_SYSTEM=$1

if [ "$SUB_SYSTEM" == "iface" ]; then
  export ACTION=$3
  export DEVICE=$2

  if [ "$DEVICE" == "br0" ] || [ "$DEVICE" == "br-lan" ] ; then
    export INTERFACE="lan"
  fi
fi

DIR="/etc/hotplug.d"
for I in "${DIR}/${SUB_SYSTEM}/"* "${DIR}/"default/* ; do
  if [ -f $I ]; then
    test -x $I && $I
  fi
done
