#!/bin/sh
# This file is Confidential Information of Cujo LLC.
# Copyright (c) 2019 CUJO LLC. All rights reserved.

# how many 5 second periods to wait for correct date
DATE_TRIES=20
RUN_DIRECTORY=/var/run

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
    pid_file="${RUN_DIRECTORY}/rabid.pid"
    if [ -f "$pid_file" ]; then
        echo "Rabid is already running or exited improperly. In the latter case remove ${pid_file} manually."
        return
    fi
    false
}

start_rabid() {
    pid_file="${RUN_DIRECTORY}/rabid.pid"
    log_directory="${1:-/var/log}"

    "${CUJO_HOME}/bin/setup-chains"
    "${CUJO_HOME}/bin/rabid" 2>&1 | "${CUJO_HOME}/bin/tinylog" -t "${log_directory}/rabid/" &
    jobs -p > "${pid_file}"
    "${CUJO_HOME}/bin/setup-features"
}

stop_rabid() {
    pid_file="${RUN_DIRECTORY}/rabid.pid"
    rabidctlsock_file="${RUN_DIRECTORY}/cujo/rabidctl.sock"
    pid=$(cat "${pid_file}")
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        printf "Waiting for Rabid to shut down..."
        while kill -0 "$pid" 2>/dev/null; do
            printf .
            sleep 1
        done
        echo
    fi
    rm -f "${pid_file}" "${rabidctlsock_file}"
}
