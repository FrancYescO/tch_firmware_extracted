#!/bin/sh

# Configuration Handler for:	Device.X_ADB_Time.Event.{i}
#
# This handler performs configuration of X_ADB_Time.Event.{i} object.
# It is registered on SET, DEL, ADD on the object:
#       - Device.Ethernet.Interface

#
#	This handler has been certified for SETM usage!
#				,------------------>>>  always check
#		avoid		.__  ,--- ----- ,.  ,.  the original
#		cheap		   \ |---   |   | \/ |  SETM logo!
#		imitations	---' '---   '   '    '  ^^^^^^^^^^^^

AH_NAME=Time
TIMED=/tmp/ec_time

[ "$user" = "${AH_NAME}" ] && exit 0

execute_time_entry() {
	local I=1 obj_act obj_path obj_val
	while [ $I -le $newActionNumberOfEntries ]; do
		obj_act=$(cmclient GETV $obj.Action.$I.Operation)
		obj_path=$(cmclient GETV $obj.Action.$I.Path)
		obj_val=$(cmclient GETV $obj.Action.$I.Value)
		case "$obj_act" in
			Add)
				cmclient -u "${AH_NAME}" ADD "$obj_path"
				;;

			Delete)
				case "$obj_path" in
				Device.X_ADB_Time*)
					cmclient DEL "$obj_path"
				;;
				*)
					cmclient -u "${AH_NAME}" DEL "$obj_path"
				;;
				esac
				;;
			Set)
				set -f
				IFS=","
				set -- $obj_path
				unset IFS
				set +f
				for path; do
					cmclient -u "${AH_NAME}" SET "$path" "$obj_val"
				done
				;;
			Setm)
				set -f
				IFS=","
				set -- $obj_path
				unset IFS
				set +f
				p=""
				for path; do
					[ -z "$p" ] && p="$path=$obj_val" || p="${p}	$path=$obj_val"
				done
				cmclient -u "${AH_NAME}" SETM "$p"
				;;
			Setv)
				obj_val=$(cmclient GETV "$obj_val")
				set -f
				IFS=","
				set -- $obj_path
				unset IFS
				set +f
				for path; do
					cmclient -u "${AH_NAME}" SET "$path" "$obj_val"
				done

				;;
			Save)
				cmclient SAVE
				;;
			Reboot)
				cmclient REBOOT
				;;
		esac
		I=$(($I+1))
	done
}

create_time_entry() {
	local prefix start delta precision
	precision=10
	if [ "$newDeadLine" = "0" ]; then
		if [ -z "$newOccurrenceMonths" ]; then
			newOccurrenceMonths="*"
		fi
		if [ -z "$newOccurrenceMonthsDays" ]; then
			newOccurrenceMonthsDays="*"
		fi
		if [ -z "$newOccurrenceWeekDays" ]; then
			newOccurrenceWeekDays="*"
		fi
		if [ -z "$newOccurrenceHours" ]; then
			newOccurrenceHours="*"
		fi
		if [ -z "$newOccurrenceMinutes" ]; then
			newOccurrenceMinutes="*"
		fi
		prefix="$newOccurrenceMinutes $newOccurrenceHours $newOccurrenceMonthsDays $newOccurrenceMonths $newOccurrenceWeekDays"
		start=`date +%s -D %M-%d-%T $newOccurrenceMonths-$newOccurrenceMonthsDays-$newOccurrenceHours:$newOccurrenceMinutes:00 2>/dev/null`

		if [ "$newOccurrenceMonths" = "*" -a "$newOccurrenceMonthsDays" = "*" -a "$newOccurrenceWeekDays" = "*" -a \
			"$newOccurrenceHours" = "*" -a "$newOccurrenceMinutes" = "*" ]; then
			delta=0
		# only fully qualified crontab entries are checked for expiration at creation time
		elif [ -n "$start" ]; then
			delta=$(($start - $currentTime))
		else
			delta=$(($precision * 2))
		fi
	else
		if [ -z "$currentTime" ]; then
			# periodic timer refresh
			delta=$newDeadLine
		else
			start=`date +%s -D %FT%T%z -d "$newLastModified"`
			delta=$(($start + $newDeadLine - $currentTime))
			[ $delta -lt 1 ] && delta=1
		fi
		prefix="$delta"
	fi

	# check for enforced expired events
	if [ "$newDeadLine" = "0" -a $delta -lt $precision ];  then
		if [ "$newType" = "EnforcedAperiodic" ]; then
			execute_time_entry
			cmclient -u "${AH_NAME}" DEL $obj
			return
		elif [ "$newType" = "Aperiodic" ]; then
			return
		fi
	fi
	if [ "$newDeadLine" = 0 ]; then
		echo "$prefix $obj.Fired" > $TIMED/${obj}_${newAlias}
	else
		echo "$prefix $newType $obj.Fired" > $TIMED/${obj}_${newAlias}
	fi
}

