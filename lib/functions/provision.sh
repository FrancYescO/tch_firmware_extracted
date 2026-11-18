#!/bin/sh
. /lib/functions.sh

set_pass() {
    local user="${1}"
    local pass="${2}"
    local opt="${3}"

    # user and pass must be specified
    [ -z "${user}" -o -z "${pass}" ] && return

    if [ "${opt}" = "-e" ]; then
    {
        # chpasswd has option `-e` to set encrypted passwords
        echo "${user}:${pass}" | chpasswd -e
    }
    else
    {
       # pass plaintext password to `passwd` for hashing
       echo -e "${pass}\r${pass}\r" | passwd -a sha512 ${user}
    }
    fi
}

get_latest_uid(){
    local uid
    uid=$(awk -F: '$3>=1000 && $3<=2000{print $3}' /etc/passwd | sort -n | tail -n1)
    [[ -n "$uid" ]] && echo "$uid" || echo "1000"
}

create_user() {
    local name="${1}"
    local pass="${2}"
    local uid="${3}"
    local gid

    user_exists "$name" && exit 1

    group_add_next ${name}
    gid=$?

    if [[ -z "$uid" ]]; then
        if awk -F: -v uid="$gid" 'BEGIN{rv=1}$3==uid{rv=0}END{exit rv}' /etc/passwd; then
            uid=$(($(get_latest_uid)+1))
        else
            uid="$gid"
        fi
    fi

    user_add ${name} ${uid} ${gid} ${name} /home/${name} /bin/ash
    set_pass "${name}" "${pass}"

    mkdir -p /home/${name}
    chmod 0755 /home/${name}
    chown ${name}:${name} /home/${name}
}
