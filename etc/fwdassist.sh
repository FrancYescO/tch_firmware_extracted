#!/bin/sh

unset CDPATH

SCRIPTNAME=/etc/fwdassist.sh

load_value()
{
  local DATAFILE=$1
  local KEY=$2
  local L=$(grep $KEY $DATAFILE)
  if [ -n $L ]; then
    echo $L | cut -d'=' -f 2 | tr -d ' '
  fi  
}

apply()
{
  local RULE=$1
  echo $RULE
  iptables $RULE
}

redirect()
{
  local DATAFILE=$1
  local ENABLED=$(load_value $DATAFILE enabled)
  local IFNAME=$(load_value $DATAFILE ifname)
  local LAN_PORT=$(load_value $DATAFILE lanport)
  local WAN_PORT=$(load_value $DATAFILE wanport)

  if [ -z $IFNAME ]; then
    return
  fi
  WAN_IP=$(lua -e "dm=require'datamodel';r=dm.get('rpc.network.interface.@$IFNAME.ipaddr'); \
           if r and r[1] then print(r[1].value) end")

  if [ -z $WAN_IP ]; then
    return
  fi

  if [ "$ENABLED" = "1" ]; then
    ACT="-I"
  else
    ACT="-D"
  fi

  local FWD_NULL="-t nat $ACT delegate_prerouting -p tcp --dst $WAN_IP --dport $LAN_PORT -j REDIRECT --to-port 65535"
  local FWD_RULE="-t nat $ACT delegate_prerouting -m tcp -p tcp --dst $WAN_IP --dport $WAN_PORT -j REDIRECT --to-ports $LAN_PORT"
  local ACCEPT_RULE="-t filter $ACT delegate_input -p tcp --dst $WAN_IP --dport $LAN_PORT -j ACCEPT"

  if [ "$LAN_PORT" != "$WAN_PORT" ]; then
    apply "$FWD_RULE"
    apply "$FWD_NULL"
  fi
  apply "$ACCEPT_RULE"
}

for datafile in $(ls /var/run/assistance/*); do
  redirect $datafile
done

# make sure it gets reloaded when the firewall is reloaded
S=$(uci get firewall.fwdassist.path 2>/dev/null)
if [ "$S" != "$SCRIPTNAME" ]; then
  uci set firewall.fwdassist=include
  uci set firewall.fwdassist.path=$SCRIPTNAME
  uci set firewall.fwdassist.reload=1
  uci commit
fi
