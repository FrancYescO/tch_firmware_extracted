#!/bin/sh
# Copyright (C) 2016 OpenWrt.org

# Source UCI functions
. $IPKG_INSTROOT/lib/functions.sh

# Contentsharing statusses
CS_STATUS_UNMOUNTED="unmounted"
CS_STATUS_MOUNTED="mounted"
CS_STATUS_FAILURE="failure"
CS_STATUS_IGNORED="ignored"
CS_STATUS_EJECTED="ejected"
CS_STATUS_UNKNOWN="unknown"

# Mountd paths
# Mountd makes a distinction between autofs mountpoints and symbolic
# mountpoints. The autofs mountpoint is where mountd creates the mountpoints
# as one would expect. Its basepath is hardcoded to /tmp/run/mountd. The
# symbolic mountpoint is created on detection of a new filesystem and links to
# the autofs mountpoint. Its basepath is configured as option within the mountd
# uci config.
# Both paths do not have a trailing slash. Where possible autofs mountpoints
# MUST be used because symbolic links are disallowed by samba for security.
CS_MOUNTD_AUTOFS_PATH="/tmp/run/mountd"
CS_MOUNTD_SYMBOLIC_PATH=$( (uci get mountd.mountd.path 2> /dev/null || echo "/mnt/usb/") | sed 's:/*$::' )

# DLNA defaults
DEFAULT_DLNA_DB_DIR="/var/run/minidlna"
DEFAULT_DLNA_LOG_DIR="/var/log"

# _cs_log <msg>
# Send <msg> to the logger with tag 'contentsharing'.
#
_cs_log () {
  local msg="${1}"
  logger -t contentsharing "${msg}"
}

# _cs_valid_args <expected_count> <args>
# Return 0 if arguments are valid, 1 otherwise. Arguments are considered valid
# if the <expected_count> equals <args> count and the arguments are not empty.
#
# e.g.
# _cs_valid_args "1" "${@}"
#
_cs_valid_args () {
  local count="${1}"

  # Drop first parameter <expected_count>.
  shift 1

  local _count="${#}"
  if [ "${count}" -ne "${_count}" ] ; then
    return 1
  fi

  for arg in ${@} ; do
    if [ -z "${arg}" ] ; then
      return 1
    fi
  done

  return 0
}

# cs_has_value <array> <value>
# Return 0 if <value> is in <array>, 1 otherwise.
#
# Remark: <array> must be a white space delimited string.
#
cs_has_value () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_has_value: invalid arguments"
    return
  fi

  local array="${1}"
  local value="${2}"

  for val in ${array} ; do
    if [ "${val}" == "${value}" ] ; then
      return 0
    fi
  done

  return 1
}

# cs_get_device_disk <device> <disk>
# Set <disk> to the disk string of <device>.
#
# e.g.
# local device="sda1"
# local disk=""
# cs_get_device_disk "${device}" "disk"
# echo "${disk}" #sda
#
cs_get_device_disk () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_get_device_disk: invalid arguments"
    return
  fi

  local device="${1}"
  local _disk=$(echo "${device}" | awk 'match($0, /[a-zA-Z]+/) { print substr($0, RSTART, RLENGTH) }')
  eval ${2}="${_disk}"
}

# cs_get_device_partition <device> <partition>
# Set <partition> to the partition number of <device>.
#
# e.g.
# local device="sda1"
# local partition=""
# cs_get_device_partition "${device}" "partition"
# echo "${partition}" #1
#
cs_get_device_partition () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_get_device_partition: invalid arguments"
    return
  fi

  local device="${1}"
  local _partition=$(echo "${device}" | awk 'match($0, /[0-9]+/) { print substr($0, RSTART, RLENGTH) }')
  eval ${2}="${_partition}"
}

# _cs_it_devices <section> <status> <devices>
# Each <section> is the name of a partition (sdaX). If, for this <section>, the
# value of the uci option 'status' is <status>, the value of the uci option
# 'device' is appended to <devices>. If <status> is empty, the value is always
# appended.
#
# ITERATOR CALLBACK
# Within iterators config_get is used and not CS functions. CS functions
# reload the config and could mess up the iteration.
#
_cs_it_devices () {
  local section="${1}"
  local status="${2}"
  local _status=""
  local _device=""
  config_get _status "${section}" status
  config_get _device "${section}" device

  # Is the partition physically present?
  local present=$(cat /proc/partitions | grep -wc ${section})
  if [ "${present}" -eq "0" ] ; then
    return
  fi

  if [ -z "${status}" ] || [ "${status}" == "${_status}" ] ; then
    # Append value of _device to <devices>
    if [ -z "${3}" ] ; then
      eval ${3}="${_device}"
    else
      local _devices="$(eval echo "\${$(echo ${3})}") ${_device}"
      eval ${3}="'${_devices}'"
    fi
  fi
}

# _cs_it_mountpoints <section> <status> <mountpoints>
# Each <section> is the name of a partition (sdaX). If, for this <section>, the
# value of the uci option 'status' is <status>, the value of the uci option
# 'mountpoint' is appended to <mountpoints>. If <status> is empty, the value is
# always appended.
#
# ITERATOR CALLBACK
# Within iterators config_get is used and not CS functions. CS functions
# reload the config and could mess up the iteration.
#
_cs_it_mountpoints () {
  local section="${1}"
  local status="${2}"
  local _status=""
  local _mountpoint=""
  config_get _status "${section}" status
  config_get _mountpoint "${section}" mountpoint

  # Is the partition physically present?
  local present=$(cat /proc/partitions | grep -wc ${section})
  if [ "${present}" -eq "0" ] ; then
    return
  fi

  if [ -z "${status}" ] || [ "${status}" == "${_status}" ] ; then
    # Append value of _mountpoint to <mountpoints>
    if [ -z "${3}" ] ; then
      eval ${3}="${_mountpoint}"
    else
      local _mountpoints="$(eval echo "\${$(echo ${3})}") ${_mountpoint}"
      eval ${3}="'${_mountpoints}'"
    fi
  fi
}

# _cs_it_devices_for_mountpoint <section> <mountpoint> <device>
# Each <section> is the name of a partition (sdaX). If, for this <section>, the
# value of the uci option 'mountpoint' equals <mountpoint>, <device> is set to
# the value of the uci option 'device'.
#
# ITERATOR CALLBACK
# Within iterators config_get is used and not CS functions. CS functions
# reload the config and could mess up the iteration.
#
_cs_it_devices_for_mountpoint () {
  local section="${1}"
  local mountpoint="${2}"
  local _mountpoint=""
  local _device=""
  config_get _mountpoint "${section}" mountpoint
  config_get _device "${section}" device

  if [ "${mountpoint}" == "${_mountpoint}" ] ; then
    # Set value of <device> to _device
    eval ${3}="${_device}"
  fi
}

