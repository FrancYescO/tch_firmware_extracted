#!/bin/sh

CRONTABS=/etc/crontabs
CRONRULE=$CRONTABS/root

if !(grep -q "/usr/sbin/dsl_restart.sh" $CRONRULE 2>/dev/null); then
    echo "1 2 * * * /usr/sbin/dsl_restart.sh" >> $CRONRULE
    if !(grep -q "crond" $(ps) 2>/dev/null); then
        /etc/init.d/cron start
    fi
fi

touch /tmp/tmp/dsl_restart
