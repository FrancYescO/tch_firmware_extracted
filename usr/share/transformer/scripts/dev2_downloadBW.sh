#!/bin/sh

swshaping=$(uci -q get fastweb.port_shaping.enable_sw_shaping)

ifname=$(uci -q get network.wan.ifname)
[ -z $ifname ] && exit 0

if [ ${ifname:0:1} = "@" ]; then
  interface=$(uci -q get network.${ifname#*@}.ifname)
else
  interface=$ifname
fi

ipt_skiplog_chain="ds_shaping_skiplog"
mark_value=0x10000000
mask_value=0xf0000000

dsport=$(uci -q get fastweb.port_shaping.dsport)
if [ -n "$interface" ]; then
  if [ -z "$dsport" ]; then
    [ -n "$(eval "ip link |grep $interface")" ] && dsport=$interface
  elif [ "$dsport" != "$interface" ]; then
    dsport=$interface
  fi
else
  exit 0
fi


loopbackip=$(uci -q get network.wan.ipaddr)
if [ -z $loopbackip ]; then
  iprule="-s 0.0.0.0/0"
  tcrule="src 0.0.0.0/0"
else
  iprule="-d $loopbackip/32"
  tcrule="dst $loopbackip/32"
fi

ds_disable=$(uci -q get fastweb.port_shaping.ds_disable)
[ -z $ds_disable ] && ds_disable='1'
ds_rate=$(uci -q get fastweb.port_shaping.total_download_bw)
if [ -n $ds_rate ]; then
  dsrate_byte=`expr $ds_rate \/ 8`
  dsburst_byte=`expr $ds_rate \/ 80`
  ds_burst=`expr $dsburst_byte + $dsrate_byte`
fi

add_skiplog_rules() {
  [ -z "$(iptables -S -t mangle | grep $ipt_skiplog_chain)" ] && iptables -t mangle -N $ipt_skiplog_chain && iptables -t mangle -I PREROUTING -j $ipt_skiplog_chain
  iptables -t mangle -A $ipt_skiplog_chain -m comment --comment "skiplog for ingress shaping" -i br-lan -j MARK --set-xmark ${mark_value}/${mask_value}
  iptables -t mangle -A $ipt_skiplog_chain -m comment --comment "skiplog for ingress shaping" $iprule -j MARK --set-xmark ${mark_value}/${mark_value}
  iptables -t mangle -A $ipt_skiplog_chain -m mark --mark ${mark_value}/${mask_value} -j SKIPLOG
}

del_skiplog_rules() {
  iptables -t mangle -F $ipt_skiplog_chain
}

if [ -n "$dsport" ]; then
  if [ "$ds_disable" = "0" ] && [ -n $ds_rate ] && ([ -z $swshaping ] || [ "$swshaping" = "1" ]); then
    tc qdisc del dev $dsport ingress
    del_skiplog_rules

    tc qdisc add dev $dsport handle ffff: ingress
    tc filter add dev $dsport parent ffff: protocol ip prio 10 u32 match ip $tcrule police rate ${ds_rate}kbit burst ${ds_burst}k drop flowid :1
    add_skiplog_rules
    fcctl flush
    uci set -q qos.${dsport}.ingress='ignore'
    uci commit
  else if [ "$ds_disable" = "1" ]; then
         tc qdisc del dev $dsport ingress
         del_skiplog_rules
         uci del -q qos.${dsport}.ingress
         uci commit
       fi
  fi
fi