# _cs_it_serial <section> <device> <serial>
# Each <section> is the serial number of a disk. If, for this <section>, the
# value of the uci option 'disc' is the disk containing <device>, <serial> is
# set to the value of <section>.
#
# Remark: <device> (sda1) may also be a <disk> (sda).
#
# ITERATOR CALLBACK
# Within iterators config_get is used and not CS functions. CS functions
# reload the config and could mess up the iteration.
#
_cs_it_serial () {
  local section="${1}"
  local device="${2}"
  local device_disk=""
  local dev=""
  local dev_disk=""

  config_get dev "${section}" disc

  cs_get_device_disk "${device}" "device_disk"
  cs_get_device_disk "${dev}" "dev_disk"
  if [ "${device_disk}" == "${dev_disk}" ] ; then
    # Set value of <serial> to <section>
    eval ${3}=${1}
  fi
}

# _cs_it_count <section> <disk> <count>
# Each <section> is the name of a partition (sdaX). If, for this <section>, the
# value of the uci option 'device' is a <disk> device, <count> is incremented.
#
# ITERATOR CALLBACK
# Within iterators config_get is used and not CS functions. CS functions
# reload the config and could mess up the iteration.
#
_cs_it_count () {
  local section="${1}"
  local disk=""
  cs_get_device_disk "${2}" "disk"

  local dev=""
  config_get dev ${section} device
  local dev_disk=""
  cs_get_device_disk "${dev}" "dev_disk"

  if [ "${disk}" == "${dev_disk}" ] ; then
    # Increment value of <count>
    eval ${3}=$((${3}+1))
  fi
}

# _cs_it_mount <section> <device> <mount>
# Each <section> is the name of a partition (sdaX). If, for this <section>, the
# value of the uci option 'device' equals <device>, <mount> is set to
# <section>.
#
# ITERATOR CALLBACK
# Within iterators config_get is used and not CS functions. CS functions
# reload the config and could mess up the iteration.
#
_cs_it_mount () {
  local section="${1}"
  local device="${2}"
  local dev=""
  config_get dev "${section}" device

  if [ "${dev}" == "${device}" ] ; then
    # Set value of <mountname> to <section>
    eval ${3}=${1}
  fi
}

# _cs_valid_status <status>
# Return 0 if <status> is valid, 1 otherwise. A status is considered valid if
# it is a member of CS_STATUS_XXX, excluding CS_STATUS_UNKNOWN.
#
_cs_valid_status () {
  local status="${1}"

  # CS_STATUS_UNKNOWN is not a valid status. It is used internally to
  # indicate a missing device.
  if [ "${status}" == "${CS_STATUS_UNMOUNTED}" ] ; then
    return 0
  elif [ "${status}" == "${CS_STATUS_MOUNTED}" ] ; then
    return 0
  elif [ "${status}" == "${CS_STATUS_FAILURE}" ] ; then
    return 0
  elif [ "${status}" == "${CS_STATUS_IGNORED}" ] ; then
    return 0
  elif [ "${status}" == "${CS_STATUS_EJECTED}" ] ; then
    return 0
  else
    return 1
  fi
}

# cs_get_device_proc_count <disk> <count>
# Set <count> to the number of devices, according to /proc, on <disk>.
#
# Remark: <disk> (sda) may also be a <device> (sda1).
#
cs_get_device_proc_count () {
  if [ "${#}" -ne "2" ] ; then
    _cs_log "cs_get_device_proc_count: invalid arguments"
    return
  fi

  local disk=""
  cs_get_device_disk "${1}" "disk"

  # Two possibilities:
  # 1 disk, multiple partitions, multiple filesystems
  # 1 disk, no partitions, 1 filesystem
  local disk_count=$(cat /proc/partitions | awk '{print $4}' | grep -c "^${disk}$")
  local part_count=$(cat /proc/partitions | awk '{print $4}' | grep -c "${disk}[0-9]\{1,\}")

  local _count=0
  if [ "${disk_count}" -eq "1" ] ; then
    if [ "${part_count}" -eq "0" ] ; then
      _count="${disk_count}"
    else
      _count="${part_count}"
    fi
  fi

  # Set value of <count> to _count
  eval ${2}="${_count}"
}

# cs_get_devices <status> <devices>
# Append to <devices> the devices with status <status> as space delimited
# string. Leave <status> empty to append all devices, no matter their status.
#
# e.g.
# local devices=""
# cs_get_devices "" "devices"
# for dev in ${devices} ; do
#   echo "${dev}"
# done
#
cs_get_devices () {
  if [ "${#}" -ne "2" ] ; then
    _cs_log "cs_get_devices: invalid arguments"
    return
  fi

  # Load /var/state/mounts config.
  LOAD_STATE=1
  config_load mounts

  config_foreach _cs_it_devices mount "${1}" "${2}"
}

# cs_get_mountpoints <status> <mountpoints>
# Append to <mountpoints> the mountpoints with status <status> as space
# delimited string. Leave <status> empty to append all mountpoints, no matter
# their status.
#
# e.g.
# local mountpoints=""
# cs_get_mountpoints "" "mountpoints"
# for mnt in ${mountpoints}; do
#   echo "${mnt}"
# done
#
cs_get_mountpoints () {
  if [ "${#}" -ne "2" ] ; then
    _cs_log "cs_get_mountpoints: invalid arguments"
    return
  fi

  # Load /var/state/mounts config.
  LOAD_STATE=1
  config_load mounts

  config_foreach _cs_it_mountpoints mount "${1}" "${2}"
}

# cs_get_device_by_mountpoint <mountpoint> <device>
# Set <device> to the device with mountpoint <mountpoint>.
#
cs_get_device_by_mountpoint () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_get_device_by_mountpoint: invalid arguments"
    return
  fi

  # A mountpoint is expected to have no trailing slashes.
  local mountpoint=$(echo "${1}" | sed 's:/*$::')

  # Load /var/state/mounts config.
  LOAD_STATE=1
  config_load mounts

  config_foreach _cs_it_devices_for_mountpoint mount "${mountpoint}" "${2}"
}

# cs_get_device_serial <device> <serial>
# Set <serial> to the serial number of the disk containing <device>. If <device>
# is not found, <serial> is empty.
#
# Remark: <device> (sda1) may also be a <disk> (sda).
#
cs_get_device_serial () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_get_device_serial: invalid arguments"
    return
  fi

  # Load /var/state/mountd config
  LOAD_STATE=1
  config_load mountd

  config_foreach _cs_it_serial mountd_disc "${1}" "${2}"

  # Reload /var/state/mounts to stay consistent with other functions.
  LOAD_STATE=1
  config_load mounts
}

