#!/bin/sh

service_get() {
	local get_path="$1" ongoing
	case "$get_path" in
		*"SpeedTestSchedulingOngoing")
			ongoing=$(cmclient GETO "Device.IP.Diagnostics.Ping.[DiagnosticsState=Requested]")
			while [ ${#ongoing} -eq 0 ]; do
				[ ${#ongoing} -eq 0 ] && ongoing=$(cmclient GETO "Device.IP.Diagnostics.Ping.[DiagnosticsState=Requested]")
				[ ${#ongoing} -eq 0 ] && ongoing=$(cmclient GETO "Device.IP.Diagnostics.DownloadDiagnostics.[DiagnosticsState=Requested]") || break
				[ ${#ongoing} -eq 0 ] && ongoing=$(cmclient GETO "Device.IP.Diagnostics.UploadDiagnostics.[DiagnosticsState=Requested]") || break
				[ ${#ongoing} -eq 0 ] && ongoing=$(cmclient GETO "Device.IP.Diagnostics.X_ADB_IPPing.[DiagnosticsState=Requested]") || break
				[ ${#ongoing} -eq 0 ] && ongoing=$(cmclient GETO "Device.IP.Diagnostics.X_ADB_DownloadDiagnostics.[DiagnosticsState=Requested]") || break
				[ ${#ongoing} -eq 0 ] && ongoing=$(cmclient GETO "Device.IP.Diagnostics.X_ADB_UploadDiagnostics.[DiagnosticsState=Requested]") || break
				break
			done
			[ ${#ongoing} -ne 0 ] && echo "true" || echo "false"
		;;
		*"SchedulingOngoing")
			ongoing=$(cmclient GETV "Device.X_ADB_QoE.Scheduler.DiagnosticsState")
			[ "$ongoing" = "Requested" ] && echo "true" || echo "false"
		;;
	esac
}

if [ "$op" = g ]; then
	for arg # Arg list as separate words
	do
		service_get "$obj.$arg"
	done
fi