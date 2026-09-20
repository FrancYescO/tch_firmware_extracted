#!/bin/sh
#set -x
. /lib/functions.sh
. /lib/functions/functions-tch.sh
. /lib/functions/network.sh

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

parse_rule(){
   local rule="$1"
   local device="$2"
   local options="$3"
   local updown="$4"
   local iptrule1="iptables -t mangle"
   local iptrule2="iptables -t mangle"
   local validforward=0
   local validoutput=0

   for option in $options ; do
      config_get value "$rule" "$option"

      case "$option" in
          routed)
              if [ "$value" -eq 1 ] ; then
                   if [ "$updown" = "up" ] ; then 
                       append iptrule1 "-A FORWARD"
                       validforward=1
                   else
                       append iptrule1 "-D FORWARD"
                       validforward=1
                   fi
              fi
          ;;
          host)
              if [ "$value" -eq 1 ] ; then
                  if [ "$updown" = "up" ] ; then
                      append iptrule2 "-A OUTPUT"
                      validoutput=1
                  else
                      append iptrule2 "-D OUTPUT"
                      validoutput=1
                  fi
              fi
          ;;
          TOS)
              add_insmod ipt_TOS
              config_get TOS "$rule" 'TOS'
              suffix="-j TOS --set-tos "${TOS:-"Normal-Service"}
          ;;
          DSCP)
              add_insmod ipt_DSCP
              config_get DSCP "$rule" 'DSCP'
              [ -z "${DSCP%%[EBCA]*}" ] && set_value="--set-dscp-class $DSCP" \
              || set_value="--set-dscp $DSCP"
              suffix="-j DSCP $set_value"
          ;;
     esac
  done
  if [ "$validforward" -eq 1 ] ; then
     append iptrule1 " -o $device"
     append iptrule1 "$suffix"
     if ! (iptables -t mangle -S | grep "FORWARD -o $device $suffix"); then
         $INSMOD
         $iptrule1     
         unset INSMOD
        fi
  fi

  if [ "$validoutput" -eq 1 ] ; then
     append iptrule2 " -o $device"
     append iptrule2 "$suffix"
     if ! (iptables -t mangle -S | grep "OUTPUT -o $device $suffix"); then
         $INSMOD
         $iptrule2
         unset INSMOD
     fi
  fi
}


start_interface(){
    for  rule in $rules; do
        config_get interface $rule interface
        [ "$interface" = "$1" ] || continue
        config_get options $rule options
        parse_rule $rule $2 "$options" "up"
    done
}

stop_interface(){
    for  rule in $rules; do
        config_get interface $rule interface
        [ "$interface" = "$1" ] || continue
        config_get options $rule options
        for network in $networks; do 
            parse_rule $rule $network "$options" "down"
        done
    done
}

config_cb() {
    option_cb() {
        return 0
    }

    # Section start
    case "$1" in
        remarking)
            option_cb() {
                append options "$1"
            }
        ;;
    esac
    # Section end

    config_get TYPE "$CONFIG_SECTION" TYPE
    case "$TYPE" in
        remarking)
          config_set "$CONFIG_SECTION" options "$options"
          append "rules" "$CONFIG_SECTION"
          unset options
        ;;
    esac
}

config_load network
config_get networks $2 ifname 


[ -e ./qos.conf ] && {
   . ./qos.conf
   config_cb
} || config_load qos

case "$1" in
	up)
	start_interface "$2" "$3"
        ;;
        down)
	stop_interface "$2"
        ;;
esac
