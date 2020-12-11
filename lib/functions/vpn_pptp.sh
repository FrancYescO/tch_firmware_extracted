#!/bin/sh

. $IPKG_INSTROOT/lib/functions/vpn_common_inc.sh

act=$1

pptp_svr_intf_up()
{
	local intf=$1

	[ "$(find_item_by_intf_in_list_file $intf)" == "1" ] && return

	ins_ipt_lan_intf_rules $intf

	local user=$(last | grep $intf | head -n 1 | awk '{print $1}')

	add_conn_to_list_file pptp "$user" $@
}

pptp_svr_intf_down()
{
	local intf=$1

	[ "$(find_item_by_intf_in_list_file $intf)" == "1" ] || return

	rm_ipt_lan_intf_rules $intf
	rm_conn_by_intf_from_list_file $intf
}

pptp_svr_fw_reload()
{
	local intf=$(get_intf_in_item $@)

	ins_ipt_lan_intf_rules $intf
}

shift 1

[ "$act" == "IP_UP" ] && pptp_svr_intf_up $@
[ "$act" == "IP_DOWN" ] && pptp_svr_intf_down $@
[ "$act" == "FW_RELOAD" ] && pptp_svr_fw_reload $@

