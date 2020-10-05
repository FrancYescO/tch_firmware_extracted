#!/bin/sh

help_qoe_serialize()
{
	local dstate=${1:-Error}

	#serialize this handler with other QoE diagnostics
	case "$newAlias" in
	QoeTest_*)
		logger -t qoe -p 6 "$obj ($newAlias) starting..."
		if ! help_serialize QoeTest 120; then
			logger -t qoe -p 3 "$obj ($newAlias) timed-out, stale lock?"
			help_serialize_unlock QoeTest
			cmclient -u ${AH_NAME}${obj} SET "${obj}.DiagnosticsState" "$dstate"
			return 1
		fi
		logger -t qoe -p 6 "$obj ($newAlias) started"
		;;
	esac
	return 0
}

help_qoe_save()
{
	#save data for completed QoE diagnostics
	case "$newAlias" in
	QoeTest_*)
		cmclient SAVE
		logger -t qoe -p 6 "$obj ($newAlias) done"
		;;
	esac
}