# cs_get_device_count <disk> <count>
# Set <count> to the number of devices, according to /var/state/mounts, on
# <disk>.
#
# Remark: <disk> (sda) may also be a <device> (sda1).
#
cs_get_device_count () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_get_device_count: invalid arguments"
    return
  fi

  local disk=""
  cs_get_device_disk "${1}" "disk"

  # Load /var/state/mounts config.
  LOAD_STATE=1
  config_load mounts

  config_foreach _cs_it_count mount "${disk}" "${2}"
}

# cs_get_device_mount <device> <mount>
# Set <mount> to the mount of <device>.
#
cs_get_device_mount () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_get_device_mount: invalid arguments"
    return
  fi

  # Load /var/state/mounts config.
  LOAD_STATE=1
  config_load mounts

  config_foreach _cs_it_mount mount "${1}" "${2}"
}

# cs_get_device_device <device> <device2>
# Set <device2> to the device of <device>. If <device> is not found, <device2>
# is empty.
#
cs_get_device_device () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_get_device_device: invalid arguments"
    return
  fi

  # Load /var/state/mounts config.
  LOAD_STATE=1
  config_load mounts

  config_get "${2}" "${1}" device ""
}

# cs_get_device_filesystem <device> <filesystem>
# Set <filesystem> to the filesystem of <device>. If <device> is not found,
# <filesystem> is empty.
#
cs_get_device_filesystem () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_get_device_filesystem: invalid arguments"
    return
  fi

  # Load /var/state/mounts config.
  LOAD_STATE=1
  config_load mounts

  config_get "${2}" "${1}" filesystem ""
}

# cs_get_device_mountpoint <device> <mountpoint>
# Set <mountpoint> to the mountpoint of <device>. If <device> is not found,
# <mountpoint> is empty.
#
cs_get_device_mountpoint () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_get_device_mountpoint: invalid arguments"
    return
  fi

  # Load /var/state/mounts config.
  LOAD_STATE=1
  config_load mounts

  config_get "${2}" "${1}" mountpoint ""
}

# cs_get_device_symbolic_alias <device> <alias>
# Set <alias> to the symbolic alias of <device>. If <device> is not
# found, <alias> is empty.
#
# Used algorithm (taken from mountd source):
# - Extract device letter + partition (if present)
# - Translate device letter to uppercase
# E.g. sda1 -> USB-A1
#
cs_get_device_symbolic_alias () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_get_device_symbolic_alias: invalid arguments"
    return
  fi

  local device="${1}"
  local node=$(echo "${device}" | awk '{ print substr($0, 3) }' | tr [a-z] [A-Z])
  local _alias="USB-${node}"

  # Set value of <alias> to _alias
  eval ${2}="${_alias}"
}

# cs_get_device_symbolic_mountpoint <device> <mountpoint>
# Set <mountpoint> to the symbolic mountpoint of <device>. If <device> is not
# found, <mountpoint> is empty.
#
# Used algorithm (taken from mountd source):
# - Extract device letter + partition (if present)
# - Translate device letter to uppercase
# - Concat result to ${CS_MOUNTD_SYMBOLIC_PATH}/USB-
# E.g. sda1 -> /mnt/usb/USB-A1
#
cs_get_device_symbolic_mountpoint () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_get_device_symbolic_mountpoint: invalid arguments"
    return
  fi

  local device="${1}"
  local alias=""
  cs_get_device_symbolic_alias "${device}" "alias"
  local _mountpoint="${CS_MOUNTD_SYMBOLIC_PATH}/${alias}"

  # Set value of <mountpoint> to _mountpoint
  eval ${2}="${_mountpoint}"
}

# cs_get_device_status <device> <status>
# Set <status> to the status of <device>. If <device> is not found, <status>
# is CS_STATE_UNKNOWN.
#
cs_get_device_status () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_get_device_status: invalid arguments"
    return
  fi

  # Load /var/state/mounts config.
  LOAD_STATE=1
  config_load mounts

  config_get "${2}" "${1}" status "${CS_STATUS_UNKNOWN}"
}

# cs_set_device_status <device> <status>
# Set status of <device> to <status>.
#
cs_set_device_status () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_set_device_status: invalid arguments"
    return
  fi

  local device="${1}"
  local status="${2}"

  if ! _cs_valid_status "${status}" ; then return ; fi

  uci -P /var/state set mounts.${device}.status="${status}"
  uci -P /var/state commit mounts
}

# cs_get_device_info <device> <vendor> <model> <start> <size> <hash>
# Set <vendor>, <model>, <start>, <size>, <hash> to the values retrieved from
# /sys/class/block/ for <device>.
#
cs_get_device_info () {
  if ! _cs_valid_args "6" "${@}" ; then
    _cs_log "cs_get_device_info: invalid arguments"
    return
  fi

  local device="${1}"
  local disk=""
  cs_get_device_disk "${device}" "disk"

  if [ ! -e "/sys/class/block/${disk}" ] ; then
    _cs_log "Unable to get disk info: /sys/class/block/${disk} not found"
    return
  fi

  local _vendor=$(cat /sys/class/block/${disk}/device/vendor | sed 's/[*; /\]//g')
  local _model=$(cat /sys/class/block/${disk}/device/model | sed 's/[*; /\]//g')
  eval ${2}="${_vendor}"
  eval ${3}="${_model}"

  if [ ! -e "/sys/class/block/${device}" ] ; then
    _cs_log "Unable to get device info: /sys/class/block/${device} not found"
    return
  fi

  local serial=""
  cs_get_device_serial "${device}" "serial"

  local _start=$(cat /sys/class/block/${device}/start)
  local _size=$(cat /sys/class/block/${device}/size)
  local _hash=$(echo "${serial}${_start}${_size}" | sha256sum | cut -c1-4)
  eval ${4}="${_start}"
  eval ${5}="${_size}"
  eval ${6}="${_hash}"
}

# cs_is_disk_added <disk>
# Return 0 if <disk> is added, 1 otherwise. A disk is considered added if all
# information about its devices has been added to /var/state/mounts.
#
# Remark: <disk> (sda) may also be a <device> (sda1).
#
cs_is_disk_added () {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_is_disk_added: invalid arguments"
    return
  fi

  local disk=""
  local count=0
  local proc_count=0
  cs_get_device_disk "${1}" "disk"
  cs_get_device_count "${disk}" "count"
  cs_get_device_proc_count "${disk}" "proc_count"

  if [ "${count}" -eq "${proc_count}" ] ; then return 0 ; fi
  return 1
}

