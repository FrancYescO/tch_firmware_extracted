PWR=0
CRASH=1
BOOTP=2
CLI=3
GUI=4
CWMP=5
STS=6
UERR=7
UPGRADE=8
ROLLBACK=9
SWOVER=10
TR64=11
RES1=12
RES2=13
RES3=14
RES4=15
# REASONS_END : keep tag 'REASONS_END' at end of reasons, because this file is parsed by system.map!


get_reboot_reason()
{
	if [[ -f /proc/prozone/reboot ]]; then
		val=${1:-$(cat /proc/prozone/reboot)}
		for var_str in PWR CRASH BOOTP CLI GUI CWMP STS UERR UPGRADE ROLLBACK SWOVER TR64 RES1 RES2 RES3 RES4 ; do
			var=$(eval echo \$$var_str)
			if [ "$var" = "$val" ] ; then
				echo -n "$var:$var_str"
				break
			fi
		done
	fi
}

set_reboot_reason()
{
	if [[ -f /proc/prozone/reboot ]]; then
		str=${1:-PWR}
		val=$(eval echo \$$str)
		[ "${val}" ] && echo ${val} >/proc/prozone/reboot
	fi
}

is_reboot_reason()
{
	if [[ -f /proc/prozone/reboot ]]; then
		par=${1:-"PWR"}
		val=$(cat /proc/prozone/reboot)
		for var_str in PWR CRASH BOOTP CLI GUI CWMP STS UERR UPGRADE ROLLBACK SWOVER TR64 RES1 RES2 RES3 RES4 ; do		var=$(eval echo \$$var_str)
			if [ "$var_str" = "$par" -a "$var" = "$val" ] ; then
				return 0
			fi
		done
	fi
	return 1
}
