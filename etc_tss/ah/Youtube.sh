#!/bin/sh
AH_NAME=YoutubeTest

pidFile=/tmp/vdo${obj}

doTest() {
	local url=$1 timeTmp minBitRate=2000000000 maxBitRate=0 p= params
	if [ -z ${url} ]; then
		cmclient SETE ${obj}.DiagnosticState Error_NoURL
		rm $pidFile /tmp/youtube_res
		return
	fi
	params="--verbose"
	[ $newOneBitRate = "true" ] && params="$params --onebitrate"
	[ $newMaxTime -gt 0 ] && params="$params --maxtime $newMaxTime"
	[ $newMinTime -gt 0 ] && params="$params --mintime $newMinTime"
	if [ "$newProtocolVersion" = "IPv4" ]; then
		params="$params -4"
	elif [ "$newProtocolVersion" = "IPv6" ]; then
		params="$params -6"
	fi
	[ $newBufferSize -gt 0 ] && params="$params --range $newBufferSize"
	[ $newBitRate -gt 0 ] && params="$params --maxbitrate $newBitRate"
	st=`date -u +%FT%TZ`
	cmclient SETE "${obj}.StartTime" "$st"
	vdo_client $url $params &> /tmp/youtube_res

	while IFS=";" read v0 v1 v2 v3 v4 v5 v6 v7 v8 v9 v10 v11 v12 v13 v14 v15 v16 v17 \
		v18 v19 v20 v21 v22 v23 v24 v25 v26 v27 v28 v29 v30 v31 v32 v33 v34; do
		case "$v0" in
		"YOUTUBEINTERIM"*)
			#echo "${v4}: ${v9} bit/s"
			case "$v4" in
			"VIDEO"|"ALL")
				[ $v9 -gt $maxBitRate ] && maxBitRate=$v9
				[ $v9 -lt $minBitRate ] && minBitRate=$v9
			;;
			esac
		;;
		"YOUTUBE.3"*)
			#echo "${v5} download time"
			#echo "${v6} stalls"
			#echo "${v7} stalls duration"
			#echo "${v8} total stall time"
			if [ "$v2" = "OK" ]; then
				p="${obj}.PlaybackTime=${v5}"
				p="$p	${obj}.Stalls=${v6}"
				p="$p	${obj}.TotalStallDuration=$v8"
				p="$p	${obj}.AverageStallDuration=$v7"
				p="$p	${obj}.DiagnosticsState=Completed"
				minBitRate=$((minBitRate * 8))
				maxBitRate=$((maxBitRate * 8))
				p="$p	${obj}.MinBitRate=${minBitRate}"
				p="$p	${obj}.MaxBitRate=${maxBitRate}"
				videoBitRate=$v20
				audioBitRate=$v29
				totalBitRate=$((videoBitRate + audioBitRate))
				p="$p	${obj}.AdvertisedBitRate=${totalBitRate}"
				p="$p	${obj}.ITag=${v13}"
			else
				p="${obj}.DiagnosticsState=Error_TestFail"
			fi
			minBitRate=2000000000
			maxBitRate=0
			cmclient SETEM "$p"
			cmclient SAVE
		;;
		esac
	done < /tmp/youtube_res

	if [ ${#p} -eq 0 ]; then
		cmclient SETE "${obj}.DiagnosticsState" "Error_TestFail"
		cmclient SAVE
	fi

	rm $pidFile /tmp/youtube_res

}

cancelTest() {
	local pid=""
	if [ -e $pidFile ]; then
		while read pid; do
			kill -9 $pid
		done <$pidFile
		rm -f $pidFile
	fi
}

[ "$user" = "${AH_NAME}${obj}" ] && exit 0

. /etc/ah/helper_functions.sh

case "$op" in
s)
	cancelTest
	if [ "$setDiagnosticsState" = "1" ]; then
		case "$newDiagnosticsState" in
		"Requested")
			doTest $newURL &
			echo "$!" >> "$pidFile"
			;;
		"None")
			;;
		*)
			exit 7
			;;
		esac
	else
		cmclient SETE ${obj}.DiagnosticsState None
	fi
	;;
esac

exit 0
