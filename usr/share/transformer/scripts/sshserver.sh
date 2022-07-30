#!/bin/sh
interfaceName="$1"

uci set dropbear.$interfaceName.enable="0"
uci commit

/etc/init.d/dropbear reload

crontab -c /etc/crontabs/ -l | grep -v "/usr/share/transformer/scripts/sshserver.sh $interfaceName" | crontab -c /etc/crontabs -
