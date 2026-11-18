
#! chroot/usr/bin/bash


while true; do

PID=/tmp/acotel/agent.pid

acotelAgent=$(uci get system.acotel.enabled)

if [ $acotelAgent == "1" ] && [ ! -f "$PID" ]; then

        mkdir -p /tmp/acotel
        echo "START SCRIPT" >> /chroot/Acotel_UA/Acotel_run.log
        date >> /chroot/Acotel_UA/Acotel_run.log    
        chroot /chroot python3 /Acotel_UA/main.py  > /chroot/dev/null
        echo "END SCRIPT" >> /chroot/Acotel_UA/Acotel_run.log
        date >> /chroot/Acotel_UA/Acotel_run.log
        rm -rf /tmp/acotel/agent.pid

fi

	sleep 300

done
