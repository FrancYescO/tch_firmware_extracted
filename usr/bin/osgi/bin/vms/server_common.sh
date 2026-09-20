#!/bin/sh

. /lib/functions.sh
config_load "osgi"

# * enable framework loader or bundle extensions
FWLOADER="on"
#FWEXT="on"

# * enable JIT by default
#FWJIT="on"

# * to disable lazy startup of bundles
#FWLAZY="off"

# * to enable security by default
#FWSECURITY="on"

# * to disable security certificated
#if [ -z "$FWCERT" ]; then FWCERT="on"; fi
local OSGI_CERT 
config_get OSGI_CERT config cert_enable
if [ $OSGI_CERT -eq 1 ]; then FWCERT="on"; fi

# * to enable profiling of framework startup by default
#FWMEASUREMENTS="on"

# * to enable resource monitoring
#FWRESMAN="on"

# * to enable self validation mode
#FWVALIDATE="on"

# * to change the boot file
#FWBOOTFILE="<path_to_boot.ini>"

# * to change the boot properties file
#FWPRS="<path_to_file.prs>"

# * to change the default storage folder
#FWSTORAGE="storage"

# * to clean the storage on startup
#FWCLEAN="on"

# * to dump all framework errors on console
if [ -z "$FWERR" ]; then FWERR="on"; fi

# * to enable the Uncaught Exception Manager
#FWUEM="on"

# * to enable the Framework Logger
#if [ -z "$FWLOG" ]; then FWLOG="on"; fi

# * to enable the Simple Console Logger
# LOG_SIMPLE="on"

# * set the arch name; used to load the correct libtime so
# PROCESSOR=i386

# to enable or disable framework logger
local EN_LOG
config_get EN_LOG config log_enable 
if [ $EN_LOG -eq 1 ]; then
  FWLOG="on"
fi

#get storage path from uci config
local STORAGE_PATH
config_get STORAGE_PATH config storage_dir
FWSTORAGE=$STORAGE_PATH

#get the logfile path from uci config
local OSGI_LOGPATH
config_get OSGI_LOGPATH config logdir

#get loglevel from uci config
local LOGLEVEL
config_get LOGLEVEL config loglevel

case $LOGLEVEL in
	1)
		FWLOGLVL=e
		;;
	2)
		FWLOGLVL=w
		;;
	3)
		FWLOGLVL=i
		;;
	4)
		FWLOGLVL=d
		;;
	
esac

# * set the os name to enable the script to use correct variables for Linux and Mac OS
if [ -z "$OSNAME" ]; then
        OSNAME=`uname -a | grep Darwin`
        if [ -z "$OSNAME" ]; then
                OSNAME="linux";
        else
                OSNAME="macosx"
        fi
fi


# * enable the debug (JDWP as example) mode of the virtual machine.
#VM_DEBUG="on"

#* explicitely set the debug port, the default is 8000, matters only if VM_DEBUG is enabled
if [ -z "$VM_DEBUG_PORT" ]; then VM_DEBUG_PORT="8000"; fi

#* instruct the VM to immediately suspend after starting, matters only if VM_DEBUG is enabled
#VM_DEBUG_SUSPEND="on"

#* pause after the VM process has exited
#WAITONEXIT="false"

# *** DO NOT EDIT BELOW!!!!!
if [ -z "$MBS_ROOT" ]; then MBS_ROOT="../../.."; fi
MAIN_CLASS="com.prosyst.mbs.impl.framework.Start"
EXTARGS=""

# *** These are "DEFAULT" variables that can be set by the caller script
if [ -z "$_FWBOOTFILE" ];     then _FWBOOTFILE="../boot.ini"; fi
if [ -z "$_FWPRS" ];          then _FWPRS="default.prs;../common.prs"; fi
if [ -z "$_SERVER" ];         then _SERVER="$MBS_ROOT/lib/framework/serverjvm15.jar"; fi
if [ -z "$PROCESSOR" ];       then PROCESSOR="i386"; fi
if [ -z "$MBS_DEVICE_ID" ];   then MBS_DEVICE_ID=`hostname`; fi

