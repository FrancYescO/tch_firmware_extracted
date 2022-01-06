#!/bin/sh

print_help ()
{
  echo "bosa_caldata.sh [cmd]"
  echo "cmd : store, clean, lock"

  exit 1
}

CMD=$1;

#Validate input
if [ -z $CMD ] ; then
  print_help
fi

OK=0
if [ "$CMD" = "store" ] || [ "$CMD" = "lock" ] || [ "$CMD" = "clean" ]; then
  OK=1
fi

if [ "$OK" = "0" ] ; then
  print_help
fi

BOSA_FILE=/etc/bosa.dat
BOSA_CAL_RIP=/proc/rip/0141
BOSA_TAR_FILE=/etc/bosa.dat.tar.gz
expected_perms="-r--r--r--"


if [ "$CMD" = "store" ]; then
   if  [ ! -e "$BOSA_CAL_RIP" ] && [ -e "$BOSA_FILE" ]; then
       cd /etc
       tar cvzf bosa.dat.tar.gz bosa.dat
       if [ $? == 0 ] && [ -e "$BOSA_TAR_FILE" ]; then
          echo 0141 > /proc/rip/new
          if [ -e "$BOSA_CAL_RIP" ]; then
             SIZE=`ls -l /etc/bosa.dat.tar.gz |awk -F ' ' '{print $5}'`
             dd if=$BOSA_TAR_FILE of=$BOSA_CAL_RIP count=1 bs=$SIZE
             RIP_SIZE=`ls -l /proc/rip/0141 |awk -F ' ' '{print $5}'`
             if [ $SIZE == $RIP_SIZE ]; then
                echo "Bosa calibration enable finished"
             else
                echo "The rip size might not correct, please check"
             fi
          fi
       else
          echo "Compression failure"
       fi

       if [ -e "$BOSA_TAR_FILE" ]; then
          rm $BOSA_TAR_FILE
       fi
   else
       if [ ! -e "$BOSA_FILE" ]; then
          echo "Not found calibration file :/etc/bosa.dat"
       else
          echo "Bosa calibration RIP already exit"
       fi
   fi
fi

if [ "$CMD" = "clean" ]; then
   if [ -e "/proc/rip/clean" ]; then
       if  [ -e "$BOSA_CAL_RIP" ]; then
          echo 0141 > /proc/rip/clean
          echo "Bosa calibration RIP is cleaned"
       else
          echo "No Bosa calibration RIP, no need to clean"
       fi
   fi
fi

if [ "$CMD" = "lock" ]; then
   perms=$(ls -l $BOSA_CAL_RIP |cut -d' ' -f 1)
   if [ "$perms" != "$expected_perms" ]; then
      echo 0141 > /proc/rip/lock
      echo "Bosa calibration RIP is locked"
   else
      echo "Bosa calibration RIP already locked, no need to relock"
   fi
fi
