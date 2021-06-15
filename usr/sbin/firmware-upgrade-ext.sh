#!/bin/sh

inst_dir="/etc/firmware" # Location of firmware and check scripts
components=`ls /etc/firmware` # Directories whose check_and_update scripts to run

# Only send events if this is a switchover.
# Decide if we have switched over from the other bank or only rebooted by looking at
#   system.fwupgrade.installstatus from the other bank.  Once we have read it and set
#   installstatus in this bank to "installing", clear installstatus in the other bank.
other_bank=$(cat /proc/banktable/notbooted) # The other bank
if [ "$(uci -c /overlay/${other_bank}/etc/config -q get system.fwupgrade.installstatus)" = "switching" ] ; then
	this_is_a_switchover=1
	uci set system.fwupgrade.installstatus="installing"
	uci commit system
	uci -c /overlay/${other_bank}/etc/config set system.fwupgrade.installstatus=""
	uci -c /overlay/${other_bank}/etc/config commit system
else
	this_is_a_switchover=0
fi

# If newversionavailable = 1, it means the upgrade was interrupted before the download began.
# Restart it if there's enough info to do so; otherwise cancel it.
if [ "$(uci -q get system.fwupgrade.newversionavailable)" = "1" ] ; then
	if [ -n "$(uci -q get system.fwupgrade.location)" -a -n "$(uci -q get system.fwupgrade.filename)" ] ; then
		uci set system.fwupgrade.downloadstatus="downloading"
		uci commit
	else
		lua -e '
			local proxy=require("datamodel");
			proxy.set("rpc.system.fwupgrade.downloadstatus","failure");
			proxy.set("rpc.system.fwupgrade.vendorstatuscode","DMC_UPGRADE_STATUS_USER_CANCELLED");
			proxy.apply();
			'
	fi
fi

dl_status=$(uci -q get system.fwupgrade.downloadstatus)
# system.fwupgrade.downloadstatus = "success" is the indication that new firmware has been
#   downloaded to the other bank and is ready to boot.  The only way that can be true is if
#   there is new firmware ready to run in the other bank and you have power cycled.
# If downloadstatus = success and this is not a switchover, call reboot to boot the other
#   bank.  If downloadstatus = success and this IS a switchover, just clear downloadstatus
#   and continue because downloadstatus should not have been set.
if [ "${dl_status}" = "success" ] ; then
	if [ ${this_is_a_switchover} -eq 0 ] ; then
		# Reset the boot failure count
		uci set system.fwupgrade.bootfailurecount="0"
		uci commit system
		reboot
		exit # reboot will not occur until this script exits
	else
		uci set system.fwupgrade.downloadstatus=""
		uci commit
	fi
# If downloadstatus = "downloading", "verifying", or "flashing", it means the download
#   was interrupted by a reboot.  Kick off sysupgrade to restart or continue it.
elif [ "${dl_status}" = "downloading" -o "${dl_status}" = "verifying" -o "${dl_status}" = "flashing" ] ; then
	lua -e '
		local proxy=require("datamodel");
		proxy.set("rpc.system.fwupgrade.state","Requested");
		proxy.apply();
		'
fi

# If installstatus = "installing", the install was interrupted.  Set this_is_a_switchover=1 to send install events.
if [ "`uci -q get system.fwupgrade.installstatus`" = "installing" ] ; then
	this_is_a_switchover=1
fi

# Look for and report failures which occurred on the last boot.
# Remove the status.failure files after you report so you don't report the failure every time you boot.
# This can happen if we're reverting from a failed install in the other bank or a failure in this bank when the
#   other bank is empty.
found_failure_file=0
this_bank=$(cat /proc/banktable/booted) # This bank
other_bank=$(cat /proc/banktable/notbooted) # The other bank

# If there is no image in the passive bank, we are just booting, not reverting.
# If we are just booting, look in this bank for failure files.  If we are reverting,
#   look in the other bank for failure files.
if [ "$(cat /proc/banktable/passiveversion)" = "Unknown" ] ; then
  booting_or_reverting="booting"
  search_dir=${inst_dir}
  the_bank_name="The last time this bank was booted"
