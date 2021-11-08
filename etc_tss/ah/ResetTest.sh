#!/bin/sh

resetIPPing() {
	local obj=$1 setm=
	setm="$obj.Timeout=5000"
	setm="$setm	$obj.DataBlockSize=64"
	setm="$setm	$obj.NumberOfRepetitions=3"
	setm="$setm	$obj.ProtocolVersion=Any"
	cmclient SETEM "$setm"
}

resetDownloadDiagnostics() {
	local obj=$1
	cmclient SETE "$obj.TimeBasedTestDuration=10"
}

resetUploadDiagnostics() {
	local obj=$1
	cmclient SETE "$obj.TimeBasedTestDuration=10"
}

resetUDPEchoDiagnostics() {
	local obj=$1
	cmclient SETE "$obj.NumberOfRepetitions=3"
}

resetNSLookUpDiagnostics() {
	local obj=$1 setm=
	setm="$obj.Timeout=5000"
	setm="$setm	$obj.NumberOfRepetitions=3"
	cmclient SETEM "$setm"
}

resetTraceRouteDiagnostics() {
	local obj=$1 setm=
	setm="$obj.Timeout=5000"
	setm="$setm	$obj.DataBlockSize=64"
	setm="$setm	$obj.ProtocolVersion=Any"
	setm="$setm	$obj.NumberOfTries=3"
	cmclient SETEM "$setm"
}

resetYoutubeDiagnostics() {
	local obj=$1 setm=
	setm="$obj.ProtocolVersion=Any"
	setm="$setm	$obj.BufferSize=5"
	setm="$setm	$obj.MinTime=0"
	setm="$setm	$obj.BitRate=0"
	setm="$setm	$obj.OneBitRate=false"
	cmclient SETEM "$setm"
}

resetWebDiagnostics() {
	local obj=$1
	cmclient SETE "$obj.ProtocolVersion=Any"
}

resetScheduler() {
	local obj=$1
	setm="$obj.ExecutionNumber=1"
	setm="$setm	$obj.ExecutionInterval=60"
	setm="$setm	$obj.StartupDelayRange=0"
	setm="$setm	$obj.WeeklySchedule.*.StartTime=0"
	setm="$setm	$obj.WeeklySchedule.*.EndTime=86400"
	setm="$setm	$obj.MinFreeMemory=15"
	setm="$setm	$obj.UserTrafficThreshold=25"
	setm="$setm	$obj.CPUThreshold=100"
	setm="$setm	$obj.MaxStored=15"
	setm="$setm	$obj.UploadInterval=1"
	cmclient SETEM "$setm"
}

if [ "$setX_ADB_Reset" = "1" -a "$newX_ADB_Reset" = "true" ]; then
 case $obj in
	*"IPPing"*)
		resetIPPing $obj
		;;
	*"Download"*)
		resetDownloadDiagnostics $obj
		;;
	*"Upload"*)
		resetUploadDiagnostics $obj
		;;
	*"UDPEcho"*)
		resetUDPEchoDiagnostics $obj
		;;
	*"NSLookUp"*)
		resetNSLookUpDiagnostics $obj
		;;
	*"TraceRoute"*)
		resetTraceRouteDiagnostics $obj
		;;
	*"Youtube"*)
		resetYoutubeDiagnostics $obj
		;;
	*"Web"*)
		resetWebDiagnostics $obj
		;;
	*"Scheduler"*)
		resetScheduler $obj
		;;
	esac
fi
