#!/bin/sh

old_config_root="$1"
if [ -z "$old_config_root" ]; then
	exit
fi

rule_name=GUI_Access_Only

get_rule_index_by_name() {
	local rule_index=0
	while uci get -c "$1/etc/config" -q "firewall.@rule[$rule_index]" >/dev/null; do
		if uci get -c "$1/etc/config" -q "firewall.@rule[$rule_index].name" | grep -Fqx "$rule_name"; then
			echo "$rule_index"
			return 0
		fi
		let ++rule_index
	done
	return 1
}

if old_index="$(get_rule_index_by_name "$old_config_root")" && new_index="$(get_rule_index_by_name "")"; then
	if enabled="$(uci get -c "$old_config_root/etc/config" -q "firewall.@rule[$old_index].enabled")"; then
		uci -c /etc/config -q set "firewall.@rule[$new_index].enabled=$enabled"
	else
		uci -c /etc/config -q del "firewall.@rule[$new_index].enabled"
	fi
fi