else
  booting_or_reverting="reverting"
  search_dir=/overlay/${other_bank}/${inst_dir}
  the_bank_name="When the other bank was booted"
fi

# Look in all of the subdirs of $search_dir.  That may not be the same as $components.
for component_dir in `find ${search_dir} -mindepth 1 -type d` ; do
	failure_file=${component_dir}/status.failure
	if [ -f ${failure_file} ] ; then
		found_failure_file=1
		# Send a failure message to syslog and the console
		component=`basename ${component_dir}`
		logger -s -t "firmware-upgrade-ext" "${the_bank_name} ${component} reported \"`cat ${failure_file}`\"" > /dev/console 2>&1
		# Capture the vendorstatuscode from status.failure if there is one
		vendorstatuscode=`grep vendorstatuscode ${failure_file} | awk '{ print $NF }'`
		/bin/rm ${failure_file}
	fi
done
if [ ${found_failure_file} -eq 1 -a "${booting_or_reverting}" = "reverting" ] ; then
	active_version=$(lua -e '
		local proxy=require("datamodel");
		av=proxy.get("rpc.system.fwupgrade.activeversion");
		av=av and av[1].value;
		print(av)')
	logger -s -t "firmware-upgrade-ext" "Firmware upgrade failed.  System has reverted to previous firmware ${active_version}" > /dev/console 2>&1
	# Send a failure message to ubus for the OLED
	# If any of the status.failure files had vendorstatuscode set, use it; otherwise use the generic UPDATE_FAILED
	lua -e '
		local proxy=require("datamodel");
		proxy.set("rpc.system.fwupgrade.vendorstatuscode","'${vendorstatuscode:-DMC_UPGRADE_STATUS_UPDATE_FAILED}'");
		proxy.set("rpc.system.fwupgrade.installpercent","100");
		proxy.set("rpc.system.fwupgrade.installstatus","failure");
		proxy.apply();
		'
	# Since this is a revert from a failed install, treat the switchover back to
	#   this bank as a normal reboot, not a switchover.  Continue on to undo any
	#   installs which succeeded in the other bank, but do not publish events.
	this_is_a_switchover=0
fi

if [ ${this_is_a_switchover} -eq 1 ] ; then
	lua -e '
		local proxy=require("datamodel");
		proxy.set("rpc.system.fwupgrade.installstatus","installing");
		proxy.apply();
		'
fi

start_time=`date +%s` # Now

# Requires ${inst_dir}/<component>/check_and_update.sh for each component
check_and_update=check_and_update.sh
check_success_command="ls "
for component in ${components} ; do
	/bin/rm -f ${inst_dir}/${component}/status.*
	if [ -x ${inst_dir}/${component}/${check_and_update} ] ; then
		${inst_dir}/${component}/${check_and_update} &
		check_success_command="${check_success_command} ${inst_dir}/${component}/status.success"
	else
		logger -s -t "firmware-upgrade-ext" "Missing ${check_and_update} for ${component}" > /dev/console 2>&1
	fi
done
check_failure_command=`echo ${check_success_command} | sed 's/success/failure/g'`

# Loop, waiting for components to report success or failure.
# Wait on components which report inprogress.
# If nothing changes for more than $timeout seconds, assume it's wedged and abort.
timeout=1200 # seconds
while [ 1 ] ; do
	component_count=0 # Used to count how many components we are checking and upgrading
	sum_of_pcts=0 # Used to compute the completion percentage to display

	# Print a status message when status changes.
	status_msg="firmware-upgrade-ext: STATUS:"
	for component in ${components} ; do
		if [ -f ${inst_dir}/${component}/status.success ] ; then
			status_msg="${status_msg} ${component}:Success"
			this_completion_pct=100
		elif [ -f ${inst_dir}/${component}/status.inprogress ] ; then
			status_msg="${status_msg} ${component}:InProgress"
			this_completion_pct=`sed -n 's/^.*completion[^0-9]*\([0-9]*\).*$/\1/p' ${inst_dir}/${component}/status.inprogress`
			if [ "${this_completion_pct}" = "" ] ; then
				this_completion_pct=0
			fi
		elif [ -f ${inst_dir}/${component}/status.failure ] ; then
			status_msg="${status_msg} ${component}:Failure"
			this_completion_pct=100
		else
			status_msg="${status_msg} ${component}:?"
			this_completion_pct=0
		fi

		# Collect stats for computation of completion percentage
		component_count=`expr ${component_count} + 1`
		sum_of_pcts=`expr ${sum_of_pcts} + ${this_completion_pct}`
	done
	if [ "${status_msg}" != "${last_status_msg}" ] ; then
		logger -s -t "firmware-upgrade-ext" "${status_msg}" > /dev/console 2>&1
	fi
	last_status_msg="${status_msg}"

	# Send a ubus event for the OLED
	if [ ${this_is_a_switchover} -eq 1 ] ; then
		completion_pct=`expr ${sum_of_pcts} / ${component_count}`
		lua -e '
			local proxy=require("datamodel");
			proxy.set("rpc.system.fwupgrade.installpercent","'${completion_pct}'");
			proxy.apply();
			'
	fi

	# Check if the system clock has been adjusted since the last loop
	last_now=${now:-${start_time}}
	now=$(date +%s)

	# If the system clock has progressed more than 15 seconds in this 5-second loop,
	#   somebody has been messing with the system clock.  Make some adjustments.
	#   Otherwise, the inprogress files look older than they really are and the start
	#   time looks earlier than it really was, and we might erroneously time out.
	if [ ${now} -gt $(expr ${last_now} + 15) ] ; then
		logger -s -t "firmware-upgrade-ext" "System clock just skipped forward from $(date -d @${last_now}) to $(date -d @${now})" > /dev/console 2>&1
		clock_adj=$(expr ${now} - ${last_now})  # Approximately
		start_time=$(expr ${start_time} + ${clock_adj})
	else
		clock_adj=0
	fi

	# Look for status.inprogress files, check their age.
	for component in ${components} ; do
		# If we're being told it's in progress and
		if [ -f ${inst_dir}/${component}/status.inprogress ] ; then
			# If the system clock has skipped forward, touch the inprogress file
			#   so we do not exit prematurely due to the apparent age of the file.
			if [ ${clock_adj} -ne 0 ] ; then
				touch ${inst_dir}/${component}/status.inprogress
			fi
			# if the status.inprogress file is more than 300 seconds old, abort.
			inprogress_time=`date -r ${inst_dir}/${component}/status.inprogress +%s`
			if [ ${now} -gt `expr ${inprogress_time} + ${timeout}` ] ; then
				echo "Timed out after ${timeout} seconds" >> ${inst_dir}/${component}/status.failure
			fi
		# If it's not in progress and it hasn't succeeded yet
		elif [ ! -f ${inst_dir}/${component}/status.success ] ; then
			if [ ${now} -gt `expr ${start_time} + ${timeout}` ] ; then
				echo "Timed out after ${timeout} seconds" >> ${inst_dir}/${component}/status.failure
			fi
		fi
	done

	# Break if there is a status.success file for each component.
	${check_success_command} &>/dev/null
	if [ $? -eq 0 ] ; then
		status="success"
		break
	fi
	# Break if there are 1 or more status.failure files.
	${check_failure_command} 2>/dev/null | grep status.failure
	if [ $? -eq 0 ] ; then
		status="failure"
		break
	fi

	# Check again in 5 seconds
	sleep 5
done

# If there was a failure, try to boot this bank again.  If there's no firmware image in the other bank to
#   revert to, keep trying until it succeeds.  If there is an image in the other bank to revert to, try
#   another $max_boot_attempts-1 times (for a total of $max_boot_attempts) before giving up and reverting.
if [ "${status}" = "failure" ] ; then
	logger -s -t "firmware-upgrade-ext" "One or more components could not be flashed." > /dev/console 2>&1
	max_boot_attempts=$(uci -q get system.fwupgrade.maxbootattempts)
	if [ -z "${max_boot_attempts}" ] ; then
		max_boot_attempts=3
	fi
	# Retrieve and increment the number of failed boot attempts so far.
	boot_failure_count=$(uci -q get system.fwupgrade.bootfailurecount)
	# If it's not set, assume this is the first.
	if [ -z "${boot_failure_count}" ] ; then
		boot_failure_count=1
	else
		boot_failure_count=$(expr ${boot_failure_count} + 1)
	fi
	# Save it back to non-volatile memory.
	uci set system.fwupgrade.bootfailurecount="${boot_failure_count}"
	# Remember that this bank failed to upgrade.
	uci set system.fwupgrade.failedtoupgrade="1"
	uci commit system
	if [ ${boot_failure_count} -lt ${max_boot_attempts} ] ; then
		logger -s -t "firmware-upgrade-ext" "Attempt ${boot_failure_count} of ${max_boot_attempts} to boot this bank failed.  Trying again." > /dev/console 2>&1
		# Try to boot this bank again
		reboot
	elif [ "$(cat /proc/banktable/passiveversion)" == "Unknown" ] ; then
		if [ "$(uci -q get system.fwupgrade.keeprebootingonlybank)" != 0 ] ; then
			logger -s -t "firmware-upgrade-ext" "Nothing in the other bank.  Trying to boot this bank again." > /dev/console 2>&1
			# Try to boot this bank again
			reboot
		else
			logger -s -t "firmware-upgrade-ext" "Nothing in the other bank.  Giving up." > /dev/console 2>&1
		fi
	elif [ "$(uci -q get system.fwupgrade.switchbacktofailedbank)" != 0 ] || [ "$(uci -c /overlay/${other_bank}/etc/config -q get system.fwupgrade.failedtoupgrade)" != 1 ] ; then
		logger -s -t "firmware-upgrade-ext" "Giving up trying to boot this bank after ${max_boot_attempts} attempts.  Reverting to the other bank." > /dev/console 2>&1
		# Reset the boot failure count
		uci set system.fwupgrade.bootfailurecount="0"
		uci commit system
		# Boot the other bank
		switchover
	else
		logger -s -t "firmware-upgrade-ext" "Giving up trying to boot this bank after ${max_boot_attempts} attempts.  Not reverting to other bank because it already failed to upgrade." > /dev/console 2>&1
	fi
else
	# Send a success message to syslog and the console
	logger -s -t "firmware-upgrade-ext" "All component firmware is correct." > /dev/console 2>&1
	# Reset the boot failure count
	uci set system.fwupgrade.bootfailurecount="0"
	uci commit system
	if [ ${this_is_a_switchover} -eq 1 ] ; then
		# Send a success message to ubus for the OLED
		lua -e '
			local proxy=require("datamodel");
			proxy.set("rpc.system.fwupgrade.installpercent","100");
			proxy.set("rpc.system.fwupgrade.vendorstatuscode","DMC_UPGRADE_STATUS_SUCCESS");
			proxy.set("rpc.system.fwupgrade.installstatus","success");
			proxy.apply();
			'
		# Log the install of new firmware
		active_version=$(lua -e '
			local proxy=require("datamodel");
			av=proxy.get("rpc.system.fwupgrade.activeversion");
			av=av and av[1].value;
			print(av)')
		logger -s -t "firmware-upgrade-ext" "Installed new firmware ${active_version}" > /dev/console 2>&1
	else
		# Send an installvalid ubus event that will be used to send a success message to Sequans
		# in order to ensure they are not still waiting for an upgrade and will therefore allow
		# a new upgrade.  For now, not sending this event all the time because we don't want to send
		# success twice to Sequans within a short period of time.  If later we determine that doing so
		# is OK, we should likely get rid of this else and always send the installvalid event on every reboot.
		ubus send installvalid
		# In addition to installvalid, send a sequansstatereset ubus event that will be used to call the
		# dcDmcResetUpgradeState() Sequans API function that will ensure the /etc/fumo.upgrade.state file
		# is removed and allow a new upgrade.  Doing this after sending installvalid is just for insurance.
		ubus send sequansstatereset
	fi
fi
