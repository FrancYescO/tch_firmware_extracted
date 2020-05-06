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
RES1=11
RES2=12
RES3=13
RES4=14
RES5=15
# REASONS_END : keep tag 'REASONS_END' at end of reasons, because this file is parsed by system.map!

get_reboot_reason()
{
	val=${1:-$(cat /proc/prozone/reboot)}
	for var_str in PWR CRASH BOOTP CLI GUI CWMP STS UERR UPGRADE ROLLBACK SWOVER RES1 RES2 RES3 RES4 RES5 ; do
		var=$(eval echo \$$var_str)
		if [ "$var" = "$val" ] ; then
			echo -n "$var:$var_str"
			break
		fi
	done
}

set_reboot_reason()
{
	str=${1:-PWR}
	val=$(eval echo \$$str)
	[ "${val}" ] && echo ${val} >/proc/prozone/reboot
}

is_reboot_reason()
{
	par=${1:-"PWR"}
	val=$(cat /proc/prozone/reboot)
	for var_str in PWR CRASH BOOTP CLI GUI CWMP STS UERR UPGRADE ROLLBACK SWOVER RES1 RES2 RES3 RES4 RES5 ; do
		var=$(eval echo \$$var_str)
		if [ "$var_str" = "$par" -a "$var" = "$val" ] ; then
			return 0
		fi
	done
	return 1
}
