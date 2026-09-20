#!/bin/sh
SKIP_BOOTINI="true"
VM_HOME=/usr/bin/jvms
PROCESSOR=arm

export SKIP_BOOTINI VM_HOME PROCESSOR 

#Disable FWLoader for compatibility with some CEE-J versions
#Load the FW through the system classloader as CEE-J classloader has issues otherwise
_ARGS="$_ARGS nofwloader appcp $*"

# *** Global configuration - EDIT THE VALUES BELOW IF YOU WANT TO ENABLE SOME FEATURE WITHOUT PASSING PARAMETERS
# * set the installation path
if [ -z "$MBS_ROOT" ]; then MBS_ROOT="`pwd`/../../.."; fi
# * arguments setup
PARAMS_PLATFORM="-Xint -Dceej.net.server.reuseaddr=false"
FEATURES="$FEATURES -Dmbs.disableContextClassLoader=true"

# *** DO NOT EDIT BELOW!!!!!

# a call-back function
Execute () {
	# * setup extra bootclasspath if not framework loader is set
	if [ -z "$FWLOADER" ]; then if [ -n "$MBS_SERVER_JAR" ]; then mCP="$MBS_SERVER_JAR"; fi; fi
	# * set class path
	if [ -z "$FWAPPCP" ]; then 
		CP="-Xbootclasspath $BOOTCP:$_SERVER:$mCP -cp $MBS_ROOT/lib/framework/fwtime.jar:$EXTRA_CP";
	else 
		if [ -n "$BOOTCP" ]; then
			CP="-Xbootclasspath $BOOTCP -cp $_SERVER:$mCP:$MBS_ROOT/lib/framework/fwtime.jar:$EXTRA_CP";
		else
			CP="-cp $_SERVER:$mCP:$MBS_ROOT/lib/framework/fwtime.jar:$EXTRA_CP";
		fi
	fi
	# * remote debugging
	XDBG=
	if [ -n "$VM_DEBUG" ]; then
		if [ -n "$VM_DEBUG_SUSPEND" ]; then XDBG="y"; else XDBG="n"; fi
		XDBG="-d:$VM_DEBUG_PORT,suspend=$XDBG";
	fi
	# * execute
	VM_ARGS="-Dmbs.server.jar=$_SERVER $VM_ARGS"
	echo $JAVA $VM_ARGS $XDBG $PARAMS_PLATFORM $CP $FEATURES $FWCLEAN $MAIN_CLASS
	if [ -z "$FWDUMPCMD" ]; then
	$JAVA $VM_ARGS $XDBG $PARAMS_PLATFORM $CP $FEATURES $FWCLEAN $MAIN_CLASS
	fi
}

# *** Parses the command line parameters
Parse () {
	while [ -n "$1" ]; do
	case $1 in
# * resource manager
		-resman|resman)
			if [ -z "$_RESMAN" ]; then _RESMAN="ceej"; fi
			;;
# * delegate to common
		*)
			_ARGS="$_ARGS $1"
			;;			
	esac
	shift
	done
}

Parse $*

# *** VM setup
SetupVM () {
	# * Resource manager
	if [ -n "$_RESMAN" ]; then 
		PARAMS_PLATFORM="$PARAMS_PLATFORM -Dmbs.resman.type=$_RESMAN"
	fi
	# Setup the java virtual machine
	if [ -x "$VM_HOME/siege" ]; then
		JAVA="$VM_HOME/siege";
	elif [ -x "$VM_HOME/siege4" ]; then
		JAVA="$VM_HOME/siege4";
	elif [ -x "$VM_HOME/siege" ]; then
		JAVA="$VM_HOME/siege";
	else
		cat<<EOF
This script was unable to detect the siege VM executable. Please set the
VM_HOME.

Current VM_HOME is $VM_HOME
EOF
		exit 0
	fi
	SIEGEHOME=$VM_HOME
	_SERVER="$MBS_ROOT/lib/framework/serverjvm15$_SERVER_SUFFIX.jar";
}

# run main
. ../server_common.sh
