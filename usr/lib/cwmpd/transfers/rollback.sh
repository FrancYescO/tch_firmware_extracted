#!/bin/sh

ACTION=$1
TOTAL_RETRY=$2

if [ ! -e /etc/config/cwmp_transfer ]; then
	touch /etc/config/cwmp_transfer
fi

ROLLBACK_DONE=100

. $(dirname $0)/rollback_common.sh

TMO=$(uci get cwmpd.cwmpd_config.upgrade_rollback_timeout 2>/dev/null)
# make it a number (if not set to 0)
TMO=$(($TMO)) 2>/dev/null
if [ $? -ne 0 ]; then
	TMO=0
fi

ROLLBACK_TO=$(uci get cwmp_transfer.@rollback_info[0].rollback_to 2>/dev/null)

TOTAL_RETRY=$(($TOTAL_RETRY)) 2>/dev/null
if [ $? -ne 0 ]; then
	TOTAL_RETRY=0
fi

rollback_trace "rollback($ACTION, $TOTAL_RETRY) TMO=$TMO ROLLBACK_TO=$ROLLBACK_TO"
if [ "$ACTION" = "init" ]; then
	if [ $TMO -le 0 ]; then
		# rollback not enabled
		rollback_trace "not enabled"
		exit $ROLLBACK_DONE
	fi

	if [ -z $ROLLBACK_TO ]; then
		# no rollback pending
		rollback_trace "no rollback pending, done"
		exit $ROLLBACK_DONE
	fi

	BANK=$(cat /proc/banktable/booted)
	if [ -z $BANK ]; then
		# no active bank info, no rollback possible
		rollback_trace "no active bank ????, done"
		exit $ROLLBACK_DONE
	fi

	if [ "$ROLLBACK_TO" = "$BANK" ]; then
		# a rollback already happened, or no switchover yet
		if [ "$(uci get cwmp_transfer.@rollback_info[0].started)" = "1" ]; then
			rollback_trace "rollback already done"
			uci delete cwmp_transfer.@rollback_info[0]
			uci commit
		else
			rollback_trace "not switched yet, done"
		fi
		exit $ROLLBACK_DONE
	fi
elif [ "$ACTION" = "connect_fail" ]; then
	if [ $TOTAL_RETRY -ge $TMO ]; then
		if [ "$(rollback_wanted)" = "1" ]; then
			#do the rollback now
			rollback_trace "initiate rollback now, done"
			uci set cwmp_transfer.@rollback_info[0].started=1
			uci commit cwmp_transfer
			# also set this in the bank we rollback to
			uci -c /overlay/$ROLLBACK_TO/etc/config set cwmp_transfer.@rollback_info[0].started=1
			uci -c /overlay/$ROLLBACK_TO/etc/config commit cwmp_transfer
			echo $ROLLBACK_TO >/proc/banktable/active
			if [ -f /lib/functions/reboot_reason.sh ]; then
				. /lib/functions/reboot_reason.sh
				set_reboot_reason ROLLBACK
			fi
			reboot
		else
			rollback_trace "no rollback requested for $(rollback_get_initiator), done"
		fi
		exit $ROLLBACK_DONE
	fi
elif [ "$ACTION" = "connect_success" ]; then
	rollback_trace "connected, no rollback needed, done"
	uci delete cwmp_transfer.@rollback_info[0]
	uci commit cwmp_transfer
	exit $ROLLBACK_DONE
elif [ "$ACTION" = "transfer_pending" ]; then
	uci set cwmp_transfer.@rollback_info[0].initiator=CWMPD
	uci commit
elif [ "$ACTION" = "record" ]; then
	rollback_record
	if [ ! -z $2 ]; then
		rollback_set_initiator $2
	else
		uci commit cwmp_transfer
	fi
else
	rollback_trace "unknown action"
fi
