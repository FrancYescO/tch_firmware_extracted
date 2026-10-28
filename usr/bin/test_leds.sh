#!/bin/sh
cd /sys/class/leds/
echo -e "\nAvailable LEDs (with max brightness) :\n"

for file in *:* ;do max_brightness=$(cat $file/max_brightness);echo $file, max brightness=$max_brightness;done
echo -e "\nPress ENTER to continue...\n"
read
echo -e "\nSwitching all leds ON :\n"
for file in *:* ;do echo $max_brightness >$file/brightness;done
echo -e "\nPress ENTER to continue...\n"
read
echo -e "\nSwitching all leds OFF :\n"
for file in *:* ;do echo 0 >$file/brightness;done
echo -e "\nPress ENTER to continue...\n"
read
echo -e "\nSwitching all leds ON and OFF one by one (with all possible brightness levels):\n"
for file in *:* ;do echo $file ON with;max_brightness=$(cat $file/max_brightness);for i in $(seq $max_brightness);do echo brightness $i;echo $i >$file/brightness;for cnt in $(seq 40);do sleep 0;done;done;echo -e "\nPress ENTER to continue...\n";read; echo $file OFF;echo 0 >$file/brightness ;read; done
#for file in *:* ;do echo $file;echo 0 >$file/brightness;sleep 3;done
