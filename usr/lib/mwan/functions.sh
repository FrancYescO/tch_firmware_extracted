#!/bin/sh

mwan_set_host_mark() {
	local path=$1
	local nfmark
	[ -f /var/etc/mwan.config ] || return

	nfmark=$(awk "\$1==\"$path\" { print \$2 }" /var/etc/mwan.config)
	[ -n "$nfmark" ] && export SO_MARK=$nfmark
}

mwan_get_dest_ip_policy()
{
	get_policy_cb()
	{
		local dest_ip
		config_get dest_ip $1 dest_ip
		if [ $dest_ip == $3 ]; then
			config_get $2 $1 policy
		fi
	}

	config_foreach get_policy_cb rule "$@"
}

case "$1" in
	set_host_mark)
		mwan_set_host_mark $2
		;;
	get_dest_ip_policy)
		mwan_get_dest_ip_policy $2 $3
		;;
esac