# cs_is_disk_removed <disk>
# Returns 0 if <disk> is removed, 1 otherwise. A disk is considered removed if
# all information about its devices has been removed from /var/state/mounts.
#
# Remark: <disk> (sda) may also be a <device> (sda1).
#
cs_is_disk_removed () {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_is_disk_removed: invalid arguments"
    return
  fi

  local disk=""
  local count=0
  cs_get_device_disk "${1}" "disk"
  cs_get_device_count "${disk}" "count"

  if [ "${count}" -eq "0" ] ; then return 0 ; fi
  return 1
}

# cs_is_device_mounted <device>
# Returns 0 if <device> is mounted, 1 otherwise. A device is considered mounted
# if it has an entry inside /proc/mounts.
#
cs_is_device_mounted () {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_is_device_mounted: invalid arguments"
    return
  fi

  local device="${1}"
  local count=$(cat /proc/mounts | grep -wc "${device}")

  if [ "${count}" -eq "0" ] ; then return 1 ; fi
  return 0
}

###############################################################################
# Samba
###############################################################################

# _cs_it_sharename <section> <device> <sharename>
# Each <section> is the name of a share. If, for this <section>, the value of
# the uci option 'device' is <device>, <sharename> is set to the value of
# <section>.
#
# ITERATOR CALLBACK
# Within iterators config_get is used and not CS functions. CS functions
# reload the config and could mess up the iteration.
#
_cs_it_sharename () {
  local section="${1}"
  local device="${2}"
  local _device=""
  config_get _device "${section}" device

  if [ "${device}" == "${_device}" ] ; then
    # Set value of <sharename> to <section>
    eval ${3}=${1}
  fi
}

# _cs_it_shareconfig <section> <device> <shareconfig>
# Each <section> is the name of a share. If, for this <section>, the value of
# the uci option 'device' is <device>, <shareconfig> is set to the value of the
# uci option 'configpath'.
#
# ITERATOR CALLBACK
# Within iterators config_get is used and not CS functions. CS functions reload
# the config and could mess up the iteration.
#
_cs_it_shareconfig () {
  local section="${1}"
  local device="${2}"
  local _device=""
  local _configpath=""
  config_get _device "${section}" device
  config_get _configpath "${section}" configpath

  if [ "${device}" == "${_device}" ] ; then
    # Set value of <shareconfig> to <_configpath>
    eval ${3}="${_configpath}"
  fi
}

# _cs_it_allshares <section> <available>
# purpose is to update the 'available' parameter for all shares :
# set to 'no' if samba filesharing is disabled, set to 'yes' if filesharing is enabled
_cs_it_allshares () {
  local section="$1"
  local available="$2"
  local avail=""
  local device=""
  local sharename="$1"
  local shareconfig=""
  local mountpoint=""
  local filesystem=""

  config_get device "${section}" device
  config_get shareconfig "${section}" configpath
  config_get filesystem "${section}" filesystem
  config_get mountpoint "${section}" path
  config_get avail "${section}" available

  if [ "${section}" != "printers" -a "${avail}" != "${available}" ] ; then
    cs_del_device_sambauci "${sharename}"
    cs_del_device_sambaconfig "${shareconfig}"
    cs_add_device_sambauci "${sharename}" "${shareconfig}" "${device}" "${filesystem}" "${mountpoint}" "${available}"
    cs_add_device_sambaconfig "${sharename}" "${shareconfig}" "${mountpoint}" "${available}"
  fi
}

# cs_get_samba_filesharing <available>
# Variable <available> is set to "yes" or "no", depeding on the fact that samba.filesharing is enabled or not
cs_get_samba_filesharing () {
  local _filesharing=1
  local _available="yes"
  config_load samba
  config_get_bool _filesharing samba filesharing '1'
  [ ${_filesharing} -eq 0 ] && _available="no"
  eval ${1}="${_available}"
}

# cs_update_sharesconfig
# iterate over all shares and update the 'available' flag to yes or no
# cs_update_sharesconfig
#
cs_update_sharesconfig () {
  local available="yes"

  cs_get_samba_filesharing "available"

  # Load /var/state/samba config.
  LOAD_STATE=1
  config_load samba
  config_foreach _cs_it_allshares sambashare ${available}

  cs_update_sambaconfig
}

