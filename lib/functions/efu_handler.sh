#!/bin/sh

#
# EFU handler framework
#
# This script is used in association with the "unlock tag".
# Based on this tag, the configuration of some services will be modified to be open.
#
# Example:
#    If the unlock tag has the root shell access bit set, this script will
#    make sure the root account is enabled for both serial and ssh access.
#
# More info: https://confluence.technicolor.com/pages/viewpage.action?pageId=59803052
#

. /usr/share/libubox/jshn.sh

# Path definition
config_dir="/etc/efu_handler"
state_file_dir="$config_dir/state_before_unlock"

# EFU file
allowed_efu_feature_file="/proc/efu/allowed"

# JSON file keyword definition
js_cmd_type="type"
js_uci_cmd="uci_command"
js_uci_param="uci_parameter"
js_uci_value="uci_value"

log(){
	logger -t "efu-handler" "$*"
}

# Function: store_default_package_state
#    Execute the command that retrieves the state of the current package and store this state into file
# Input:
#    1: configuration file (package name only) in json format
# Output:
#    none
store_default_package_state() {
	local _js_config_file
	local _js_state_file
	local _type
	local _uci_param
	local _uci_value

	# Package config file must be present
	_js_config_file="$config_dir/$1"
	[[ ! -f "$_js_config_file" ]] && return

	# Create directory where to store the default package state file
	mkdir -p "$state_file_dir"

	# Initialise the file where to store parameter state
	_js_state_file="$state_file_dir/$1"
	if [[ -f "$_js_state_file" ]]; then
		# Do not store the default parameter state twice
		return
	else
		# Create an empty JSON file
		echo '{ }' > "$_js_state_file"
	fi

	# Initialise JSON context for both state and config file
	json_init
	local _js_namespace_config="config"
	local _js_namespace_state="state"

	# Load the file where parameter state will be written to
	json_set_namespace "$_js_namespace_state"
	json_load "$(cat "$_js_state_file")"
	json_add_array "$1"

	# Load the json package config file
	json_set_namespace "$_js_namespace_config"
	json_load "$(cat "$_js_config_file")"

	# Select the "store" object and loop through all elements
	json_select "store"
	local _index="1"
	local _js_obj_type
	while json_get_type _js_obj_type "$_index" && [[ "$_js_obj_type" == "object" ]]; do

		json_select "$_index"				# inner array element
		json_get_var _type "$js_cmd_type"	# Select the parameter type
		case "$_type" in

			uci)
				# Get the current state of the selected parameter
				json_get_var _uci_param "$js_uci_param"
				_uci_value="$(uci get -q "$_uci_param")"

				# Store this state into state file
				json_set_namespace "$_js_namespace_state"
				json_add_object
				json_add_string "$js_cmd_type" "$_type"
				json_add_string "$js_uci_param" "$_uci_param"
				if [[ -z "$_uci_value" ]]; then
					# Parameter is not part of UCI tree,
					# so it must be deleted when restoring the configuration
					json_add_string "$js_uci_cmd" "delete"
				else
					json_add_string "$js_uci_cmd" "set"
					json_add_string "$js_uci_value" "$_uci_value"
				fi
				json_close_object
				;;

			*)
				log "unknown object type '$_type'"
				json_cleanup
				exit 1
				;;

		esac
		# Back to config file array element
		json_set_namespace "$_js_namespace_config"
		json_select ".."
		let _index++

	done

	json_set_namespace "$_js_namespace_state"
	json_dump > "$_js_state_file"
	json_cleanup
}

# Function: restore_default_state
#   Restore the state of the services that were changed by the unlock tag
#   based on the file storing the state of the package name given as input
# Input:
#    1: configuration file (package name only) in json format
# Output:
#    none
restore_default_state() {
	local _js_state_file
	local _type
	local _uci_cmd
	local _uci_param
	local _uci_value
	local _index
	local _js_obj_type

	_js_state_file="$state_file_dir/$1"

	[[ ! -f "$_js_state_file" ]] && return

	json_init
	json_load "$(cat "$_js_state_file")"

	json_select "$1" # Select array

	# Loop through all parameter for that package (array elements)
	local _index="1"
	while json_get_type _js_obj_type "$_index" && [[ "$_js_obj_type" == "object" ]]; do

		json_select "$_index"				# inner array element
		json_get_var _type "$js_cmd_type"	# Select the parameter type

		case "$_type" in

			uci)
				json_get_var _uci_cmd "$js_uci_cmd"
				json_get_var _uci_param "$js_uci_param"
				if [[ "$_uci_cmd" == "set" ]]; then
					json_get_var _uci_value "$js_uci_value"
				fi
				uci "$_uci_cmd" "${_uci_param}${_uci_value:+=$_uci_value}"
				log "Lock: Parameter ${_uci_param} restored"
				;;

			*)
				log "unknown object type '$_type'" >/dev/stderr
				json_cleanup
				return 1
				;;

		esac
		json_select ".."
		let _index++

	done

	uci commit
	rm -f "$_js_state_file" # Restore the state only once
	json_cleanup
}


