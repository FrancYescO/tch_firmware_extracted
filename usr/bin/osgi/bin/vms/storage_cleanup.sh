#!/bin/sh

STORAGE=$1
if [ -n "${STORAGE}" ]; then
	echo "# Deleting requested storage [ ${STORAGE} ]"
	if [ -d "${STORAGE}" ]; then
		ERR=0
		if [ -d "${STORAGE}/data" ]; then
			rm -rf ${STORAGE}/data
			rc=$?
			if [ $rc -ne 0 ]; then
				ERR=$rc
				echo   "- Deleting [ ${STORAGE}/data ] failed with error: ${ERR}"
			fi		
		fi
		[ -d "${STORAGE}/data" ] || rm -rf ${STORAGE}/bundles
		ERR=$?
		[ $ERR -ne 0 ] && echo   "- Deleting [ ${STORAGE}/bundles ] failed with error: ${ERR}"
		exit ${ERR}
	else
		echo "# Requested storage [ ${STORAGE} ] is not valid directory!"
		exit 1
	fi
fi

BASEDIR=`dirname $0 2>/dev/null`
# dirname could be missing! prevent removing from undefined base directory!
if [ -z "${BASEDIR}" ]; then
	echo "Failed getting $0 directory!"
	exit 2
fi

echo "# Deleting all storage dirs in `pwd`/${BASEDIR}"

# sanity check for basedir/domain.crp
if [ -z "${BASEDIR}" ] || [ ! -f "${BASEDIR}/domain.crp" ]; then
	echo "# Script directory not valid: `pwd`/${BASEDIR}/domain.crp is missing!"
	exit 1
fi

STORAGES=`find "${BASEDIR}" -maxdepth 2 -name storage -type d`
for dir in ${STORAGES}; do
	if [ -d "${dir}" ]; then
		echo "  - Deleting [ ${dir} ]"
		[ -d "${dir}/data" ] && rm -rf ${dir}/data
		rc=$?
		[ $rc -ne 0 ] && echo "- Deleting [ ${dir}/data ] failed with error: ${rc}"
		[ -d "${dir}/data" ] || rm -rf ${dir}/bundles
		rc=$?
		[ $rc -ne 0 ] && echo   "- Deleting [ ${dir}/bundles ] failed with error: ${rc}"
	fi
done