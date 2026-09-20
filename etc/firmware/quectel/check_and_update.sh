#!/bin/sh

component_root="$(dirname "$0")"
component_name="$(basename "$component_root")"

# Look for the firmware file, determine the required version.
firmware_file="$(ls "$component_root"/*.bli)"
firmware_file_count="$(echo "$firmware_file" | wc -w)"
if [ "$firmware_file_count" -eq 0 ]; then
	echo "firmware-upgrade-ext: No firmware file present for $component_name, not performing upgrade." >/dev/console
	echo "No firmware file present for $component_name, not performing upgrade." >"$component_root/status.success"
	exit 0
elif [ "$firmware_file_count" -ne 1 ]; then
	echo "firmware-upgrade-ext: ERROR: You should have exactly one firmware file in $component_root for $component_name, but you have $firmware_file_count!" >/dev/console
	echo "$firmware_file" >/dev/console
	echo "You should have exactly one firmware file in $component_root for $component_name, but you have $firmware_file_count!" >"$component_root/status.failure"
	echo "$firmware_file" >>"$component_root/status.failure"
	echo "vendorstatuscode: DMC_UPGRADE_STATUS_PKG_VALIDATION_FAILED" >>"$component_root/status.failure"
	exit 3
fi

firmware_basename="$(basename "$firmware_file" .bli)"
source_version="${firmware_basename%-to-*}"
target_version="${firmware_basename#*-to-}"
if [ -z "$source_version" ] || [ -z "$target_version" ]; then
	echo "firmware-upgrade-ext: Firmware filename format should be <source_version>-to-<target_version>.bli!" >/dev/console
	echo "$firmware_file" >/dev/console
	echo "Firmware filename format should be <source_version>-to-<target_version>.bli!" >"$component_root/status.failure"
	echo "$firmware_file" >>"$component_root/status.failure"
fi
echo "firmware-upgrade-ext: $component_name target_version is $target_version" >/dev/console

# Check which version is currently installed.  Try up to 120 times until you get
# an answer that's not "" as a firmware upgrade of the module might be running
# if the power was cut during an upgrade.
installed_version=""
read_attempts=0
max_read_attempts=120
while true; do
	# If you couldn't get an answer, log an error and exit.
	if [ $read_attempts -ge $max_read_attempts ]; then
		echo "firmware-upgrade-ext: Could not detect $component_name version after $read_attempts attempts!  Exiting!" >/dev/console
		echo "Could not detect $component_name version after $read_attempts attempts!" >"$component_root/status.failure"
		exit 1
	fi
	# Here's the command to get the installed version:
	if ubus call mobiled.device firmware_upgrade | jsonfilter -e '$.status' | grep -Eqv '^started|downloading|downloaded|flashing$' && installed_version="$(ubus call mobiled.device get | jsonfilter -e '$.software_version')"; then
		break
	fi
	let ++read_attempts
	sleep 10
done

# If it's not $target_version, install it
if [ "$installed_version" = "$target_version" ]; then
	echo "firmware-upgrade-ext: The installed $component_name version $target_version is up to date." >/dev/console
	echo "The installed $component_name version $target_version is up to date." >"$component_root/status.success"
elif [ "$installed_version" != "$source_version" ]; then
	echo "firmware-upgrade-ext: The installed $component_name version does not match source version, not upgrading." >/dev/console
	echo "The installed $component_name version does not match source version, not upgrading." >"$component_root/status.success"
else
	logger -s -t "firmware-upgrade-ext" "Updating $component_name firmware version $installed_version -> $target_version" >/dev/console
	echo '"completion": 0' >"$component_root/status.inprogress"

	sleep 300
	if upgrade_target "$firmware_file"; then
		logger -s -t "firmware-upgrade-ext" "Successfully updated $component_name firmware." >/dev/console
		echo "$component_name successfully upgraded from $installed_version to $target_version" >"$component_root/status.success"

		# Remove the firmware file to avoid future upgrade attempts.
		rm "$firmware_file"
	else
		logger -s -t "firmware-upgrade-ext" "ERROR: $component_name firmware update failed." >/dev/console
		echo "$component_name failed to upgrade from $installed_version to $target_version" >"$component_root/status.failure"
	fi

	rm -f "$component_root/status.inprogress"
fi

exit 0