# Function: unlock
#    Retrieve the unlock action from config file and execute it
# Input:
#    $1 : package config file
# Output:
#    none
unlock() {

	local _js_config_file
	local _type
	local _uci_cmd
	local _uci_param
	local _uci_value

	_js_config_file="$config_dir/$1"

	# Package config file must be present
	[[ ! -f "$_js_config_file" ]] && return 1

	# Initialise the JSON context
	json_init
	json_load "$(cat "$_js_config_file")"

	json_select "unlock" || { json_cleanup; return 1; }

	# Loop through all elements
	local _index="1"
	local _js_obj_type
	while json_get_type _js_obj_type "$_index" && [[ "$_js_obj_type" == "object" ]]; do

		json_select "$_index"				# inner array element
		json_get_var _type "$js_cmd_type"	# Select the parameter type

		case "$_type" in

			uci)
				json_get_var _uci_cmd "$js_uci_cmd"
				json_get_var _uci_param "$js_uci_param"
				json_get_var _uci_value "$js_uci_value"
				uci "$_uci_cmd" "${_uci_param}${_uci_value:+=$_uci_value}"
				log "Unlock: Parameter ${_uci_param} updated"
				;;

			*)
				log "unknown object type '$_type'"
				json_cleanup
				exit 1
				;;

		esac
		json_select ".."
		let _index++

	done

	json_cleanup
}

# Function: _adapt_banner
#    Change banner file in case the EFU has any bit set
# Input:
#    $1: 0=remove banner, 1=add banner
# Output:
#    none
adapt_banner(){
	local _banner="/etc/banner"
	local _warning_msg="WARNING: Development board (EFU tag present)"

	[[ ! -f "$_banner" ]] && return
	# Remove any previous message from banner
	awk '/\x1B\[1;30m\x1B\[43m /{p=1}/\x1B\[0m /{p=0;next}!p' "$_banner" >> /tmp/banner
	mv /tmp/banner "$_banner"
	if [[ "$1" == "1" ]]; then # Add a new message to banner
		if grep -q . /proc/efu/allowed; then
			echo -ne "\n\e[1;30m\e[43m" >> "$_banner"
			echo " " | sed -e :a -e 's/^.\{1,49\}$/& /;ta' >> "$_banner"
			echo "$_warning_msg" | sed -e :a -e 's/^.\{1,49\}$/ & /;ta' >> "$_banner"
			echo " " | sed -e :a -e 's/^.\{1,49\}$/ &/;ta' >> "$_banner"
			echo "Features enabled:" | sed -e :a -e 's/^.\{1,49\}$/& /;ta' >> "$_banner"
			echo "$(cat /proc/efu/allowed)" | sed -e 's/^/   /' | sed -e :a -e 's/^.\{1,49\}$/& /;ta' >> "$_banner"
			echo " " | sed -e :a -e 's/^.\{1,49\}$/ &/;ta' >> "$_banner"
			echo -ne "\e[0m " >> "$_banner"
		fi
	fi
}

# Function: efu_handler_is_unlocked
#    Get the state to be applied to the package based on the unlock
#    tag feature list
# Input:
#    $1 : package config file
# Output:
#    none
# Return value:
#    0 if unlock feature is set, 1 otherwise
efu_handler_is_unlocked(){
	local _efu_feature
	local _js_config_file="$config_dir/$1"
	local _is_unlocked=1

	# Exit in case if the efu kernel module isn't present
	[[ -f "$allowed_efu_feature_file" ]] || return 1

	# Load configuration file to get the efu feature
	json_init
	json_load "$(cat "$_js_config_file")"
	json_get_var _efu_feature "efu_feature"

	if [[ -n "$_efu_feature" ]]; then
		if grep -q "$_efu_feature" "$allowed_efu_feature_file"; then
			_is_unlocked=0
		fi
	fi
	json_cleanup
	return "$_is_unlocked"
}

efu_run_execute_handler() {
	local config_file="$config_dir/$1"
	local action="$2"
	local command

	json_init
	json_load_file "$config_file"
	json_get_var command "exec"
	json_cleanup

	if [[ -n "$command" ]]; then
		$command $action
	fi
}

# Function: efu_handler_apply_config
#    Loop through all packages to unlock them or restore their states
#    before the unlock action.
# Input:
#    none
# Output:
#    none
efu_handler_apply_config() {
	local _packages
	local _efu_active=0

	# Exit in case if the efu kernel module isn't present
	if [[ -f "$allowed_efu_feature_file" ]]; then

		# Get the list of files that must be processed
		[[ -d ${config_dir} ]] && _packages="$(find ${config_dir} -maxdepth 1 -type f -exec basename {} \;)"

		local _pkg
		local action
		for _pkg in $_packages; do

			if efu_handler_is_unlocked "$_pkg"; then
				store_default_package_state "$_pkg" && unlock "$_pkg"
				_efu_active=1
				action="unlock"
			else
				restore_default_state "$_pkg"
				action="lock"
			fi
			efu_run_execute_handler "$_pkg" "$action"
		done
		uci commit

	fi
	adapt_banner "$_efu_active"
}

