
[[ -f /tmp/acotel/agent.pid ]] && echo "Acotel Agent is Running" && exit;

acotelAgent=$(uci get system.acotel.enabled)

if [ $acotelAgent == "1" ]; then

        chroot /chroot python3 /Acotel_UA/main.py >/chroot/dev/null &
        PID=$!

        mkdir -p /tmp/acotel
        echo "$PID"  > /tmp/acotel/agent.pid
        wait $PID
fi
rm -rf /tmp/acotel/agent.pid
