#!/bin/sh

action="${1}"

SYSRQ_FILE=/proc/sys/kernel/sysrq

change_sysrq() {
  local flag="${1}"
  if [ -f ${SYSRQ_FILE} ]; then
    echo ${flag} > ${SYSRQ_FILE}
  fi
}

if [ "${action}" = "unlock" ]; then
  change_sysrq 1
elif [ "${action}" = "lock" ]; then
  change_sysrq 0
fi
