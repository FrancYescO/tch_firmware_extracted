#!/bin/sh
usage()
{
cat << EOF
usage: $0 options

This script on/off the LAN LEDs TG1600.

OPTIONS:
   -h      Show this message
   -s      State (1/0 - defaults to 1)
EOF
}

PHY0_ID=7
PHY1_ID=8
LED_ON=0x0022
LED_OFF=0
STATE=1

while getopts “h:s:” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         s)
             STATE=$OPTARG
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [ $STATE -eq 1 ]; then
	ethctl phy ext $PHY0_ID 31 8
	ethctl phy ext $PHY1_ID 20 $LED_ON
	ethctl phy ext $PHY0_ID 31 0 
else
	ethctl phy ext $PHY0_ID 31 8
	ethctl phy ext $PHY1_ID 20 $LED_OFF
	ethctl phy ext $PHY0_ID 31 0 
fi

