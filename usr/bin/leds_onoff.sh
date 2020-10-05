#!/bin/sh
usage()
{
cat << EOF
usage: $0 options

This script turns on/off the LEDs on the board.

OPTIONS:
   -h      Show this message
   -s      State (1/0 - defaults to 1)
   -v      Verbose mode
EOF
}

BASEPATH='/sys/class/leds'
COLOR='*'
LED='*'
STATE=1
VERBOSE=0
INFOBUTTON_ON='/tmp/infobutton_on'

if test -z "$OPTARG"; then
	if [ ! -f $INFOBUTTON_ON ]; then
		touch $INFOBUTTON_ON
		STATE=1
	else
		rm -f $INFOBUTTON_ON
		STATE=0
	fi
else
while getopts "hs:v" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         s)
             STATE=$OPTARG
             ;;
	 v)
	     VERBOSE=1
	     ;;
         ?)
             usage
             exit
             ;;
     esac
done
fi

if [ $VERBOSE -eq 1 ]; then
echo "State    : $STATE"
fi

shutdown_leds()
{
	for dir in $BASEPATH/$LED:$COLOR/; do
    	if [ ! -d $dir ]; then
        	echo "No LED directory matching $LED:$COLOR found in $BASEPATH"
        	exit
    	else
        	if [ $VERBOSE -eq 1 ]; then
            	echo "Processing $dir"
        	fi

			# power LED will not be impacted by info button
        	if [ $dir == "$BASEPATH/power:green/" ]; then
				continue
        	fi
        	if [ $dir == "$BASEPATH/power:orange/" ]; then
				continue
        	fi
        	echo none > $dir/trigger
           	echo 0 > $dir/brightness
    	fi
	done
}
if [ $STATE -eq 1 ]; then
	# power LED will not be impacted by info button
	shutdown_leds 
	[ -x /usr/bin/lanleds_onoff.sh ] && lanleds_onoff.sh -s 0 
	ubus send infobutton '{"state":"on"}'
else
	ubus send infobutton '{"state":"off"}'
	[ -x /usr/bin/lanleds_onoff.sh ] && lanleds_onoff.sh -s 1 
fi

