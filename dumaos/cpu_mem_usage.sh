#!/bin/sh
OLD_TOTAL=0
OLD_IDLE=0
while true; do
  #Get CPU stats including the idle time
  CPU_ARGS=$(sed -n 's/^cpu\s//p' /proc/stat)
  #Calculate all CPU time idle/used
  TOTAL=0
  IDLE=0
  USED=0
  for v in 1 2 3 4 5 6 7 8; do
  if [ "$v" = "4" ];then
    VIDLE=$(echo $CPU_ARGS | awk -v CUR="$v" 'NR==1{print $CUR}')
    IDLE=$((IDLE + VIDLE))
  elif [ "$v" = "5" ];then
    IOWAIT=$(echo $CPU_ARGS | awk -v CUR="$v" 'NR==1{print $CUR}')
    IDLE=$((IDLE + IOWAIT))
  else
    VAL=$(echo $CPU_ARGS | awk -v CUR="$v" 'NR==1{print $CUR}')
    USED=$((USED + VAL))
  fi  
  done
  #Calculate CPU usage
  NEW_IDLE=$((IDLE-OLD_IDLE))
  TOTAL=$((IDLE + USED)) 
  NEW_TOTAL=$((TOTAL - OLD_TOTAL))
  NEW_USAGE=$(((1000*(NEW_TOTAL-NEW_IDLE)/NEW_TOTAL+5)/10))
  #NEW_USAGE=$(($NEW_TOTAL - $NEW_IDLE))
  USED_MEM=$(free | awk 'NR==2{ printf("free: %.0f %\n", $3/$2 * 100.0) }')
  #FREE_MEM=$(free | awk 'NR==2{ printf("free: %.0f %\n", $4/$2 * 100.0) }')
  #echo -en "CPU USAGE: $NEW_USAGE % - Used Memory: $USED_MEM - Free Memory: $FREE_MEM\n"
  echo -en "CPU USAGE: $NEW_USAGE % - Used Memory: $USED_MEM\n"
  #Keep a track of current idle & total times for the next iteration
  OLD_TOTAL="$TOTAL"
  OLD_IDLE="$IDLE"
  sleep 1
done
