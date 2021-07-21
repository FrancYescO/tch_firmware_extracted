#!/bin/sh
# This file is Confidential Information of Cujo LLC.
# Copyright (c) 2019 CUJO LLC. All rights reserved.

# how many 5 second periods to wait for correct date
DATE_TRIES=20
# shellcheck source=../configs/rabid_generic_sh-env
. "$CUJO_HOME/bin/rabid-sh-env"

if [ -e "$CUJO_HOME"/bin/ipset ]; then
    ipset=$CUJO_HOME/bin/ipset
else
    ipset=ipset
fi

export ipset

have_firewall_iptables=false
if [ -e "$CUJO_HOME"/bin/firewall-iptables ]; then
    have_firewall_iptables=true
fi

if $have_firewall_iptables; then
    iptables=$CUJO_HOME/bin/firewall-iptables
    ip6tables=$CUJO_HOME/bin/firewall-ip6tables

    flush_rabid_firewall() {
        ret=0
        "$CUJO_HOME"/bin/firewall-iptables flush-everything || ret=1
        "$CUJO_HOME"/bin/raptr clear base || ret=1
        return $ret
    }
else
    iptables=iptables
    ip6tables=ip6tables

    flush_rabid_firewall() {
        ret=0
        "$CUJO_HOME"/bin/raptr clear base || ret=1
        return $ret
    }
fi

export iptables
export ip6tables

wait_for_correct_date() {
    tries=$DATE_TRIES

    while [ $tries -gt 0 ] && [ "$(date +%Y)" -lt 2019 ]; do
        tries=$((tries - 1))
        echo "Date: $(date -I), waiting for correct date to start rabid, $tries tries left"
        sleep 5
    done
    if [ $tries -eq 0 ]; then
        echo "Date was not set correctly after $DATE_TRIES tries, aborting"
        exit
    fi
}

insert_module() {
    module="$1"
    module_path="${2:-.}"
    if ! grep -q -w "^$module" /proc/modules; then
        insmod /lib/modules/*/"$module_path/$module.ko"
    fi
}

is_rabid_running() {
    if [ -f "$RABID_PID_FILE" ]; then
        echo "Rabid is already running or exited improperly. In the latter case remove ${RABID_PID_FILE} manually."
        return
    fi
    false
}

set_base_rules_if_needed() {
    CUJO_EXT_NF_RULES=${CUJO_EXT_NF_RULES+x}
    if [ -n "$CUJO_EXT_NF_RULES" ]; then
        "$CUJO_HOME/bin/raptr" set base
    fi
}

# $1 is optional parameter for this function:
# shellcheck disable=SC2120
start_rabid() {
    log_directory="${1:-/var/log}"

    # just in case that there are some leftovers from previous run of rabid
    flush_rabid_firewall

    set_base_rules_if_needed

    "${CUJO_HOME}/bin/rabid" 2>&1 | "${CUJO_HOME}/bin/tinylog" -t "${log_directory}/rabid/" &
    jobs -p > "${RABID_PID_FILE}"
    "${CUJO_HOME}/bin/setup-features"
}

stop_rabid() {
    rabidctlsock_file="${RABID_RUNPATH}/rabidctl.sock"
    pid=$(cat "${RABID_PID_FILE}")
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        printf "Waiting for Rabid to shut down..."
        while kill -0 "$pid" 2>/dev/null; do
            printf .
            sleep 1
        done
        echo
    fi
    rm -f "${RABID_PID_FILE}" "${rabidctlsock_file}"
}
