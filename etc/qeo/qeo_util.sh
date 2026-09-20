QEO_CONFIG_FILE=/etc/qeo/qeo.conf
source ${QEO_CONFIG_FILE}

# Add a firewall port
# $1 port to open
firewall_add_port() {
    uci add firewall rule
    uci set firewall.@rule[-1].name=${QEO_FWD}
    uci set firewall.@rule[-1].src=wan
    uci set firewall.@rule[-1].target=ACCEPT
    uci set firewall.@rule[-1].proto=tcp
    uci set firewall.@rule[-1].port=${1}
    uci commit firewall
}

# Remove all qeo forwarder ports
firewall_remove_all_qeo_ports() {
    i=0
    RET=0

    while [ ${RET} -ne 1 ]
    do
        NAME=`uci get firewall.@rule[${i}].name`
        RET=$?
        if [ ${RET} -eq 0 ] && [ ${NAME} == ${QEO_FWD} ]
        then
             # remove port
             uci delete firewall.@rule[${i}]
             uci commit firewall
        else
            let "i++"
        fi
    done
}