# *** Parses the command line parameters
Parse () {
	while [ -n "$1" ]; do
		case $1 in
# * features
		-measurements|measurements)
			FWMEASUREMENTS="on" ;;
		-nomeasurements|nomeasurements)
			FWMEASUREMENTS= ;;
		-resman|resman)
			FWRESMAN="on" ;;
		-noresman|noresman)
			FWRESMAN= ;;
		-lazy|lazy) 
			FWLAZY= ;;
		-nolazy|nolazy)
			FWLAZY="off" ;;
		-validate|validate)
		  FWVALIDATE="on";;
		-novalidate|novalidate)
      FWVALIDATE= ;;
		-jit|jit|-JIT|JIT) 
			FWJIT="on" ;;
		-nojit|nojit) 
			FWJIT= ;;
		-security|security)
			FWSECURITY="on" ;;
		-nosecurity|nosecurity)
			FWSECURITY= ;;
		-cert|cert)
			FWCERT="on" ;;
		-nocert|nocert)
			FWCERT= ;;
		-clean|clean)
			FWCLEAN="on" ;;
		-noclean|noclean)
			FWCLEAN= ;;
		-fwloader|fwloader)
			FWLOADER="on" ;;
		-nofwloader|nofwloader)
			FWLOADER= ;;
		-fwext|fwext)
			FWEXT="on" ;;
		-nofwext|nofwext)
			FWEXT= ;;
		-fwerr|fwerr)
			FWERR="on" ;;
		-nofwerr|nofwerr)
			FWERR= ;;
		-uem|uem)
			FWUEM="on" ;;
		-nouem|nouem)
			FWUEM= ;;
		-fwlog|fwlog)
			FWLOG="on" ;;
		-nofwlog|nofwlog)
			FWLOG= ;;
		-consolelog|consolelog)
			LOG_SIMPLE="on" ;;
		-noconsolelog|noconsolelog)
			LOG_SIMPLE ;;
		-appcp|appcp)
			FWAPPCP="on" ;;
		-noappcp|noappcp)
			FWAPPCP= ;;
		-debug|debug)
			VM_DEBUG="on" ;;
		-nodebug|nodebug)
			VM_DEBUG= ;;
		-dbg_suspend|dbg_suspend)
			VM_DEBUG_SUSPEND="on" ;;
		-dbg_nosuspend|dbg_nosuspend)
			VM_DEBUG_SUSPEND= ;;
		-dbg_port|dbg_port)
			VM_DEBUG_PORT=$2
			shift
			;;
		-waitonexit|waitonexit)
		  WAITONEXIT=true
		  ;;	
# * help
		-help|help)
			Help
			;;
# * collect setup files
		*)
			if [ -e $1 ]; then 
				EXT_FILES="$EXT_FILES $1"; 
			elif [ -e ../$1 ]; then
				EXT_FILES="$EXT_FILES ../$1"; 
			else
				EXTARGS="$EXTARGS $1";
			fi
		esac
		shift
	done
}

# *** An utility function to read the boot class path
SetBootCP () {
	unset BOOTCP
	if [ -f "$MBS_STORAGE/data/0/bootcp.set" ]; then
		BOOTCP=`cat "$MBS_STORAGE/data/0/bootcp.set" |sed -e "s/;/:/g"`
	fi
	if [ -n "$FWBOOTCP" ]; then BOOTCP="$FWBOOTCP:$BOOTCP"; fi
}

# *** Processes the command line parameters and sets the VM-specific features
Setup () {

	# * call setup files
	for i in $EXT_FILES; do . ./$i $EXTARGS; done
	for i in auto*;      do if [ -x $i ]; then . ./$i $EXTARGS; fi; done
	for i in ../auto*;   do if [ -x $i ]; then . ./$i $EXTARGS; fi; done
	# * sane parameters
	if [ -z "$FWPRS" ];          then FWPRS="$EXTPRS;$_FWPRS"; fi
	# * disable extension boot file processing
	if [ -n "$FW_NOEXTBOOTFILE" ]; then 
		EXTBOOTFILE=
	fi
	if [ -z "$FWBOOTFILE" ]; then FWBOOTFILE="$_FWBOOTFILE;$EXTBOOTFILE"; fi
	# rem * make sure FWEXT switches FWLOADER too
	if [ -n "$FWEXT" ];          then FWLOADER="on"; fi
	# * set features
	if [ -n "$FWPRS" ];          then FEATURES="$FEATURES -Dmbs.prs.name=$FWPRS"; fi
	if [ -n "$FWLOADER" ];       then FEATURES="$FEATURES -Dmbs.customFrameworkLoader=true -Dmbs.server.jar=$_SERVER:$MBS_SERVER_JAR"; fi
	if [ -n "$FWRESMAN" ];       then FEATURES="$FEATURES -Dmbs.resman.enabled=true"; fi
	if [ -n "$FWVALIDATE" ];     then FEATURES="$FEATURES -Dmbs.um.validation=true"; fi
	if [ -z "$FWERR" ];          then FEATURES="$FEATURES -Dmbs.log.errorlevel=false"; fi
	if [ -n "$FWLAZY" ];         then FEATURES="$FEATURES -Dmbs.bundles.lazy=false"; fi
	if [ -n "$FWSECURITY" ];     then FEATURES="$FEATURES -Dmbs.security=jdk12 -Djava.security.policy=../policy.all -Dmbs.sm=true"; fi
	if [ -n "$FWCERT" ];         then FEATURES="$FEATURES -Dmbs.certificates=true -Dmbs.certificates.strict=true -Dmbs.certificate.root=/opt/osgi/keystore/ -Dmbs.keystore.class=com.prosyst.mbs.impl.framework.module.certmanager.certstorage.FolderCertificateStorageImpl"; else FEATURES="$FEATURES -Dmbs.certificates=false" ; fi
	if [ -n "$FWCLEAN" ];        then FEATURES="$FEATURES -Dmbs.storage.delete=true"; fi
	if [ -n "$FWBOOTFILE" ];     then FEATURES="$FEATURES -Dmbs.boot.bootfile=$FWBOOTFILE"; fi
	if [ -n "$FWSTORAGE" ];      then FEATURES="$FEATURES -Dmbs.storage.root=$FWSTORAGE"; fi
	if [ -n "$FWMEASUREMENTS" ]; then FEATURES="$FEATURES -Dmbs.measurements.intermediate=true"; fi
	if [ -n "$FWUEM" ];          then FEATURES="$FEATURES -Dmbs.thread.uem=true"; fi
	if [ -n "$FWLOG" ];          then FEATURES="$FEATURES -Dmbs.log.file.dir=$OSGI_LOGPATH -Dmbs.framework.log.level=$FWLOGLVL -Dmbs.util.ref.log.level=$LOGLEVEL"; fi	#changed from "-Dmbs.log.file.dir=logs" to set log path and log level in the framework
	if [ -n "$LOG_SIMPLE" ];     then FEATURES="$FEATURES -Dmbs.log.simple=true"; fi
	if [ -n "$FWJIT" ];          then JIT=; fi
	FEATURES="$JIT $FEATURES"
	if [ -n "$MBS_DEVICE_ID" ];   then FEATURES="$FEATURES -Dcom.prosyst.mbs.deviceId=$MBS_DEVICE_ID"; fi
	# * setup the library path
	MBS_STORAGE="$FWSTORAGE"
	if [ -z "$MBS_STORAGE" ]; then MBS_STORAGE="`pwd`/storage"; fi
	MBS_NATIVE_PATH="$MBS_NATIVE_PATH:$MBS_ROOT/lib/framework/runtimes/$OSNAME/$PROCESSOR:$MBS_STORAGE/native"
	# * add native path to the system path, where libraries can be loaded succesfully
	if [ "$OSNAME" = "macosx" ]; then
	    export DYLD_LIBRARY_PATH="$MBS_NATIVE_PATH:$DYLD_LIBRARY_PATH"
	else
		LD_LIBRARY_PATH="$MBS_NATIVE_PATH:$LD_LIBRARY_PATH"
	fi
}


