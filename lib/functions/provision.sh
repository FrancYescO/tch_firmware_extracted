#!/bin/sh
. /lib/functions.sh

_top_id=500

set_pass() {
    local user="${1}"
    local pass="${2}"
    local opt;

    [ "${pass}" != "${pass/\$1\$/}" ] && opt="-e"
    echo "${user}:${pass}"|chpasswd ${opt:--m}
}

create_user() {
    local name="${1}"
    local pass="${2}"
    local id=${_top_id}

    _top_id=$(( _top_id + 1 ))
    group_add ${name} ${id}
    user_add ${name} ${id} ${id} ${name} /home/${name} /bin/ash
    set_pass "${name}" "${pass}"

    mkdir -p /home/${name}
    chmod 0755 /home/${name}
    chown ${name}:${name} /home/${name}
}
