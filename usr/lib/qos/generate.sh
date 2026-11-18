#!/bin/sh
. /lib/functions.sh
. /lib/functions/functions-tch.sh
. /lib/functions/network.sh

QOS_LOCK_FILE="/var/lock/qos-generate-l2classify"
QOS_CHAIN='QoS'
QOS_L2CLASS_CHAIN='QoS_l2classify'
INTERFACES=
LABELS=
L2RULES=

QOS_MARK_MASK_BITS=15
QOS_MARK_SHIFT=11

val_shift_left QOS_MARK_MASK "$QOS_MARK_MASK_BITS" "$QOS_MARK_SHIFT"

[ -x /sbin/modprobe ] && {
  insmod="modprobe"
  rmmod="$insmod -r"
} || {
  insmod="insmod"
  rmmod="rmmod"
}

add_insmod() {
  eval "export isset=\${insmod_$1}"
  case "$isset" in
    1) ;;
    *) {
      [ "$2" ] && append INSMOD "$rmmod $1 >&- 2>&-" "$N"
      append INSMOD "$insmod $* >&- 2>&-" "$N"; export insmod_$1=1
    };;
  esac
}

LIST_BR=

list_bridge_add() {
  local type
  config_get type "$1" type
  [ "$type" == "bridge" ] && append LIST_BR $1
}

config_load network
config_foreach list_bridge_add interface

start_interface() {
  local iface="$1"
  local device="$2"
  local up

  config_get_bool enabled "$iface" enabled 1
  [ 1 -eq "$enabled" ] || return

  if list_contains LIST_BR "$iface"; then
    if ! (ebtables -t nat -L ${QOS_CHAIN} | grep -q ".-logical-out ${device} .*-j ${QOS_CHAIN}_${iface}"); then
      append up "ebtables -t nat -A ${QOS_CHAIN} --logical-out ${device} --mark 0/$QOS_MARK_MASK -j ${QOS_CHAIN}_${iface}" "$N"
    fi
  fi

  [ -z "$up" ] && return

  cat <<EOF
$INSMOD
$up
EOF
  unset INSMOD
}

parse_matching_l2rule() {
  local var="$1"
  local chain="$2"
  local section="$3"
  local options="$4"
  local trafficid="$5"
  local out1 out2 out3 value

  val_shift_left target "${trafficid}" "$QOS_MARK_SHIFT"

  # Remove duplicate options
  options=$(printf '%s\n' $options | sort -u)

  for option in $options; do
    config_get value "$section" "$option"

    case "$option" in
      proto)
        append out1 "-p $value"
      ;;
      srcif)
        append out1 "-i $value"
      ;;
      dstif)
        append out1 "-o $value"
      ;;
      macsrc)
        append out1 "-s $value"
      ;;
      macdst)
        append out1 "-d $value"
      ;;
      ipsrc)
        append out2 "--ip-src $value"
      ;;
      ipdst)
        append out2 "--ip-dst $value"
      ;;
      iptos)
        append out2 "--ip-tos $value"
      ;;
      ipproto)
        append out2 "--ip-proto $value"
      ;;
      ipsrcports)
        append out3 "--ip-sport $value"
      ;;
      ipdstports)
        append out3 "--ip-dport $value"
      ;;
      ip6src)
        append out2 "--ip6-src $value"
      ;;
      ip6dst)
        append out2 "--ip6-dst $value"
      ;;
      ip6tclass)
        append out2 "--ip6-tclass $value"
      ;;
      ip6proto)
        append out2 "--ip6-proto $value"
      ;;
      ip6srcports)
        append out3 "--ip6-sport $value"
      ;;
      ip6dstports)
        append out3 "--ip6-dport $value"
      ;;
      limit)
        append out2 "--limit $value"
      ;;
      limitburst)
        append out2 "--limit-burst $value"
      ;;
      pkttype)
        append out2 "--pkttype-type $value"
      ;;
      vlanid)
        append out2 "--vlan-id $value"
      ;;
      vlanprio)
        append out2 "--vlan-prio $value"
      ;;
      vlanencap)
        append out2 "--vlan-encap $value"
      ;;
    esac
  done

  append "$var" "ebtables -t nat -A $chain $out1 $out2 $out3 -j mark --mark-or $target --mark-target RETURN" "$N"
}

config_cb() {
  option_cb() {
    return 0
  }

  # Section start
  case "$1" in
    l2classify)
      option_cb() {
        append options "$1"
      }
    ;;
  esac
  # Section end

  config_get TYPE "$CONFIG_SECTION" TYPE
  case "$TYPE" in
    interface)
      append INTERFACES "$CONFIG_SECTION"
    ;;
    label)
      config_get trafficid "$CONFIG_SECTION" trafficid
      [ -n "${trafficid}" ] && append LABELS "$CONFIG_SECTION"
    ;;
    l2classify)
      config_set "$CONFIG_SECTION" options "$options"
      append L2RULES "$CONFIG_SECTION"
      unset options
    ;;
  esac
}

add_l2rules() {
  local var="$1"
  local iface="$2"
  local rules="$3"
  local rule options target

  for rule in $rules; do
    config_get target "$rule" target
    list_contains LABELS $target || continue
    config_get trafficid "$target" trafficid
    config_get options "$rule" options

    parse_matching_l2rule "$var" "${QOS_L2CLASS_CHAIN}" "$rule" "$options" "$trafficid"
  done
}

start_qos() {
  add_l2rules l2rules "${iface}" "$L2RULES"

  for iface in $INTERFACES; do
    list_contains LIST_BR $iface || continue
    append l2rules "ebtables -t nat -N ${QOS_CHAIN}_${iface} -P RETURN" "$N"

    config_get_bool enabled "$iface" enabled 1
    [ 1 -eq "$enabled" ] || continue
    network_is_up "$iface" || continue
    network_get_device device "$iface"

    append l2rules "ebtables -t nat -A ${QOS_CHAIN} --logical-out $device -j ${QOS_CHAIN}_${iface}" "$N"
  done

  cat <<EOF
ebtables -t nat -N ${QOS_CHAIN} -P RETURN
ebtables -t nat -N ${QOS_L2CLASS_CHAIN} -P RETURN
ebtables -t nat -A ${QOS_CHAIN} --mark 0/$QOS_MARK_MASK -j ${QOS_L2CLASS_CHAIN}
$INSMOD
$l2rules
ebtables -t nat -I POSTROUTING -j ${QOS_CHAIN}
EOF
  unset INSMOD
}

ebtables_flush() {
  ebtables -t nat -L --Lx |
    # Find rules for the QoS_* chains
    grep ' -[Nj] \(QoS\)' |
    # Exclude inter-QoS_* references
    grep -v ' -A \(QoS\)' |
    # Replace -N with -X and hold, with -F and print
    # Replace -A with -D
    # Print held lines at the end (note leading newline)
    sed -e '/ -N /{s/ -N / -X /;H;s/ -X / -F /}' \
      -e 's/ -A / -D /' \
      -e '${p;g}'
}

start_firewall() {
  ebtables_flush
  start_qos
}

stop_firewall() {
  ebtables_flush
}

[ -e ./qos.conf ] && {
  . ./qos.conf
  config_cb
} || config_load qos

echo "lock ${QOS_LOCK_FILE}"

case "$1" in
  interface)
    start_interface "$2" "$3"
  ;;
  firewall)
    case "$2" in
      stop)
        stop_firewall
      ;;
      start|"")
        start_firewall
      ;;
    esac
  ;;
esac

echo "lock -u ${QOS_LOCK_FILE}"

