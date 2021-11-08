#!/bin/sh

parse_results_server()
{
	local filename="$1"
	local arg="$2"
	local name val
	local output

	if [ -e "$filename" ]; then
		while IFS=";" read -r name val; do
			[ "$name" = "$arg" ] && { output="$val"; break; }
		done < "$1"
	fi
	if [ ${#output} -ne 0 ]; then
		echo "$output"
	else
		case "$arg" in
			*"TimeFirstPacketReceived"*|*"TimeLastPacketReceived"*)
				echo "0001-01-01T00:00:00.000000"
			;;
			*)
				echo "0"
			;;
		esac
	fi
}

collect() {
	local file="$1"

	if [ -f "$file" ]; then
		read pidList<$file
		for pid in $pidList; do
			kill -USR1 $pid > /dev/null
		done
		sleep 1
	fi
}

