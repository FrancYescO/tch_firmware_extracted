
[[ -f /tmp/acotel/agent.pid ]] && echo "Acotel Agent is Running" && exit;

acotelAgent=$(uci get system.acotel.enabled)

if [ $acotelAgent == "1" ]; then

        mkdir -p /tmp/acotel
        chroot /chroot python3 /Acotel_UA/main.py > /chroot/dev/null &
        echo $! > /tmp/acotel/agent.pid
        exit
fi
rm -rf /tmp/acotel/agent.pid
