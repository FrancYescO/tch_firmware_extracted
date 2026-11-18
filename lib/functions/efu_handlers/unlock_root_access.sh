#!/bin/sh

SYSRQ_FILE=/proc/sys/kernel/sysrq

change_sysrq() {
  local flag="${1}"
  if [ -f ${SYSRQ_FILE} ]; then
    echo ${flag} > ${SYSRQ_FILE}
  fi
}

change_sysrq 0
