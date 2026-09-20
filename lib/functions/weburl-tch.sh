#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/functions/network.sh

global_enable=0
urlfilter_enable=
exclude=
blocked_page_redirect=
blockall_mac_list=
acceptall_mac_list=

redirect_mark_value=
accept_mark_value=
mark_mask_value=
ipv6_enable=
keyword_filter_enable=
lan_dev=

cfg_tmpl_file="/etc/weburl_cfg_tmpl"
webredir_proc_file="/proc/net/nf_conntrack_webredir"
webredir_tmp_file="/var/weburl_cfg"

clean_table() {
    local table=$1

    # deleting weburlfilter from forwarding rule
    ${table}-save -t filter | grep forwarding_rule | grep weburlfilter | while read LINE
    do
        $table -t filter -D ${LINE:2}
    done

    ${table}-save -t filter | grep SKIP_HTTP_HELPER | while read LINE
    do
        $table -t filter -D ${LINE:2}
    done

    # deleting weburlfilter chain
    ${table} -F weburlfilter >/dev/null 2>&1
    ${table} -X weburlfilter >/dev/null 2>&1
    ${table} -F weburlfilter_skip >/dev/null  2>&1
    ${table} -X weburlfilter_skip >/dev/null  2>&1
}

append_to_mac_list() {
    local mac=$1
    local action="$(echo $2 | tr [a-z] [A-Z])"

    if [ "$action" = "DROP" ]
    then
        blockall_mac_list="$blockall_mac_list $mac"
    elif [ "$action" = "ACCEPT" ]
    then
        acceptall_mac_list="$acceptall_mac_list $mac"
    fi
}

insert_weburl_rule () {
    local site_match_str=$1
    local dev_str=$2
    local mac_str=$3
    local act=$4
    local chain=$5
    local ipv6_apply=1
    local ipv4_apply=1

    [ -z "$chain" ] && chain="weburlfilter"

    if [ "$act" = "DROP" ]
    then
        act_str="CONNMARK --set-mark 0x$redirect_mark_value/0x$mark_mask_value"
    elif [ "$act" = "ACCEPT" ]
    then
        act_str="CONNMARK --set-mark 0x$accept_mark_value/0x$mark_mask_value"
    elif [ "$act" = "SKIP" ]
    then
	act_str="CONNMARK --set-mark 0x$skip_mark_value/0x$mark_mask_value"
    elif [ "$act" = "RETURN" ]
    then
        act_str="RETURN"
    else
        return
    fi

    if [ -n "$dev_str" ]  # if device string is not empty
    then
        [ -z "$(echo $dev_str | grep : )" ] && ipv6_apply=0
        [ -n "$(echo $dev_str | grep : )" ] && ipv4_apply=0
    fi

    if [ "${site_match_str:0:3}" = "-d " ]   # if it's server string
    then
        [ -z "$(echo $site_match_str | grep : )" ] && ipv6_apply=0
        [ -n "$(echo $site_match_str | grep : )" ] && ipv4_apply=0
    fi

    [ "$ipv4_apply" = "1" ] && iptables -A $chain -m connmark --mark 0x0/0x$mark_mask_value -p tcp $site_match_str $dev_str $mac_str -j $act_str
    [ "$ipv6_enable" = "1" -a "$ipv6_apply" = "1" ] && ip6tables -A $chain -m connmark --mark 0x0/0x$mark_mask_value -p tcp $site_match_str $dev_str $mac_str -j $act_str
}

insert_default_rule () {
    local match_str=$1
    local act=$2

    if [ "$act" = "DROP" ]
    then
        act_str="CONNMARK --set-mark 0x$redirect_mark_value/0x$mark_mask_value"
    elif [ "$act" = "ACCEPT" ]
    then
        act_str="CONNMARK --set-mark 0x$accept_mark_value/0x$mark_mask_value"
    elif [ "$act" = "SKIP" ]
    then
        act_str="CONNMARK --set-mark 0x$skip_mark_value/0x$mark_mask_value"
    else
        return
    fi

    iptables -A weburlfilter -m connmark --mark 0x0/0x$mark_mask_value -p tcp -m weburl --contains_regex ".*" $match_str -j $act_str
    [ "$ipv6_enable" == "1" ] && ip6tables -A weburlfilter -m connmark --mark 0x0/0x$mark_mask_value -p tcp -m weburl --contains_regex ".*" $match_str -j $act_str
}

