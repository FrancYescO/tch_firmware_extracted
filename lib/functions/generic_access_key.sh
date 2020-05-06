#!/bin/sh
# Copyright (C) 2015 Technicolor Delivery Technologies, SAS

GAK_KEY_SIZE=8

local ripentry="/proc/rip/0124"

# Helper function to translate a 'gak_id' to a 'from-to' pair
#   Params: gak_id, integer that specifies which part of RIP GAK to get; typically 1 to 8
#   Returns: the from-to pair that indicates where to find the actual key or empty result
_gak_id_to_gak_part() {
	local gak_id=$1
	local result

	if [ ! -z "$gak_id" ]; then
		let gak_id=$gak_id

		# Is argument an integer number?
		if [ "$gak_id" -eq "$gak_id" ]; then

			# and greater than 0?
			if [ "$gak_id" -gt 0 ]; then
				let from="1+($gak_id-1)*$GAK_KEY_SIZE"
				let to="$from+$GAK_KEY_SIZE-1"
				local full=$(cat "$ripentry")
				if [[ "$to" -gt "$from" && "$from" -le "${#full}" ]]; then
					result="$from-$to"
				fi
			else
				logger "Error: gak_id not a positive number"
			fi
		else
			logger "Error: gak_id is not an integer"
		fi
	else
		logger "Error: gak_id is empty"
	fi
	echo $result
}

# Get a generic access key from RIP
#   Params: gak_id, integer that specifies which part of RIP GAK to get; typically 1 to 10
#   Returns: the key or empty result
get_key() {
	local gak_id=$1
	local result

	if [[ -f "$ripentry" ]]; then
		local part=$(_gak_id_to_gak_part $gak_id)
		if [[ $part ]]; then
			result=$(cut -c "$part" "$ripentry")
		fi
	elif [[ "$gak_id" == "1" && -f /proc/rip/0107 && -x /usr/bin/get_access_key ]]; then
		# No 0124 rip entry; fall back to legacy access key when GAK[1] is requested
		result=$(/usr/bin/get_access_key)
	else
		logger "Error: could not get GAK for gak_id=$gak_id"
	fi
	echo $result
}
