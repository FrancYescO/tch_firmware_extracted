#!/bin/sh
usage()
{
cat << EOF
usage: $0 options

This script tests the LEDs on the board.

OPTIONS:
   -h      Show this message
   -b      Base path to use (defaults to /sys/class/leds)
   -d      Delay (blink rate; defaults to 1000ms)
   -p      On/off Pattern string
   -l      Led type (power/wireless/wps/ethernet/voip/iptv/broadband/dect - defaults to *)
   -c      Color (green/red/blue - defaults to *)
   -s      State (1/0 - defaults to 1)
   -v      Verbose mode
EOF
}

BASEPATH='/sys/class/leds'
COLOR='*'
LED='*'
STATE=1
VERBOSE=0
PATTERN=''
DELAY=1000

while getopts "hb:c:d:l:p:s:v" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         b)
             BASEPATH=$OPTARG
             ;;
         c)
             COLOR=$OPTARG
             ;;
         d)
             DELAY=$OPTARG
             ;;
         l)
             LED=$OPTARG
             ;;
         p)
             PATTERN=$OPTARG
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

if [ $VERBOSE -eq 1 ]; then
echo "Basepath: $BASEPATH"
echo "LED     : $LED"
echo "Color   : $COLOR"
echo "State    : $STATE"
echo "Delay    : $DELAY"
echo "Pattern  : $PATTERN"
fi

for dir in $BASEPATH/$LED:$COLOR/; do
	if [ ! -d $dir ]; then
		echo "No LED directory matching $LED:$COLOR found in $BASEPATH"
		exit
	else
		if [ $VERBOSE -eq 1 ]; then
			echo "Processing $dir"
		fi

		echo none > $dir/trigger
		if [ $STATE -eq 1 ]; then
			cat $dir/max_brightness > $dir/brightness
		else
			echo 0 > $dir/brightness
			echo none >$dir/trigger
		fi
		if [ "$PATTERN" ]; then
			echo pattern > $dir/trigger
			echo $DELAY > $dir/delay
			echo $PATTERN >$dir/message
		fi
	fi
done