# *** An utility function to print the help screen
Help () {
	cat ../server_common_help.txt
	if [ -f server_help.txt ]; then cat server_help.txt; fi
	exit 0
}

# *** re-reads the boot class path and call-back the caller script to execute the VM
StartServer () {
	SetBootCP
	Execute
	FWEXITCODE=$?
	export FWEXITCODE
	case $FWEXITCODE in
		# framework extension was installed - restart
		23)
			if [ -z "$MBSA_ROOT" ]; then
				if [ -n "$FWCLEAN" ]; then
					unset FWCLEAN
					FEATURES=`echo "$FEATURES" | sed -n s/" -Dmbs.storage.delete=true"//p`
				fi
				StartServer
			fi
		;;
	esac
	return $FWEXITCODE
}

# *** an utility method used by vm scripts to setup their own VM
FindVM () {
	# $1 - executable image
	# $2 - extra path
	# $3 - bin folder, defaults to bin
	BIN="bin"
	if [ -n "$3" ]; then BIN="$3"; fi
	if [ -x "$VM_HOME/$BIN/$1" ]; then
		JAVA="$VM_HOME/$BIN/$1"
	elif [ -x "$2/$BIN/$1" ]; then
		VM_HOME="$2"
		JAVA="$VM_HOME/$BIN/$1"
	else
		JAVA=`which $1 2> /dev/null`
		if [ -x "$JAVA" ]; then
			VM_HOME=`dirname $JAVA`/..
		fi
	fi

	if [ -x "$JAVA" ]; then
		echo "Using $1 VM from: $VM_HOME" | sed -n -e "s/\/$BIN\/[^\/]*$//p"
	else
		cat<<EOF
This script was unable to detect the $1 VM executable. Please set the
VM_HOME environment variable or add the '$1' to the executable PATH.

Current VM_HOME is $VM_HOME
EOF
		exit 0
	fi
}

Parse $_ARGS
SetupVM
Setup
export LD_LIBRARY_PATH
StartServer

if [ -n "$WAITONEXIT" ]; then
   read -p "Press any key to continue" -n 1
fi

# TO USE THIS FILE FROM OTHER SCRIPTS MAKE SURE THAT YOUR SCRIPT:
# 1. Collects all command-line arguments into variable named "_ARGS" -> (_ARGS=$*)
# 2. Defines Execute() function - where the VM is executed
# 3. Sources this file: . ../server_common.sh
# THE FOLLOWING VARIABLES ARE EXPORTED OR USED BY THIS SCRIPT:
# $MBS_NATIVE_PATH - import & export, path to native libraries
# $MBS_ROOT - the absolute location of server
# $LD_LIBRARY_PATH - modified to include $MBS_NATIVE_PATH, must be exported in Execute()
# $FEATURES - a list with defines
# $MAIN_CLASS - main class of the framework
# $BOOTCP - the contents of the bootcp.set file
