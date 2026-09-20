#!/bin/sh

CRONTABS=/etc/crontabs
CRONRULE=$CRONTABS/root

if !(grep -q "\*/1 \* \* \* \* /sbin/assistance-helper.lua" $CRONRULE 2>/dev/null); then
   mkdir -p $CRONTABS
   echo "*/1 * * * * /sbin/assistance-helper.lua" >> $CRONRULE
   sed -i "/^$/d" $CRONRULE
   if !(grep -q "crond" $(ps) 2>/dev/null); then
      /etc/init.d/cron start
   fi
fi
