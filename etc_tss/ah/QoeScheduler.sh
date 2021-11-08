#!/bin/sh
AH_NAME=QoeScheduler

setWeekTest()
{
	local dayObj=$1 WeekDay dayNumber p=
	local hours minutes seconds id idAction
	WeekDay=`cmclient GETV ${dayObj}.Day`
	StartTime=`cmclient GETV ${dayObj}.StartTime`
	hours=$((StartTime/3600))
	minutes=$(((StartTime-hours*3600)/60))
	seconds=$((StartTime%60))
	case $WeekDay in
		Mon) dayNumber=1 ;;
		Tue) dayNumber=2 ;;
		Wed) dayNumber=3 ;;
		Thu) dayNumber=4 ;;
		Fri) dayNumber=5 ;;
		Sat) dayNumber=6 ;;
		Sun) dayNumber=7 ;;
	esac
	Timer=$(cmclient GETO "Device.X_ADB_Time.Event.[Alias=Scheduler_${dayNumber}]")
	if [ ${#Timer} -eq 0 ]; then
		id=$(cmclient ADD "Device.X_ADB_Time.Event.[Alias=Scheduler_${dayNumber}]");
		Timer="Device.X_ADB_Time.Event.${id}"
		cmclient SET "Device.X_ADB_Time.Event.${id}.Type Periodic"
		idAction=$(cmclient ADD "Device.X_ADB_Time.Event.${id}.Action")
		p="${Timer}.Action.${idAction}.Operation=Set"
		p="$p	${Timer}.Action.${idAction}.Path=Device.X_ADB_QoE.Scheduler.DiagnosticsState"
		p="$p	${Timer}.Action.${idAction}.Value=Requested"
		cmclient SETM "$p"
	fi
	p="${Timer}.OccurrenceHours=${hours}"
	p="$p	${Timer}.OccurrenceMinutes=${minutes}"
	p="$p	${Timer}.OccurrenceWeekDays=${dayNumber}"
	p="$p	${Timer}.Enable=true"
	cmclient SETM "$p"
	cmclient SAVE
}

configureScheduler()
{
	local dayObj tests minFreeMemory cpuThreshold userTraficThreshold maxStored p=""
	cmclient SET Device.X_ADB_QoE.Scheduler.DiagnosticsState None
	dayObj=`cmclient GETO Device.X_ADB_QoE.Scheduler.WeeklySchedule.[Check=true]`
	for dayObj in $dayObj; do
		setWeekTest $dayObj
	done
	minFreeMemory=$(cmclient GETV Device.X_ADB_QoE.Scheduler.MinFreeMemory)
	CPUThreshold=$(cmclient GETV Device.X_ADB_QoE.Scheduler.CPUThreshold)
	userTraficThreshold=$(cmclient GETV Device.X_ADB_QoE.Scheduler.UserTrafficThreshold)
	maxStored=$(cmclient GETV Device.X_ADB_QoE.Scheduler.MaxStored)
	tests=$(cmclient GETV Device.X_ADB_QoE.Scheduler.PathList)
	IFS=","
	for tests in $tests; do
		p="Device.X_ADB_QoE.${tests}.MinFreeMemory=$minFreeMemory"
		p="$p	Device.X_ADB_QoE.${tests}.CPUThreshold=$CPUThreshold"
		p="$p	Device.X_ADB_QoE.${tests}.UserTrafficThreshold=$userTraficThreshold"
		p="$p	Device.X_ADB_QoE.${tests}.MaxStored=$maxStored"
		cmclient SETEM "$p"
	done
	unset IFS
}

case "$op" in
s)
	if [ "$setEnable" = "1" -a "$newEnable" = "true" ]; then
		configureScheduler &
		#setWeekTest $newStartTime $newDay
	fi
	;;
esac
exit 0