##################
### Start here ###
##################

if [ "$#" -eq 1 ] && [ "$1" = "init" ]; then
	currentTime=`date +%s`
	newLastModified=$(cmclient GETV Device.Time.CurrentLocalTime)
	objs=$(cmclient GETO X_ADB_Time.Event)
	for obj in $objs; do
		newEnable=$(cmclient GETV $obj.Enable)
		[ "$newEnable" = "false" ] && continue
		newType=$(cmclient GETV $obj.Type)
		case "$newType" in
		"Aperiodic"|"EnforcedAperiodic")
			continue
		;;
		*)
			newAlias=$(cmclient GETV $obj.Alias)
			newDeadLine=$(cmclient GETV $obj.DeadLine)
			newOccurrenceMonths=$(cmclient GETV $obj.OccurrenceMonths)
			newOccurrenceWeekDays=$(cmclient GETV $obj.OccurrenceWeekDays)
			newOccurrenceMonthDays=$(cmclient GETV $obj.OccurrenceMonthDays)
			newOccurrenceHours=$(cmclient GETV $obj.OccurrenceHours)
			newOccurrenceMinutes=$(cmclient GETV $obj.OccurrenceMinutes)
			newActionNumberOfEntries=$(cmclient GETV $obj.ActionNumberOfEntries)
			create_time_entry
			cmclient SETE $obj.LastModified $newLastModified
		;;
		esac
	done
	exit 0
fi

if [ "$op" = "d" ]; then
	rm -f $TIMED/${obj}_${newAlias}
	exit
fi

## obj creation/update
# check for obj disabling
if [ "$newEnable" = "false" ]; then
	if [ "$changedEnable" = "1" ]; then
		rm -f $TIMED/${obj}_${newAlias}
	fi
	exit 0
fi

## check if the event has been fired
if [ "$setFired" = "1" -a "$newFired" = "true" ]; then
	lc=$(cmclient GETV Device.Time.CurrentLocalTime)
	cmclient SETE $obj.LastExpired $lc

	execute_time_entry

	# Delete aperiodic events upon expiration
	if [ "$newType" != "Periodic" ]; then
		cmclient -u "${AH_NAME}" DEL $obj
		[ "$newType" = "PersistentAperiodic" ] && cmclient SAVE
		rm -f $TIMED/${obj}_${newAlias}
	elif [ "$newDeadLine" -gt 0 ]; then
		# reschedule periodic timer with deadline
		currentTime=""
		create_time_entry
	fi
	exit 0
fi

## noop check, needed to avoid auto-update loop
[ "$changedEnable" = 0 ] && [ "$changedType" = 0 ] && [ "$setDeadLine" = 0 ] && \
	[ "$changedOccurrenceMinutes" = 0 ] && [ "$changedOccurrenceMinutes" = 0 ] && \
	[ "$changedOccurrenceHours" = 0 ] && [ "$changedOccurrenceWeekDays" = 0 ] && \
	[ "$changedOccurrenceMonths" = 0 ] && [ "$changedOccurrenceMonthDays" = 0 ] && exit 0

## event update/creation
newLastModified=$(cmclient GETV Device.Time.CurrentLocalTime)
cmclient SETE $obj.LastModified $newLastModified
currentTime=`date +%s`
[ "$newType" != "Periodic" ] && cmclient SETE $obj.LastExpired ""
[ "$changedAlias" = "1" ] && rm -f $TIMED/${obj}_${oldAlias}
create_time_entry
exit 0

