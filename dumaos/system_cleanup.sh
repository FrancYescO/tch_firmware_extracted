#!/bin/sh

iptables_cleanup() {
if [ $(ip6tables -t nat -nvL &>/dev/null) ];then
  V6NAT=1
else
  V6NAT=0
fi
for chain in nat mangle filter
do
  CHAINS=$(iptables -nL -t$chain 2>/dev/null | grep "Chain\ " | grep "nd_\|hyperlane\|_mark\|geo\|tc_\|gf.*_" | cut -d' ' -f2)
  CLEAN=0
  while [ "$CLEAN" -ne "1" ]
  do
    for value in $CHAINS
    do
#      echo "$chain - $value"
      iptables -t$chain -F $value 2>/dev/null
      iptables -t$chain -X $value 2>/dev/null
      if [ "$(echo $?)" -ne "0" ];then
        for ref in INPUT OUTPUT FORWARD POSTROUTING PREROUTING
        do
          if [ "$(iptables -t$chain --list-rules $ref 2>/dev/null | grep -ic "$value")" -gt "0" ];then
             line=$(iptables -t$chain --list-rules $ref 2>/dev/null | grep $value | sed 's/-A/-D/g')
#             echo "$chain - $ref - $value - $line"
             if [ -n "$line" ];then
	       printf "%s\n" "$line" | while IFS= read -r ln
	       do
		 iptables -t$chain $ln 2>/dev/null
	       done
             fi
          fi
        done
        iptables -t$chain -X $value 2>/dev/null
      fi
      if [ "$V6NAT" = "0" -a "$chain" = "nat" ];then
        continue
      fi
        ip6tables -t$chain -F $value 2>/dev/null
        ip6tables -t$chain -X $value 2>/dev/null
        if [ "$(echo $?)" -ne "0" ];then
              for ref in INPUT OUTPUT FORWARD POSTROUTING PREROUTING
              do
                if [ "$(ip6tables -t$chain --list-rules $ref 2>/dev/null | grep -ic "$value")" -gt "0" ];then
                  line=$(ip6tables -t$chain --list-rules $ref 2>/dev/null | grep $value | sed 's/-A/-D/g')
                  if [ -n "$line" ];then
                    printf "%s\n" "$line" | while IFS= read -r ln
		    do
                      ip6tables -t$chain $ln 2>/dev/null
                    done
                  fi
                fi
              done
              ip6tables -t$chain -X $value 2>/dev/null
       fi
    done
  if [ ! -n "$(iptables -nL -t$chain 2>/dev/null | grep "Chain\ " | grep "nd_\|hyperlane\|_mark\|geo\|tc_\|gf.*_")" ];then
    CLEAN=1
  fi
  done
done
}

iprules_cleanup() {
if [ "$VENDOR" != "TELSTRA" -a "$VENDOR" != "BT" -a "$ODM" != "SEAL" ];then
  while [ "$(ip rule show | grep fwmark)" ];
  do
    ip rule show | grep fwmark | awk -F":" '{print $1}' | xargs -n1 ip rule del pref > /dev/null 1>&2
  done
fi
for set in $(ipset list | grep -Eo "aaipset[0-9]*")
do
  ipset destroy "$set" > /dev/null 1>&2
done
return 0
}

stop_seal_cron(){
    if [ "$ODM" = "SEAL" ]; then
        while [ -n "$(pgrep crond)" ]; do
            killall crond 2>/dev/null 1>&2
        done
    fi
}

stop_seal_cron
killall -9 iptables-restore 2> /dev/null
iptables_cleanup
iprules_cleanup
