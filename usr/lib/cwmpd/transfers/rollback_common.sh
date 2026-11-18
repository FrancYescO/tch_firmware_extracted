# common rollback function

rollback_trace() {
	logger -t cwmpd "$1"
}

rollback_config_value()
{
	local option=$1
	local default=$2
	
	local v=$(uci get cwmpd.cwmpd_config.rollback_$option 2>/dev/null)
	if [ -z $v ]; then
		echo $default
	else
		echo $v
	fi
}

rollback_get_initiator()
{
	local v=$(uci get cwmp_transfer.@rollback_info[0].initiator 2>/dev/null)
	if [ -z $v ]; then
		v="Unknown"
	fi
	echo $v
}

rollback_wanted()
{
	local initiator=$(rollback_get_initiator)
	
	if [ "$initiator" = "CWMPD" ]; then
		rollback_config_value cwmpd 1
	elif [ "$initiator" = "DELAYED" ]; then
		rollback_config_value delayed 1
	elif [ "$initiator" = "GUI" ]; then
		rollback_config_value gui 0
	else
		rollback_config_value unknown 0
	fi
}

ensure_rollback_info()
{
	local CFG=$1/etc/config
	local VAR
	if [ ! -z $1 ]; then
		VAR="-P /var/.uci-$(basename $1)"
	fi
	touch $CFG/cwmp_transfer
	uci -c $CFG $VAR get cwmp_transfer.@rollback_info[0] >/dev/null 2>/dev/null
	if [ $? -ne 0 ]; then
		uci -c $CFG $VAR add cwmp_transfer rollback_info
	fi
}

rollback_record()
{
	ensure_rollback_info
	if [ -f /proc/banktable/booted ]; then
		rollback_trace "setting rollback_to to $(cat /proc/banktable/booted)"
		uci set cwmp_transfer.@rollback_info[0].rollback_to=$(cat /proc/banktable/booted)
		uci set cwmp_transfer.@rollback_info[0].started=0
	fi
}

rollback_set_initiator() { # $1=initiator
	# if the rollback_info does not exist there is no need for the initiator to be set
	# so only commit if the set succeeds.
	uci set cwmp_transfer.@rollback_info[0].initiator=$1 2>/dev/null
	if [ $? -eq 0 ]; then
		uci commit cwmp_transfer
	fi
}
