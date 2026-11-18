#!/bin/sh

unset CDPATH

SCRIPTNAME=/etc/fwdassist.sh

CUSTO_RULES=/etc/ra_forward.sh

export RA_NAME=
export DATAFILE=
export ENABLED=
export IFNAME=
export LAN_PORT=
export WAN_PORT=
export WAN_IP=

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
  logger -t RAFWD -- $RULE
  iptables $RULE
}

redirect()
{
  DATAFILE=$1
  ENABLED=$(load_value $DATAFILE enabled)
  IFNAME=$(load_value $DATAFILE ifname)
  LAN_PORT=$(load_value $DATAFILE lanport)
  local WAN_PORT=$(load_value $DATAFILE wanport)

  if [ -z $IFNAME ]; then
    return
  fi
  WAN_IP=$(lua -e "dm=require'datamodel';r=dm.get('rpc.network.interface.@$IFNAME.ipaddr'); \
           if r and r[1] then print(r[1].value) end")

  if [ -z $WAN_IP ]; then
    return
  fi

  if [ -x $CUSTO_RULES ]; then
    $CUSTO_RULES
  else
    if [ "$ENABLED" = "1" ]; then
      ACT="-I"
    else
      ACT="-D"
    fi

    local FWD_RULE="-t nat $ACT prerouting_rule -m tcp -p tcp --dst $WAN_IP --dport $WAN_PORT -j REDIRECT --to-ports $LAN_PORT"
    local FWD_NULL="-t nat $ACT prerouting_rule -p tcp --dst $WAN_IP --dport $LAN_PORT -j REDIRECT --to-port 65535"
    local ACCEPT_RULE="-t filter $ACT input_rule -p tcp --dst $WAN_IP --dport $LAN_PORT -j ACCEPT"

    if [ "$LAN_PORT" != "$WAN_PORT" ]; then
      apply "$FWD_RULE"
      apply "$FWD_NULL"
    fi
    apply "$ACCEPT_RULE"
  fi
}

for datafile in $(ls /var/run/assistance/*); do
  RA_NAME=$(basename $datafile)
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