insert_site_rule() {
    local site_keyword=$1
    local device=$2
    local mac=$3
    local action=$4
    local dev_str=""
    local mac_str=""
    local tmp

    tmp=$(echo $device | tr [A-Z] [a-z])

    if [ "$tmp" != "all" ]
    then
        dev_str="-s $device"
    fi

    if [ -n "$mac" ]
    then
        mac_str="-m mac --mac-source $mac"
    fi

    if [ -n "$site_keyword" ]
    then
        site_keyword="-m weburl --contains $site_keyword"
    fi

    insert_weburl_rule "$site_keyword" "$dev_str" "$mac_str" "$action"
}


handle_urlfilter_inst() {
    local name="$1"
    local device site action

    config_get device "$name" device "All"
    config_get site "$name" site ""
    config_get mac "$name" mac ""
    config_get action "$name" action ""

    site=$(echo $site | tr [A-Z] [a-z])
    site=${site#http://}
    # busybox doesn't support variable replacement as below, so recover old way
    # site=${site/#www./.}
    if [ "${site:0:4}" = "www." ]
    then
        site=${site:3}
    fi

    if [ -z "$site" -a -z "$device" -a -z "$mac" ]
    then
        return
    fi

    if [ -n "$action" ]
    then
        # detail rules action will override global action
        action="$(echo $action | tr [a-z] [A-Z])"
    elif [ "$exclude" = "1" ]
    then
        action="DROP"
    else
        action="ACCEPT"
    fi

    if [ -z "$site" -a -n "$mac" ]
    then
        append_to_mac_list "$mac" "$action"
    else
        insert_site_rule "$site" "$device" "$mac" "$action"
    fi
}

handle_skip_site_mac_list() {
    local mac=$1
    local server=$2
    local act=$3

    [ -n "$mac" ] && mac="-m mac --mac-source $mac"
    [ -n "$server" ] && server="-d $server"

    insert_weburl_rule "$server" "" "$mac" $act  weburlfilter_skip
}


handle_skip_site_dev_list() {
    local device=$1
    local server=$2
    local act=$3

    [ -n "$device" ] && device="-s $device"
    [ -n "$server" ] && server="-d $server"

    insert_weburl_rule "$server" "$device" "" $act  weburlfilter_skip
}

handle_skip_site() {
    local name=$1
    local server=
    local invert=
    local act="SKIP"

    config_get server "$name" server ""
    config_get_bool invert "$name" invert "0"

    [ "$invert" = "1" ] && act="RETURN"

    config_list_foreach $name device handle_skip_site_dev_list "$server" $act
    config_list_foreach $name mac handle_skip_site_mac_list "$server" $act

    [ "$invert" = "1" ] && { [ -n "$server" ] && server="-d $server"; insert_weburl_rule "$server" "" "" SKIP weburlfilter_skip; }
}

insert_tables() {
    local t

    # creating weburlfilter chain
    iptables -N weburlfilter
    iptables -N weburlfilter_skip
    iptables -I weburlfilter -j weburlfilter_skip
    [ "$ipv6_enable" == "1" ] && { ip6tables -N weburlfilter; ip6tables -N weburlfilter_skip; ip6tables -I weburlfilter -j weburlfilter_skip; }

    for t in $lan_dev
    do
        # never block packet from/to modem
        iptables -I INPUT -i $t -p tcp --dport 80 -m state --state NEW -m comment --comment weburl_SKIP_HTTP_HELPER -j CONNMARK --set-mark 0x$skip_mark_value/0x$mark_mask_value

        [ "$ipv6_enable" == "1" ] && ip6tables -I INPUT -i $t -p tcp --dport 80 -m state --state NEW -m comment --comment weburl_SKIP_HTTP_HELPER -j CONNMARK --set-mark 0x$skip_mark_value/0x$mark_mask_value

        # insert the chain into the forwarding_rule
        iptables -I forwarding_rule -i $t -p tcp --dport 80 -m connmark --mark 0x0/0x$mark_mask_value -j weburlfilter
        [ "$ipv6_enable" == "1" ] && ip6tables -I forwarding_rule -i $t -p tcp --dport 80 -m connmark --mark 0x0/0x$mark_mask_value -j weburlfilter
    done

    # insert skip rules
    config_foreach handle_skip_site skip_site

    [ "$urlfilter_enable" == "1" ] || return

    # insert site rules
    config_foreach handle_urlfilter_inst URLfilter

    # The block/accept_all MAC rules should be appended after accept_particular_site rules.
    for m in $blockall_mac_list; do
        insert_default_rule "-m mac --mac-source $m" DROP
    done

    for m in $acceptall_mac_list; do
        insert_default_rule "-m mac --mac-source $m" ACCEPT
    done

    if [ "$exclude" != "1" ]
    then
        insert_default_rule ''  DROP
    else
	insert_default_rule '' ACCEPT
    fi
}

check_helper() {
    local table=$1
    local http_help_exist=$(${table}-save -t raw | grep helper_binds | grep "helper http")
    local enable=$global_enable

    [ "$table" == "ip6tables" -a "$ipv6_enable" != "1" ] && enable=0

    if [ "$enable" == "1" -a -z "$http_help_exist" ]
    then
        ${table} -t raw -A helper_binds -p tcp --dport 80 -j CT --helper http
    fi
}

turn_on_off_http_helper() {
    local act=
    local tmp_str=
    local webredir_url=

    check_helper iptables
    check_helper ip6tables

    if [ "$global_enable" != "1" ]
    then
	# global disabled
	echo > $webredir_proc_file
	return
    fi

    # to generate config file and load it to HTTP helper proc file
    echo "[global]"  > $webredir_tmp_file
    echo "ipv4=1" >> $webredir_tmp_file
    [ "$ipv6_enable" == "1" ] && echo "ipv6=1" >> $webredir_tmp_file
    [ "$keyword_filter_enable" == "1" ] && echo "keyword_filter_enable=1" >> $webredir_tmp_file
    echo "redir_mark_value=$redirect_mark_value"  >> $webredir_tmp_file
    echo "accept_mark_value=$accept_mark_value"  >> $webredir_tmp_file
    echo "skip_mark_value=$skip_mark_value"  >> $webredir_tmp_file
    echo "mark_mask_value=$mark_mask_value"    >> $webredir_tmp_file
    echo >> $webredir_tmp_file

    echo "[webredirect]"  >> $webredir_tmp_file

    blocked_page_redirect=$(echo $blocked_page_redirect | sed 's/\//\\\//g')

    cat $cfg_tmpl_file >> $webredir_tmp_file

    sed -i "s/__WEBREDIR_URL__/$blocked_page_redirect/g"  $webredir_tmp_file

    echo >> $webredir_tmp_file
    if [ "$keyword_filter_enable" == "1" ]
    then
        echo "[httpfilter]" >> $webredir_tmp_file
        config_foreach handle_keyword_inst filterkeyword
    fi

    echo  >> $webredir_tmp_file

    cat $webredir_tmp_file > $webredir_proc_file
}

handle_keyword_inst() {
    name=$1

    config_get keyword "$name" keyword

    [ -n "$keyword" ] && echo "keyword="$keyword >> $webredir_tmp_file
}

handle_each_intf() {
    local intf=$1
    local t=

    network_get_device t $intf
    lan_dev="$lan_dev $t"
}

start() {
    local lan_intf

    clean_table iptables
    clean_table ip6tables

    config_load parental

    config_get_bool urlfilter_enable general enable 1
    config_get_bool keyword_filter_enable general keywordfilter_enable 0


    [ "$urlfilter_enable" == "1" -o "$keyword_filter_enable" == "1" ] && global_enable=1

    if [ "$global_enable" != '1' ]
    then
        TARGET=`cat /proc/cpuinfo | grep "Comcerto" | cut -d':' -f 2 | cut -d' ' -f 2`
        if [ "$TARGET" == "Comcerto" ] ; then
            cmm -c set asym_fastforward disable
            echo 1 > /sys/devices/platform/pfe.0/vwd_bridge_hook_enable
        fi
    else
    	TARGET=`cat /proc/cpuinfo | grep "Comcerto" | cut -d':' -f 2 | cut -d' ' -f 2`
    	if [ "$TARGET" == "Comcerto" ] ; then
            cmm -c set asym_fastforward enable
            echo 0 > /sys/devices/platform/pfe.0/vwd_bridge_hook_enable
    	fi
    fi

    config_get_bool exclude general exclude 0
    config_get_bool ipv6_enable general ipv6_enable 0
    config_list_foreach general lan_intf handle_each_intf
    if [ -z "$lan_dev" ]
    then
        global_enable=0
        echo "no LAN interface given, disabled weburl!"
    fi

    config_get blocked_page_redirect redirect blocked_page_redirect ""
    [ -z "$blocked_page_redirect" ] && blocked_page_redirect="http://$(uci get dhcp.@dnsmasq[0].hostname).$(uci get dhcp.@dnsmasq[0].domain)$(uci get web.parentalblock.target 2>/null)"
    config_get redirect_mark_value redirect redirect_mark_value "4000000"
    config_get accept_mark_value redirect accept_mark_value "2000000"
    config_get skip_mark_value redirect skip_mark_value "6000000"
    config_get mark_mask_value redirect mark_mask_value "6000000"

    turn_on_off_http_helper

    [ "$global_enable" == "1" ] && insert_tables
}

start

exit 0
