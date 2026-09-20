#!/bin/sh

dumaos_dependencies_startup(){
    /dumaos/system_cleanup.sh
    # shutdown
    for prog in arpwatch connwatch ctwatch nginx ndhttpd; do
      if [ -n "$(pgrep $prog)" ];then
        /etc/init.d/$prog stop
      fi
    done

    for prog in dpiclass burstwatch;do
      if [ -n "$(pgrep $prog)" ];then
        killall $prog 2>/dev/null 1>&2
      fi
    done

     # startup
     kmods="sch_fq_codel sch_htb sch_prio ifb xt_FLOWOFFLOAD"
     find /lib/modules -iname "nf_conntrack_netlink.ko" -exec insmod {} \;
     for kmod in $kmods; do
         modprobe $kmod
     done
     for prog in ubus ngcompat nginx ndhttpd ctwatch connwatch arpwatch;do
         /etc/init.d/$prog start
     done
}

export_dumaos_ldpath(){
    DUMAOS_LDPATH=/dumaos/libs
    export LD_LIBRARY_PATH=$DUMAOS_LDPATH:$LD_LIBRARY_PATH
}

ensure_necessary_paths(){
    mkdir -p /data/dumaos/rapp-data
    mkdir -p /data/dumaos/themes/cloud
    mkdir -p /data/dumaos/language
    touch /data/dumaos/themes/ready
}


copy_dumaos_wrapper() {
    dumaos_wrapper="dumaosWrapper.zip"
    if [ ! -e /data/${dumaos_wrapper} ];then
        cp /dumaos/${dumaos_wrapper} /data/
    fi
}

copy_dpi_files() {
    mkdir -p /data/dumaos/rapp-data/com.netdumasoftware.devicemanager/ /data/cloud/www/json/ /data/cloud/usr/
    cd /data/dumaos/rapp-data/com.netdumasoftware.devicemanager/ && \
        if [ ! -e "libdpipacketprocessors.so" -o \
            ! -e "dpiclass" -o \
            ! -e "_services_.json" -o \
            ! -e "categories.json" -o \
            ! -e "qos_categories.json" ]; then
            cp -rf /dumaos/cloud-ro/* /
        fi
}

stop_dumaos_rapps(){
    # try SIGINT and then SIGTERM if processes still left up after 48 secs
    DUMA_RAPPS=$(ps ww | grep "/dumaos/apps" | grep -v grep | awk '{print $1}')
    for rapp in $DUMA_RAPPS; do                                    
        kill -2 "$rapp" 2>/dev/null 1>&2
    done               
  
    sleep 10 
    for rapp in $(ps ww | grep "/dumaos/apps" | grep -v grep | awk '{print $1}'); do
        kill -9 "$rapp" 2>/dev/null 1>&2
    done          
}

shift_www_bulk(){
    if [ ! -L /www/nd-js -a ! -L /www/custom-elements ]; then
        rm -rf /3rdParty/netduma/ && \
        mkdir -p /3rdParty/netduma && \
        mv /www/custom-elements/ /3rdParty/netduma/ && \
        mv /www/nd-js /3rdParty/netduma && \
        ln -s /3rdParty/netduma/custom-elements /www/ && \
        ln -s /3rdParty/netduma/nd-js /www
    fi
}
