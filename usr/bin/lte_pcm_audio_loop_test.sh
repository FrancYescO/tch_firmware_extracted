#!/bin/sh

DTMF_PCMU_FILE="/etc/mmpbx/DTMFS_012345689ABCD.pcmu"
MMBRCMNOSIGTEST="/usr/bin/mmbrcmnosigtest"
MULTIMON="/usr/bin/multimon-ng"

# Stop mmpbx in case it's running
/etc/init.d/mmpbxd stop 2>&1 > /dev/null

sleep 4

# load kernel modules
modprobe dsphal.ko
modprobe slicslac.ko

# allocate temporal files
RAW_FILE=$( mktemp -t raw.XXXXXXXXX )
RESULT=$( mktemp -t dtmf.XXXXXXXX )

# put LTE module into loop mode
ubus call mobiled.device qual '{ "dev_idx":1, "execute":"AT+QAUDLOOP=1" }' 2>&1 > /dev/null

# run loop test
${MMBRCMNOSIGTEST} -i ${DTMF_PCMU_FILE} -o ${RAW_FILE}

# Run DTMF detection
${MULTIMON} -q -a DTMF -t raw  ${RAW_FILE} > ${RESULT}

# cleaning ..
rm ${RAW_FILE}
rmmod slicslac
rmmod dsphal
ubus call mobiled.device qual '{ "dev_idx":1, "execute":"AT+QAUDLOOP=0" }' 2>&1 > /dev/null

HITS=0
for d in 0 1 2 3 4 5 6 8 9 A B C D; do
  grep  -q "DTMF: $d" ${RESULT}
  if [ $? -eq 0 ]; then
     let HITS=$(( HITS + 1 ))
  fi
done

# Make sure that DTMF 7, that we never played, was not detected
grep  -q "DTMF: 7" ${RESULT}
if [ $? -eq 0 ]; then
    let HITS=$(( HITS - 5 ))
fi

rm ${RESULT}

if [ ${HITS} -gt 11 ]; then
    echo "SUCCESS: ${HITS}/13 DTMF detected"
    exit 0
else
    echo "FAIL: ${HITS}/13 DTMF detected"
    exit 1
fi