# cs_update_sambaconfig
# Update the samba daemon configuration. The main configuration file includes a
# secondary configuration file. Calling cs_update_sambaconfig updates the
# secondary configuration file with all samba configurations added/deleted by
# cs_add/del_device_sambaconfig.
#
# Remark: MUST be called after all cs_add/del_device_sambaconfig.
#
cs_update_sambaconfig () {
  local sambaconfigsdir="$(uci -P /var/state get samba.samba.configsdir | sed 's:/*$::')"

  # Rebuild samba configuration
  echo -n "" > ${sambaconfigsdir}.conf
  for conf in ${sambaconfigsdir}/*; do
    # Catch filename patterns expanding to themselves if no match.
    if [ -e "${conf}" ] ; then
      echo "include = ${conf}" >> ${sambaconfigsdir}.conf
    fi
  done
}

# cs_add_device_sambaconfig <sharename> <shareconfig> <mountpoint> <available>
# Create a samba configuration, for share name <sharename> with mountpoint
# <mountpoint>, at filepath <shareconfig>, with available set to <available>
#
# Remark: MUST call cs_update_sambaconfig after all
# cs_add/del_device_sambaconfig.
#
cs_add_device_sambaconfig () {
  if ! _cs_valid_args "4" "${@}" ; then
    _cs_log "cs_add_device_sambaconfig: invalid arguments"
    return
  fi

  local sharename="${1}"
  local shareconfig="${2}"
  local mountpoint="${3}"
  local available="${4}"

  cat << EOF > ${shareconfig}
[${sharename}]
       path = ${mountpoint}
       read only = no
       guest ok = yes
       create mask = 0700
       directory mask = 0700
       available = ${available}
EOF
}

# cs_del_device_sambaconfig <shareconfig>
# Remove the samba configuration at filepath <shareconfig>.
#
# Remark: MUST call cs_update_sambaconfig after all
# cs_add/del_device_sambaconfig.
#
cs_del_device_sambaconfig () {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_del_device_sambaconfig: invalid arguments"
    return
  fi

  local shareconfig="${1}"
  rm ${shareconfig}
}

# cs_add_device_sambauci <sharename> <shareconfig> <device> <filesystem> <mountpoint> <available>
# Add a section type 'sambashare' with section name <sharename> to
# /var/state/samba.
#
cs_add_device_sambauci () {
  if ! _cs_valid_args "6" "${@}" ; then
    _cs_log "cs_add_device_sambauci: invalid arguments"
    return
  fi

  local sharename="${1}"
  local shareconfig="${2}"
  local device="${3}"
  local filesystem="${4}"
  local mountpoint="${5}"
  local available="${6}"

  uci -P /var/state set samba.${sharename}=sambashare
  uci -P /var/state set samba.${sharename}.device="${device}"
  uci -P /var/state set samba.${sharename}.filesystem="${filesystem}"
  uci -P /var/state set samba.${sharename}.configpath="${shareconfig}"
  uci -P /var/state set samba.${sharename}.path="${mountpoint}"
  uci -P /var/state set samba.${sharename}.guest_ok=yes
  uci -P /var/state set samba.${sharename}.create_mask=0700
  uci -P /var/state set samba.${sharename}.dir_mask=0700
  uci -P /var/state set samba.${sharename}.read_only=no
  uci -P /var/state set samba.${sharename}.enabled=1
  uci -P /var/state set samba.${sharename}.available=${available}
  uci -P /var/state commit samba
  config_load samba
}

# cs_del_device_sambauci <sharename>
# Delete the section type 'sambashare' with section name <sharename> from
# /var/state/samba.
#
cs_del_device_sambauci () {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_del_device_sambauci: invalid arguments"
    return
  fi

  local sharename="${1}"

  # Must be after removing the conf! Commiting to the uci will trigger a
  # commit&apply reload of the samba deamon.
  # Common way:
  # uci -P /var/state delete samba.${sharename}
  # uci -P /var/state commit samba
  #
  # When using /var/state, the common way has a nasty quirk. Instead of
  # removing the entries from the config file, it keeps them and adds the
  # same statement with a '-' in front to indicate deletion. Setting the same
  # option adds a new, and duplicate, entry. This causes the file to grow in
  # size over time. A workaround is removing these entries using sed and
  # reloading the config.
  #
  # Search for the EXACT device on word boundary. Prevents sda10 triggering when
  # searching for sda1.
  #
  # Remark: fails if uci value is on multiple lines, which should never be the
  # case.
  #
  sed -i "/\<${sharename}\>/d" /var/state/samba
  config_load samba
}

# cs_get_device_sambaname <device> <sharename>
# Set <sharename> to the share name of <device>. If <device> is not found,
# <sharename> is empty.
#
cs_get_device_sambaname () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_get_device_sambaname: invalid arguments"
    return
  fi

  local device="${1}"

  # Load /var/state/samba config.
  LOAD_STATE=1
  config_load samba

  local cs_sharename=""
  config_foreach _cs_it_sharename sambashare "${device}" "cs_sharename"

  eval ${2}="${cs_sharename}"
}

# cs_get_device_sambaconfig <device> <shareconfig>
# Set <shareconfig> to the share configuration filepath of <device>. If <device>
# is not found, <shareconfig> is empty.
#
cs_get_device_sambaconfig () {
  if ! _cs_valid_args "2" "${@}" ; then
    _cs_log "cs_get_device_sambaconfig: invalid arguments"
    return
  fi

  local device="${1}"

  # Load /var/state/samba config.
  LOAD_STATE=1
  config_load samba

  local cs_shareconfig=""
  config_foreach _cs_it_shareconfig sambashare "${device}" "cs_shareconfig"

  eval ${2}="${cs_shareconfig}"
}

# cs_del_device_sambashare <device>
# Delete the device <device> from the samba configuration and /var/state/samba.
#
cs_del_device_sambashare () {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_del_device_sambashare: invalid arguments"
    return
  fi

  local device="${1}"

  # Load /var/state/samba config.
  LOAD_STATE=1
  config_load samba

  local cs_share_name=""
  local cs_share_config=""
  cs_get_device_sambaname "${device}" "cs_share_name"
  cs_get_device_sambaconfig "${device}" "cs_share_config"

  if [ -z "${cs_share_name}" ] ; then
    _cs_log "samba: unable to find sharename for ${device}"
    return
  fi

  cs_del_device_sambauci "${cs_share_name}"
  cs_del_device_sambaconfig "${cs_share_config}"
  cs_update_sambaconfig
}

# cs_start_samba
# Start the Samba daemon.
#
cs_start_samba () {
  /etc/init.d/samba start
}

# cs_stop_samba
# Stop the Samba daemon.
#
cs_stop_samba () {
  /etc/init.d/samba stop
}

# cs_restart_samba
# Restart the Samba daemon.
#
cs_restart_samba () {
  /etc/init.d/samba restart
}

# cs_reload_samba
# Reload the Samba daemon.
#
cs_reload_samba () {
  /etc/init.d/samba reload
}

# cs_is_samba_running
# Return 0 if Samba daemon is running, 1 otherwise.
#
cs_is_samba_running () {
  if [ ! -r /var/run/smbd.pid ] ; then return 1 ; fi

  local _pid=$(cat /var/run/smbd.pid)
  if [ -z "${_pid}" ] ; then return 1 ; fi

  return 0
}

###############################################################################
# Dlna (minidlna)
###############################################################################

# _cs_is_dlna_db_on_mount
# Return 0 if DLNA database is on a mounted device, 1 otherwise.
#
_cs_is_dlna_db_on_mount () {
  local dir=""
  config_get dir "config" db_dir ""

  if [ -z "${dir}" ] ; then
    return 1
  fi

  local found_once=0
  local mountpoints=""
  cs_get_mountpoints "${CS_STATUS_MOUNTED}" "mountpoints"
  for mnt in ${mountpoints} ; do
    if [ -n "${mnt}" ] && [ "$(echo ${dir} | grep ${mnt})" == "${dir}" ] ; then
      found_once=1
    fi
  done
  if [ ${found_once} -ne "1" ] ; then
    return 1
  fi

  local found_twice=$(find -L ${dir}/files.db | grep -c ${dir})
  if [ "${found_twice}" -ne "1" ] ; then
    return 1
  fi

  return 0
}

# _cs_is_dlna_db_on_gateway
# Return 0 if DLNA database is on the gateway, 1 otherwise.
#
_cs_is_dlna_db_on_gateway () {
  local dir=""
  config_get dir "config" db_dir ""

  if [ -z "${dir}" ] ; then
    return 1
  fi

  if [ "${dir}" != "${DEFAULT_DLNA_DB_DIR}" ] ; then
    return 1
  fi

  return 0
}

# _cs_find_dlna_db <mountpoints> <mountpoint>
# Set <mountpoint> to the mountpoint inside <mountpoints> containing the DLNA
# database. If the DLNA database is not found, <mountpoint> is empty.
#
_cs_find_dlna_db () {
  local mountpoints="${1}"

  for mnt in ${mountpoints} ; do
    local _db=$(find -L ${mnt} -name files.db | head -1)
    if [ -n "${_db}" ] ; then
      eval ${2}="${_mnt}"
      return
    fi
  done

  eval ${2}=""
}

# cs_add_device_dlnamedia <device>
# Add the device <device> to the list of media directories.
#
cs_add_device_dlnamedia() {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_add_device_dlnamedia: invalid arguments"
    return
  fi

  local device="${1}"

  # Load /var/state/minidlna config.
  LOAD_STATE=1
  config_load minidlna

  local mountpoint=""
  local root=""
  cs_get_device_mountpoint "${device}" "mountpoint"
  config_get root "config" start_dir "/"

  local media_dir="${mountpoint}${root}"
  _cs_log "dlna: Add media ${media_dir}"

  # Prevent duplicates.
  uci del_list minidlna.config.media_dir="${media_dir}"
  uci add_list minidlna.config.media_dir="${media_dir}"
  uci commit minidlna
}

# cs_del_device_dlnamedia <device>
# Delete the device <device> from the list of media directories.
#
cs_del_device_dlnamedia() {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_del_device_dlnamedia: invalid arguments"
    return
  fi

  local device="${1}"

  # Load /var/state/minidlna config.
  LOAD_STATE=1
  config_load minidlna

  local mountpoint=""
  local root=""
  cs_get_device_mountpoint "${device}" "mountpoint"
  config_get root "config" start_dir "/"

  # Entry in mounts is already deleted. Reconstruct information.
  if [ -z "${mountpoint}" ] ; then
    mountpoint="${CS_MOUNTD_AUTOFS_PATH}/${device}"
  fi

  local media_dir="${mountpoint}${root}"
  _cs_log "dlna: Remove media ${media_dir}"

  uci del_list minidlna.config.media_dir="${media_dir}"
  uci commit minidlna
}

# cs_update_dlnadirs
# Update DLNA database and log directory.
#
# Remark: MUST be called after all cs_add/del_device_dlnamedia.
#
cs_update_dlnadirs () {
  # Load /var/state/minidlna config.
  LOAD_STATE=1
  config_load minidlna

  local curr_dir=""
  config_get curr_dir "config" db_dir ""

  if _cs_is_dlna_db_on_mount ; then
    _cs_log "dlna: reusing db_dir ${curr_dir}"
    return
  fi

  # Candidates are mounted disks to store the db and log file on.
  local candidates=""
  cs_get_mountpoints "${CS_STATUS_MOUNTED}" "candidates"

  # Reload /var/state/minidlna config.
  LOAD_STATE=1
  config_load minidlna

  local db_dir=""
  local log_dir=""

  if [ -n "$candidates" ] ; then
    _cs_log "dlna: found candidates: ${candidates}"

    # Does one of the disks already has files.db?
    local candidate=""
    _cs_find_dlna_db "${candidates}" "candidate"

    if [ -z "$candidate" ]; then
      _cs_log "dlna: found no db in ${candidates}"
      # No disk has files.db ... pick first disk.
      candidate=$(echo "$candidates" | awk '{print $1}')
    else
     _cs_log "dlna: found db in ${candidate}"
    fi

    _cs_log "dlna: picked candidate ${candidate}"
    db_dir="${candidate}/.dlna"
    log_dir="${candidate}/.dlna"
    mkdir "${db_dir}"
    mkdir "${log_dir}"

    # Keep gateway clean.
    rm -rf ${DEFAULT_DLNA_DB_DIR}
    rm -rf ${DEFAULT_DLNA_LOG_DIR}/minidlna.log
  else
    if _cs_is_dlna_db_on_gateway ; then
      _cs_log "dlna: reusing db_dir ${curr_dir}"
      return
    fi

    _cs_log "dlna: found no candidates ... pick gateway"
    db_dir="${DEFAULT_DLNA_DB_DIR}"
    log_dir="${DEFAULT_DLNA_LOG_DIR}"
    mkdir -p "${db_dir}"
    mkdir -p "${log_dir}"
  fi

  _cs_log "dlna: using db_dir ${db_dir} and log_dir ${log_dir}"
  uci set minidlna.config.db_dir="${db_dir}"
  uci set minidlna.config.log_dir="${log_dir}"
  uci commit minidlna
}

# cs_get_dlna_pid <pid>
# Set <pid> to the PID of the DLNA daemon.
#
cs_get_dlna_pid () {
  local _pid=$(cat /var/run/minidlna_d.pid)
  eval ${1}="${_pid}"
}

# cs_start_dlna
# Start the DLNA daemon.
#
cs_start_dlna () {
  /etc/init.d/minidlna-procd start
}

# cs_stop_dlna
# Stop the DLNA daemon.
#
cs_stop_dlna () {
  /etc/init.d/minidlna-procd stop
}

# cs_restart_dlna
# Restart the DLNA daemon.
#
cs_restart_dlna () {
  /etc/init.d/minidlna-procd restart
}

# cs_reload_dlna
# Reload the DLNA daemon.
#
cs_reload_dlna () {
  /etc/init.d/minidlna-procd reload
}

# cs_is_dlna_running
# Return 0 if DLNA daemon is running, 1 otherwise.
#
cs_is_dlna_running () {
  if [ ! -r /var/run/minidlna_d.pid ] ; then return 1 ; fi

  local _pid=$(cat /var/run/minidlna_d.pid)
  if [ -z "${_pid}" ] ; then return 1 ; fi

  return 0
}

# cs_is_dlna_present
# Return 0 if DLNA daemon is present (not necessary running), 1 otherwise.
#
cs_is_dlna_present () {
  if [ -f /etc/init.d/minidlna-procd ] ; then return 0 ; fi
  return 1
}

###############################################################################
# Dlna (dlnad)
###############################################################################

# cs_del_device_dlnadmedia <device>
# Delete the device <device> from the database of media devices.
#
cs_del_device_dlnadmedia() {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_del_device_dlnadmedia: invalid arguments"
    return
  fi

  local device="${1}"
  local mountpoint=""

  # Remove the symbolic mountpoint. This triggers mud to cleanup any references
  # to it. Most importantly, remove it from the mvfs configuration file
  # (/tmp/.mvfs/mvfs.ini) and trigger mvfs to reread this configuration and
  # release any fds active.
  cs_get_device_symbolic_mountpoint "${device}" "mountpoint"
  if [ -n "${mountpoint}" ] ; then
    _cs_log "cs_del_dlnadmedia: remove symbolic mountpoint ${mountpoint}"
    rm -f "${mountpoint}"

    # Prevent lsof from stalling. Most likely <device> was unsafely unplugged
    # and is already unmounted.
    if [ -e "${CS_MOUNTD_AUTOFS_PATH}/${device}" ] ; then
      # Wait upto 5 seconds for mvfs to release fds.
      for run in 1 2 3 4 5 6; do
        local lines=$(lsof ${CS_MOUNTD_AUTOFS_PATH}/${device} | tail -n +2)
        if [ -z "${lines}" ] ; then break ; fi

        local count=$(echo ${lines} | grep -c "mvfs")
        if [ "${count}" -eq "0" ] ; then break ; fi

        sleep 1
      done
    fi
  fi
}

# cs_get_dlnad_pid <pid>
# Set <pid> to the PID of the DLNAD daemon.
#
cs_get_dlnad_pid () {
  local _pid=$(cat /var/run/dlnad.pid)
  eval ${1}="${_pid}"
}

# cs_start_dlnad
# Start the DLNAD daemon.
#
cs_start_dlnad () {
  /etc/init.d/dlnad start
}

# cs_stop_dlnad
# Stop the DLNAD daemon.
#
cs_stop_dlnad () {
  /etc/init.d/dlnad stop
}

# cs_restart_dlnad
# Restart the DLNAD daemon.
#
cs_restart_dlnad () {
  /etc/init.d/dlnad restart
}

# cs_reload_dlnad
# Reload the DLNAD daemon.
#
cs_reload_dlnad () {
  /etc/init.d/dlnad reload
}

# cs_is_dlnad_running
# Return 0 if DLNAD daemon is running, 1 otherwise.
#
cs_is_dlnad_running () {
  # File is created on start, removed on stop. PID is missing ... to be solved.
  if [ -f /var/run/dlnad.pid ] ; then return 0 ; fi
  return 1
}

# cs_is_dlnad_present
# Return 0 if DLNAD daemon is present (not necessary running), 1 otherwise.
#
cs_is_dlnad_present () {
  if [ -f /etc/init.d/dlnad ] ; then return 0 ; fi
  return 1
}

###############################################################################
# Eject
###############################################################################

# _cs_it_mountd <section>
# Each <section> is a section name of section type 'mountd'. The section name
# 'mountd' contains the main configuration options for mountd, all other
# sections names are disk serials.
#
# ITERATOR CALLBACK
#
_cs_it_mountd () {
  local section="${1}"

  # Main configuration.
  if [ "${section}" == "mountd" ] ; then return ; fi

  # All other section names are considered ignores.
  _cs_log "Removed ignores for disk ${section}"
  uci del mountd."${section}"
  uci commit mountd
}

# cs_ignore_device <device>
# Ignore device <device>. Have mountd ignore the device, triggers an
# ACTION=remove hotplug event.
#
cs_ignore_device () {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_ignore_device: invalid arguments"
    return
  fi

  local device="${1}"

  local serial=""
  local disk=""
  local partition=""
  cs_get_device_serial "${device}" "serial"
  cs_get_device_disk "${device}" "disk"
  cs_get_device_partition "${device}" "partition"

  # Fails if entries in /var/state/mountd are removed before this function is
  # called. These entries are managed by mountd.
  #
  # Possible solution: keep an uci list of ignored devices next to the partX
  # options (ref. cs_(un)ignore_device).
  if [ -z "${serial}" ] ; then
    _cs_log "Failure ignoring ${device}, no disk serial"
    return
  fi

  _cs_log "Ignoring ${device} on disk ${disk} (${serial})"

  # Load /etc/config/mountd
  LOAD_STATE=0
  config_load mountd

  # A mountd partition can be ignored by setting the option partX to 0, with X
  # being the partition number.
  # UCI search path MUST be /etc/config, NOT /var/state.
  # UCI sectiontype = mountd
  # UCI sectionname = serial
  # UCI sectionoption = partX (X = partition number)
  uci set mountd.${serial}=mountd
  uci set mountd.${serial}.part${partition}=0
  uci commit mountd

  # Reload /var/state/mounts to stay consistent with other functions.
  LOAD_STATE=1
  config_load mounts
}

# cs_unignore_device <device>
# Unignore device <device>. Have mountd unignore the device, triggers an
# ACTION=add hotplug event.
#
cs_unignore_device () {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_unignore_device: invalid arguments"
    return
  fi

  local device="${1}"

  local serial=""
  local disk=""
  local partition=""
  cs_get_device_serial "${device}" "serial"
  cs_get_device_disk "${device}" "disk"
  cs_get_device_partition "${device}" "partition"

  # Fails if entries in /var/state/mountd are removed before this function is
  # called. These entries are managed by mountd.
  #
  # Possible solution: keep an uci list of ignored devices next to the partX
  # options (ref. cs_(un)ignore_device).
  if [ -z "${serial}" ] ; then
    _cs_log "Failure unignoring ${device}, no disk serial"
    return
  fi

  _cs_log "Unignoring ${device} on disk ${disk} (${serial})"

  # Load /etc/config/mountd
  LOAD_STATE=0
  config_load mountd

  # A mountd partition can be ignored by setting the option partX to 0, with X
  # being the partition number. Reverting to unignore.
  # UCI search path MUST be /etc/config, NOT /var/state. Thus not using ${UCI}.
  # UCI sectiontype = mountd
  # UCI sectionname = serial
  # UCI sectionoption = partX (X = partition number)
  uci delete mountd.${serial}.part${partition}
  uci commit mountd

  # Reload /var/state/mounts to stay consistent with other functions.
  LOAD_STATE=1
  config_load mounts
}

# cs_unignore_disk <disk>
# Unignore all devices on disk <disk>. have mountd unignore the disk, triggers
# an ACTION=add hotplug event for each unignored device.
#
# Remark: <disk> (sda) may also be a <device> (sda1).
#
cs_unignore_disk () {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_unignore_disk: invalid arguments"
    return
  fi

  local disk=""
  local serial=""
  cs_get_device_disk "${1}" "disk"
  cs_get_device_serial "${disk}" "serial"

  # Fails if entries in /var/state/mountd are removed before this function is
  # called. These entries are managed by mountd.
  #
  # Possible solution: keep an uci list of ignored devices next to the partX
  # options (ref. cs_(un)ignore_device).
  if [ -z "${serial}" ] ; then
    _cs_log "Failure unignoring ${disk}, no disk serial"
    return
  fi

  _cs_log "Unignoring disk ${disk} (${serial})"

  # Load /etc/config/mountd
  LOAD_STATE=0
  config_load mountd

  # A mountd partition can be ignored by setting the option partX to 0, with X
  # being the partition number. Clean ignores by deleting complete section.
  # UCI search path MUST be /etc/config, NOT /var/state. Thus not using ${UCI}.
  # UCI sectiontype = mountd
  # UCI sectionname = serial
  uci delete mountd.${serial}
  uci commit mountd

  # Reload /var/state/mounts to stay consistent with other functions.
  LOAD_STATE=1
  config_load mounts
}

# cs_cleanup_ignores
# Remove ignores inside /etc/config/mountd.
#
cs_cleanup_ignores () {
  LOAD_STATE=0
  config_load mountd
  config_foreach _cs_it_mountd mountd

  # Reload /var/state/mounts to stay consistent with other functions.
  LOAD_STATE=1
  config_load mounts
}

# cs_cleanup_device <device>
# Clean up the device <device>. Clean up samba and DLNA + stop processes having open
# files on <device>.
#
cs_cleanup_device () {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_cleanup_device: invalid arguments"
    return
  fi

  local device="${1}"
  cs_del_device_sambashare "${device}"

  # Actions if minidlna is present
  if cs_is_dlna_present ; then
    cs_del_device_dlnamedia "${device}"
    cs_update_dlnadirs
  fi
  # Actions if dlnad is present
  if cs_is_dlnad_present ; then
    cs_del_device_dlnadmedia "${device}"
  fi

  # Prevent lsof from stalling. Most likely <device> was unsafely unplugged
  # and is already unmounted.
  if [ -e "${CS_MOUNTD_AUTOFS_PATH}/${device}" ] ; then
    # Send SIGTERM to processes having open files on <device>.
    local lines=$(lsof ${CS_MOUNTD_AUTOFS_PATH}/${device} | tail -n +2)
    echo "${lines}" | while IFS= read -r line ; do
      if [ -z "${line}" ] ; then continue ; fi

      local pid=$(echo ${line} | awk '{print $2}')
      /bin/kill -SIGTERM ${pid}
      _cs_log "SIGTERM to ${pid} (${line})"
    done

    # Wait for processes to clean up. After 5 seconds, send SIGTERM to processes
    # not yet cleaned up.
    for run in 1 2 3 4 5 6; do
      local lines=$(lsof ${CS_MOUNTD_AUTOFS_PATH}/${device} | tail -n +2)
      if [ -z "${lines}" ] ; then break ; fi

      if [ "${run}" -eq "6" ] ; then
        echo "${lines}" | while IFS= read -r line ; do
          if [ -z "${line}" ] ; then continue ; fi

          local pid=$(echo ${line} | awk '{print $2}')
          /bin/kill -SIGKILL ${pid}
          _cs_log "SIGKILL to ${pid} (${line})"
        done
      fi

      sleep 1
    done
  fi
}

# cs_eject_device <device>
# Eject the device <device>.
#
cs_eject_device () {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_eject_device: invalid arguments"
    return
  fi

  local device="${1}"
  local disk=""
  local status=""
  cs_get_device_disk "${device}" "disk"
  cs_get_device_status "${device}" "status"
  if [ "${status}" != "${CS_STATUS_MOUNTED}" ] ; then
    cs_set_device_status "${device}" "${CS_STATUS_EJECTED}"
    return
  fi

  cs_set_device_status "${device}" "${CS_STATUS_EJECTED}"
  cs_cleanup_device "${device}"

  _cs_log "umount ${device}"
  /bin/umount "${CS_MOUNTD_AUTOFS_PATH}/${device}"

  local devices=""
  cs_get_devices "${CS_STATUS_MOUNTED}" "devices"

  # Are all devices of the disk ejected (not mounted)?
  local count=$(echo "${devices}" | grep -c "${disk}")
  if [ "${count}" -eq "0" ] ; then
    # USB device format: root_hub-hub_port.hub_port (.hub_port is not limited)
    local sysfs_devices=$(ls /sys/bus/usb/devices/ | grep '^[0-9]\+-[0-9.]\+$')
    for dev in ${sysfs_devices} ; do
      # USB device is an USB hub
      local max_child=$(cat /sys/bus/usb/devices/${dev}/maxchild)
      if [ "${max_child}" -ne "0" ] ; then continue ; fi
      # USB device is ejected disk?
      local found=$(/usr/bin/find /sys/bus/usb/devices/${dev}/ -name "${disk}")
      if [ -n "${found}" ] ; then
        _cs_log "remove ${disk} (usb ${dev})"
        echo "0" > "/sys/bus/usb/devices/${dev}/bConfigurationValue"
        echo "1" > "/sys/bus/usb/devices/${dev}/remove"
      fi
    done
  fi

  # Remark.
  # The proper way of ejecting a device and thus getting it unmounted, would be
  # ignoring the device. Ignoring does not immediately trigger an unmount and
  # ACTION=remove event. It is only triggered once the partition has expired!
  # When ejecting it is not desirable to wait for this expiral.
  #
  # In the above implementation mounted partitions are unmounted without mountd
  # being aware. Once all partitions of the disk are unmounted, the USB device
  # is removed causing it to delisted in sysfs. This triggers an unmount and
  # ACTION=remove by mountd:
  # '/tmp/run/mountd/USB-XXXX has dissappeared ... unmounting'

  # Remark.
  # USB devices have a complex representation. An USB device consists of
  # configurations, interfaces and endpoints. An endpoint carries data in one
  # direction. An interface is a bundle of endpoints, handling one type of a
  # logical connection, e.g. a keyboard. A USB device may have multiple
  # interfaces, e.g. a speaker having two interfaces, an USB keyboard for the
  # buttons and an USB audio stream. A configuration is a bundle of interfaces.
  # Multiple configurations are quite rare.
  #
  # /sys/bus/usb/devices/:
  # USB device naming scheme: root_hub-hub_port.hub_port
  # USB interface naming scheme: root_hub-hub_port.hub_port:config.interface
  #
  # /sys/bus/usb/devices/.../bDeviceClass is not used to determine an USB hub.
  # Most class specifications choose to identify itself at the interface level
  # and as a result set the bDeviceClass as 0x00. To identify an USB device as
  # USB hub /sys/bus/usb/devices/.../maxchild is used.
}

# cs_eject_device_unsafe <device>
# Handle the unsafely ejected device <device>.
#
cs_eject_device_unsafe () {
  if ! _cs_valid_args "1" "${@}" ; then
    _cs_log "cs_eject_device_unsafe: invalid arguments"
    return
  fi

  local device="${1}"
  local disk=""
  local status=""
  cs_get_device_disk "${device}" "disk"
  cs_get_device_status "${device}" "status"
  # Device is safely ejected
  if [ "${status}" == "${CS_STATUS_EJECTED}" ] ; then
    return
  fi

  cs_set_device_status "${device}" "${CS_STATUS_EJECTED}"
  cs_cleanup_device "${device}"

  _cs_log "umount ${device}"
  /bin/umount "${CS_MOUNTD_AUTOFS_PATH}/${device}"
}
