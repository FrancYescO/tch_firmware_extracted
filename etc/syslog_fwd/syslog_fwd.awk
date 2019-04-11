BEGIN {


	fscmd="wc "outfile
	fscmd | getline
	close(fscmd)
	lines=$1
	fsize=$3
#	maxlines=maxize*10
#	droplines=maxize*5
	maxize*=1024
	prefix=""
	LEVEL=8

	facility["kern"]=0
	facility["user"]=1
	facility["mail"]=2
	facility["daemon"]=3
	facility["security"]=4
	facility["syslog"]=5
	facility["lpr"]=6
	facility["news"]=7
	facility["uucp"]=8
	facility["clock"]=9
	facility["authpriv"]=10
	facility["ftp"]=11
	facility["ntp"]=12
	facility["audit"]=13
	facility["alert"]=14
	facility["cron"]=15
	facility["local0"]=16
	facility["local1"]=17
	facility["local2"]=18
	facility["local3"]=19
	facility["local4"]=20
	facility["local5"]=21
	facility["local6"]=22
	facility["local7"]=23
	facility["mark"]=24

	severity["emerg"]=0
	severity["panic"]=0
	severity["alert"]=1
	severity["crit"]=2
	severity["err"]=3
	severity["error"]=3
	severity["warn"]=4
	severity["warning"]=4
	severity["notice"]=5
	severity["info"]=6
	severity["debug"]=7
	severity["none"]=8

#get level from uci
	cmd="uci get system.@system[0].filterloglevel 2>/dev/null"
	cmd | getline LEVEL
	close(cmd)

	cmd="uci get system.@system[0].hostname"
	cmd | getline HOST
	close(cmd)
	prefix=prefix HOST " "

	cmd="uci get env.rip.eth_mac"
	cmd | getline MAC
	close(cmd)
	gsub(/:/,"-",MAC)
	prefix=prefix"[MAC="MAC"]"

	cmd="uci get env.var.serial"
	cmd | getline SN
	close(cmd)
	prefix=prefix"[S/N="SN"]"
	gsub(/ /,"",prefix)

	cmd="uci get system.@system[0].log_prefix 2>/dev/null"
	cmd | getline LOG_PREFIX
	close(cmd)

	hostname=prefix
}

$0 ~ pattern && (!xpattern || $0 !~ xpattern) {
	lines++
	pri_str="user.notice"
	pos_h=match($0,HOST " ")
	if (pos_h >=40) pos_h=0
	if (pos_h == 0)
		SR_STR= ""
	else
		SR_STR= HOST " "
	pos_p=match($0,/\w+\.\w+/)
	if (pos_p != 0) {
		pri_str=substr($0,RSTART,RLENGTH)
		sub(SR_STR pri_str, hostname)
	}
	else if (pos_h !=0) {
		sub(SR_STR, hostname)		
	}
#logging : in case hostname/prefix translation is wrong
#	print $0 ";HOST:'" HOST ",SR_STR:'" SR_STR "',pos_p:" pos_p ",pos_h:" pos_h "pri_str:'" pri_str "'" >>"/etc/syslog_fwd/syslog_awk.log"
	split(pri_str,pri,".")
	fac=pri[1]
	sev=pri[2]
	priority=facility[fac] * 8 + severity[sev]
#skip line if severity too high (higher severity is less urgent), so not urgent enough
 	if (severity[sev] >= LEVEL) next
	if (LOG_PREFIX != "")
		sub(": ", ": "LOG_PREFIX" ")
	line="<" priority ">" $0
	fsize+=length(line)
	print line >>outfile
	fflush(outfile)
	if (fsize > maxize) {
#	if (lines >= maxlines) {
# Log Rotate
		cmd="mv "outfile" "outfile".1"
		close(outfile)
		system(cmd)
		lines=0
		fsize=0
## Alternative : Remove lines from beginning of log file (shrink)
#		cmd="sed -i '1,"droplines"d' " outfile
#		system(cmd)
#		close(outfile)
#		lines-=droplines
	}
}

END {
}
