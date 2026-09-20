#!/bin/sh

DUMAOS_LDPATH=/dumaos/libs
DUMAOS_CACHE_DIR=$DUMAOS_SYSROOT/dumaos/udata
DUMAOS_CONFIG_FNAME=dumaos
DUMAOS_UCI_CONFIG=/etc/config/$DUMAOS_CONFIG_FNAME
NOUP_STAMPF=$DUMAOS_SYSROOT/dumaos/.noup
CONFIG_PATH=/usr/sbin/ndconfig

dumaos_dependencies_startup(){
    /dumaos/system_cleanup.sh
    # shutdown
    for prog in arpwatch connwatch ctwatch ndhttpd; do
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
     kmods="sch_fq_codel sch_htb sch_prio ifb xt_FLOWOFFLOAD wireguard"
     find /lib/modules -iname "nf_conntrack_netlink.ko" -exec insmod {} \;
     for kmod in $kmods; do
         modprobe "$kmod"
     done
     for prog in ubus ngcompat nginx ndhttpd ctwatch connwatch arpwatch;do
         /etc/init.d/$prog start
     done
}

export_dumaos_ldpath(){
    export LD_LIBRARY_PATH=$DUMAOS_LDPATH:$LD_LIBRARY_PATH
}

export_nginx_ldpath(){
if [ "$MODEL" = "XRE1200" ];then
    export LD_LIBRARY_PATH=$DUMAOS_LDPATH/nginx:$LD_LIBRARY_PATH
else
	export_dumaos_ldpath
fi
}

ensure_necessary_paths(){
    mkdir -p /data/dumaos/rapp-data
    mkdir -p /data/dumaos/themes/cloud
    mkdir -p /data/dumaos/language
    touch /data/dumaos/themes/ready
}

create_themes_symbolic_link() {
  THEMES_SYMBOLIC_LINK=/www/themes
  THEMES_CLOUD_PATH=/dumaos/themes/cloud

  if [ ! -L "$THEMES_SYMBOLIC_LINK" ]; then
    ln -sf "$THEMES_CLOUD_PATH" "$THEMES_SYMBOLIC_LINK"
  fi
}

# XRE1200 factory reset and firmware upgrade/downgrade cleanup
check_datawipe(){
    # remove all userdata and translation files on factory reset
    wipe_data="$("${CONFIG_PATH}" get dumaos)"
    if [ "$wipe_data" != "1" ]; then
      /dumaos/reset.sh
      $CONFIG_PATH set dumaos=1
      $CONFIG_PATH commit
    fi

    # remove translations files on firmware upgrade/downgrade
    fxngfirmver_conf_var='fxngfirmver'
    fxngfirmver="$(version | grep -i ".*/.*" | tr -d " " | tr -d "\n")"
    saved_fxngfirmver="$(config get $fxngfirmver_conf_var)"

    # save firm version in config if different from what's there and remove translation files
    if [ "$saved_fxngfirmver" != "$fxngfirmver" ]; then
            "$CONFIG_PATH" set  "$fxngfirmver_conf_var"="$fxngfirmver"
            "$CONFIG_PATH" commit
            rm -rf /www/language/dumaos/*
    fi
}

copy_dumaos_wrapper() {
    dumaos_wrapper="/dumaos/dumaosWrapper*.zip"
    cp ${dumaos_wrapper} /data/
}

copy_dpi_files() {
    mkdir -p /data/cloud/www/json/ /data/cloud/usr/lib
    clouddir=/data/cloud
    if [ ! -e "${clouddir}/usr/lib/libdpipacketprocessors.so" -o \
        ! -e "${clouddir}/usr/bin/dpiclass" -o \
        ! -e "${clouddir}/www/json/_services_.json" -o \
        ! -e "${clouddir}/www/json/categories.json" -o \
        ! -e "${clouddir}/usr/lib/detectlist.xor" -o \
        ! -e "${clouddir}/www/json/qos_categories.json" ]; then
        cp -rf /dumaos/cloud-ro/* /
    fi
}

stop_dumaos_rapps(){
    # try SIGINT and then SIGTERM if processes still left up after 20 secs
    DUMA_RAPPS=$(ps ww | grep "/dumaos/apps" | grep -v grep | awk '{print $1}')
    for rapp in $DUMA_RAPPS; do                                    
        kill -2 "$rapp" 2>/dev/null 1>&2
    done               
  
    sleep 20 
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

set_up_seal_cache(){
    ng_conf="/etc/netgear.conf"
    cache_var="cache_dir"
    cache_path="$(grep -i "\b${cache_var}" "$ng_conf"| awk '{ printf $3 }')"
    mkdir -p "$cache_path"/"$DUMAOS_CACHE_DIR"
    [ ! -L "$DUMAOS_CACHE_DIR" ] && ln -sf "$cache_path"/"$DUMAOS_CACHE_DIR" "$DUMAOS_CACHE_DIR"
}

# stamp file exists = no firmware upgrade has occured
mark_noup_stamp(){
    touch "$NOUP_STAMPF"
}

set_up_cron(){
    CRONJOB_SCRIPT=$DUMAOS_SYSROOT/dumaos/cron_uci_config_backup.sh
    CRONTAB_FILE=/etc/crontabs/root
    
    # only populate crontab if not already
    if [ -z "$(grep "$(basename $CRONJOB_SCRIPT)" $CRONTAB_FILE 2>/dev/null)" ];then
        echo "* * * * * $CRONJOB_SCRIPT" >> $CRONTAB_FILE
    fi
    killall -9 crond 2>/dev/null; crond
    mark_noup_stamp
}

dumaos_configure(){
    # old setup wizard config variables
    if [ "$VENDOR" != "NETDUMA" ];then 
        "$CONFIG_PATH" set DumaOS_Setup_Done=1
        "$CONFIG_PATH" set DumaOS_Eula=1
    fi
    "$CONFIG_PATH" commit
}

# restore dumaos uci config on RBR750 on first install
retrieve_config_backup(){
    if [ -f $DUMAOS_CACHE_DIR/$DUMAOS_CONFIG_FNAME ] && [ ! -f "$NOUP_STAMPF" ]; then
        cp $DUMAOS_CACHE_DIR/$DUMAOS_CONFIG_FNAME $DUMAOS_UCI_CONFIG
    fi
}

wait_and_start(){
sleep 30
for prog in arpwatch connwatch ctwatch; do
	if [ -z "$(ps ww | grep -i $prog | grep -v grep)" ];then
		/etc/init.d/$prog start
	fi
done
}

