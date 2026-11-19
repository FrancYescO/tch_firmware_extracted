#!/bin/sh

# script parameters:
# $1 : name of the directory that contains the old_config from
#      where the config is copied from.
#      This may be a symbolic link.
# $2 : (optional) name of the target config.
#      This defaults to the root directory
# $3 : (optional) the name of the conversion script
#      defaults to /etc/parameter_conversion/conversion

. /lib/functions/uci-defaults.sh

LOGFILE=/etc/parameter_conversion/log

DEBUG=
export DEBUG

echo_debug() {
	if [ -n "$DEBUG" ]; then
		echo $1 >> $DEBUG
	fi
	echo $1
}

. /usr/lib/parameter_conversion/fcopy.sh


rm -f $LOGFILE
mkdir -p $(dirname $LOGFILE)

if [ ! -z "$1" -a -e "$1" ]; then
	old_config=$1
elif [ -L /overlay/homeware_conversion ]; then
	old_config=$(readlink /overlay/homeware_conversion)
elif [ -d /overlay/homeware_conversion ]; then
	old_config=/overlay/homeware_conversion
fi
old_config=${old_config%/}

new_config=${2%/}

export OLD_CONFIG=$old_config
export NEW_CONFIG=$new_config
export OLD_UCI_CONFIG=$old_config/etc/config
export NEW_UCI_CONFIG=$new_config/etc/config

run_conversion_script() { #script
	local script=$1
	local action
	local value1
	local value2
	local value3
	local line=1
	# Remove comments from conversion file

	echo_debug "Conversion file=$script"
	while read action value1 value2 value3; do
		if [ ! -z $action ]; then
			echo_debug "RUN[$line]: $action '$value1' '$value2' '$value3'"
			case $action in
			
			\#*)
				# this is a comment
				;;
			
			debug_on)
				# No parameter required
				DEBUG=$LOGFILE
				echo_debug "Old configuration=$old_config/"
				echo_debug "New configuration=$new_config/"
				echo_debug "Conversion file=$script"
				;;

			duplicate_config)
				# No parameter required
				echo_debug "Duplicate config from $old_config to /"
				copy /
				;;

			copy_dir)
				# value1=directory to be copied
				# value2=new directory destination (optional)
				# value3=(not used)
				value1=${value1#/}
				if [ ! -z $value1 ]; then
					if [ -d $old_config/$value1 ]; then
						copy $value1 $value2
					else
						echo_debug "$script[$line]: copy_dir: '$old_config/$value1' is not a directory"
					fi
				else
					echo_debug "$script[$line]: copy_dir: Error, expected at least 1 parameter"
				fi
				;;

			copy_file)
				# value1=file to be copied
				# value2=new directory (optional)
				# value3=new filename (optional)
				if [ ! -z $value1 ]; then
					copy $value1 $value2 $value3
				else
					echo_debug "$script[$line]: copy_file: Error, expected at least 1 parameter"
				fi
				;;

			uci_set)
				# value1=parameter to be copied
				# value2=new parameter name (optional)
				# value3=(not used)
				convcmds uci_set $value1 $value2
				if [ $? -ne 0 ]; then
					echo_debug "$script[$line]: uci_set: error"
				fi
				;;

			uci_section)
				# value1=section name
				# value2=UCI filename (absolute path)
				# value3=(not used)
				convcmds uci_section $value1 $value2
				if [ $? -ne 0 ]; then
					echo_debug "$script[$line]: uci_section: error"
				fi
				;;

			uci_list)
				# value1=list parameter to be copied
				# value2=new list name (optional)
				# value3=(not used)
				convcmds uci_list $value1 $value2
				if [ $? -ne 0 ]; then
					echo_debug "$script[$line]: uci_list: error"
					fi
				;;

			uci_del )
				#value1=section/option to drop
				#value2=(not used)
				#value3=(not used)
				convcmds uci_del $value1
				if [ $? -ne 0 ]; then
					echo_debug "$script[$line]: uci_del: error"
				fi
				;;

			copy_web_users )
				# no parameters
				convcmds copy_web_users
				if [ $? -ne 0 ]; then
					echo_debug "$script[$line]: copy_web_users: error"
				fi
				;;

			inline_sh_cmd)
				# value1=shell command
				# value2=shell command (continued)
				# value3=shell command (continued)
				if [[ "$value1" ]]; then
					run=$(echo "$value1 $value2 $value3" | sed "s|%%OLDCONFIG%%|$old_config|g")
					echo_debug "inline_sh_cmd: Running '$run'"
					if [ -z "$DEBUG" ]; then
						sh -c "$run"
					else
						sh -c "$run" >>$DEBUG
					fi
				else
					echo_debug "$script[$line]: inline_sh_cmd: Error, expected at least 1 parameter"
				fi
				;;

			*)
				echo_debug "$script[$line]: Unknown action '$action'"
			esac
			line=$(($line+1))
		fi
	done < $script
}

need_commit="no"

if [ ! -z $old_config ]; then

	old_release_version=$(uci -q -c $OLD_UCI_CONFIG get version.@version[0].version | awk -F- '{print $1}')

	if [ ! -z $3 ]; then
		conversion_file=$3
		need_commit="yes"
	elif [[ "$old_release_version" && -f /etc/parameter_conversion/conversion_$old_release_version ]]; then
		conversion_file=/etc/parameter_conversion/conversion_$old_release_version
	else
		conversion_file=/etc/parameter_conversion/conversion
	fi
	
	if [[ -f $conversion_file ]]; then
		run_conversion_script $conversion_file
	else
		echo_debug "Conversion file '$conversion_file' not found"
		need_commit="no"
	fi
	
	HOOKDIR=$old_config/$conversion_file.hooks
	for f in $(ls $HOOKDIR/*.conv 2>/dev/null); do
		run_conversion_script $f
	done
	
	if [ "$need_commit" = "yes" ]; then
		uci -c $NEW_UCI_CONFIG -p /tmp/.uci commit
	fi

	mount | grep -q "tmpfs on /overlay/homeware_conversion type tmpfs" && umount /overlay/homeware_conversion
	rm -rf /overlay/homeware_conversion
fi


