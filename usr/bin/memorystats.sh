#!/bin/sh

. "$IPKG_INSTROOT/lib/functions.sh"

enable_stats="$(uci_get system @system[0] memory_stats 0)"

if [ "${enable_stats}" -eq 0 ]; then
    exit 0
fi

Logging_threshold=80
critical_threshold=90
free_memory=$(($(echo `sed -n '2p;4p;5p' <  /proc/meminfo | sed "s/ \+/ /g" | cut -d' ' -f 2 ` | sed "s/ /+/g")))
total_memory=$(($(echo `head -n1 /proc/meminfo | sed "s/ \+/ /g" | cut -d' ' -f 2 `)))
ram_usage=$(( (200 * (total_memory - free_memory) / total_memory) % 2 + (100 * (total_memory - free_memory) / total_memory) ))
mkdir -p /root/log
LOGFILE="/root/log/memory.log"

log_memory() {
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "$1 Memroy Data at `date +"%d_%m_%Y/%H:%M:%S"`" >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "UP Time is: `uptime` " >> $LOGFILE
    echo "TOTAL Memory is: $((total_memory/1024)) MB" >> $LOGFILE
    echo "FREE Memory is: $((free_memory/1024)) MB" >> $LOGFILE
    echo "Memory Current Usage is: $ram_usage%" >> $LOGFILE
    echo "" >> $LOGFILE
}

dump_stats() {
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "Current Memroy Stats" >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "$(cat /proc/meminfo)" >> $LOGFILE
    echo "" >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "Detailed Process Memory using smaps logic" >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    memory_map
    echo "" >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "Top Memory Consuming Processes Using ps command" >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "$(ps w)" >> $LOGFILE
    echo "" >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "CPU Stats using mpstat " >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "$(mpstat)" >> $LOGFILE
    echo "" >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "VM Stats /proc/vmstat " >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "$(cat /proc/vmstat)" >> $LOGFILE
    echo "" >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "SLAB info /proc/slabinfo " >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "$(cat /proc/slabinfo)" >> $LOGFILE
    echo "" >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "Pagetypeinfo info /proc/pagetypeinfo " >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "$(cat /proc/pagetypeinfo)" >> $LOGFILE
    echo "" >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "Buddyinfo info /proc/buddyinfo " >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "$(cat /proc/buddyinfo)" >> $LOGFILE
    echo "------------------------------------------------------------------" >> $LOGFILE
    echo "" >> $LOGFILE
    echo "###########################END####################################" >> $LOGFILE
    echo "" >> $LOGFILE
}

compress_rotate_log() {
    # Log directory
    log_dir=/root/log

    # Maximum number of archive logs to keep
    MAXNUM=5
    log_file=memory.log

    if [ -f /root/memorystats.tgz ]; then
        tar -xzf /root/memorystats.tgz -C /
        rm /root/memorystats.tgz
    fi
    ## Check if the last log archive exists and delete it.
    if [ -f $log_dir/$log_file.$MAXNUM.gz ]; then
        rm $log_dir/$log_file.$MAXNUM.gz
    fi

    NUM=$(($MAXNUM - 1))

    ## Check the previous log file.
    while [ $NUM -ge 0 ]
    do
        NUM1=$(($NUM + 1))
        if [ -f $log_dir/$log_file.$NUM.gz ]; then
            mv $log_dir/$log_file.$NUM.gz $log_dir/$log_file.$NUM1.gz
        fi

        NUM=$(($NUM - 1))
    done
    # Compress and clear the log file
    if [ -f $log_dir/$log_file ]; then
        cat $log_dir/$log_file | gzip > $log_dir/$log_file.0.gz
        if [ ! -f $log_dir/$log_file.firstdump.gz ]; then
            cp $log_dir/$log_file.0.gz $log_dir/$log_file.firstdump.gz
        fi
        cat /dev/null > $log_dir/$log_file
	tar -zcf /root/memorystats.tgz /root/log/*.gz
	rm -f $log_dir/*.gz
    fi
}

memory_map()
{
    # Remove kernel threads from output
    ps | grep -v "root         0 " > /tmp/ps.tmp

    # Get line count of file
    CNT=`wc -l < /tmp/ps.tmp`
    CNT=$((CNT-1))

    # Remove first line
    tail -n ${CNT} /tmp/ps.tmp > /tmp/ps.out
    rm /tmp/ps.tmp
    while read LINE; do
        pid=${LINE%% *}
        if [ -e "/proc/$pid/smaps" ]; then
            echo "cat /proc/$pid/smaps" > /tmp/smap.dat
            cat /proc/$pid/smaps >> /tmp/smap.dat
            echo "####### -- end smaps data" >> /tmp/smap.dat
            head -n 1 /proc/$pid/status >> $LOGFILE
           /usr/lib/lua/memorystats-smap.lua /tmp/smap.dat
        fi
    done < /tmp/ps.out
    rm -f /tmp/ps.out /tmp/smap.dat

    echo "Total SLAB info: $(grep Slab /proc/meminfo | awk '{print $2 " " $3}') " >> $LOGFILE
    echo "Total kernel modules: $(cat /proc/modules | awk '{tot=tot+$2} END {print tot/1024,"kB"}')" >> $LOGFILE
}

# Condition to dump first memory stats after first boot
if [ ! -f  "$LOGFILE" ]; then
    sleep 60
    log_memory "FIRST BOOT"
    dump_stats
fi

if [ $ram_usage -ge $Logging_threshold ]; then
    if [ $ram_usage -ge $critical_threshold ]; then
        echo "Memory usage crossed CRITICAL threshold limit, Logging mem stats in $LOGFILE" > /dev/console
	#TODO: Any memory optimization operation
    elif [ $ram_usage -ge $Logging_threshold ]; then
        if [ ! -f /tmp/count ]; then
            echo 1 > /tmp/count
	    exit 0
        else
            count=`cat /tmp/count`
            echo $(($count + 1)) > /tmp/count
            if [ $count -lt 5 ]; then
                exit 0
            fi
            rm /tmp/count
        fi
        echo "Memory usage crossed LOGGING threshold limit, Logging mem stats in $LOGFILE " > /dev/console
    fi
    log_memory
    dump_stats
fi

log_size=$(du $LOGFILE | tr -s '\t' ' ' | cut -d' ' -f1)

if [ $log_size -ge 2048 ]; then
    compress_rotate_log
fi
