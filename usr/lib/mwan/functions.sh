#!/bin/sh

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
	get_dest_ip_policy)
		mwan_get_dest_ip_policy $2 $3
		;;
esac
