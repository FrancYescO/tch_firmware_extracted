#!/bin/sh
# (C) NETDUMA Software 2016
# 
# Run simple tests to verify that DumaOS in theory should be ready. The only
# way to test correctly would be to boot it up and query it via http protocol.
# However we can't do that because:
#   1) Full DumaOS boot up can take up to 2 mins. Mainly due to potential cloud
#      updates and Geo-Filter IP loading. This is too long for the factory which
#      needs a high rate of turnover.
#   2) During first time boot up of DumaOS many files are written to flash. The
#      factory personnel run the risk of corrupting files or worse yet 
#      corrupting the file system. So we simply can't start DumaOS as part of 
#      the factory testing procedure.
#
# Instead we very expected resources are installed e.g. ubus, core R-Apps, cgi
# files, core bins and verify the file system is writable. 

set -e

#-- @depends echo
#-- @test echo procmanager
echo "Testing DumaOS"

# Verify core bins are installed

#-- @depends which; dpiclass
#-- @test which which && which dpiclass
which dpiclass

#-- @depends which; geoip-ndtech1
#-- @test which which && which geoip
which geoip

#-- @depends which; arpwatch
#-- @test which which && which arpwatch
which arpwatch

#-- @depends which; ctwatch
#-- @test which which && which ctwatch
which ctwatch

#-- @depends which; iptables
#-- @test which which && iptables --help
which iptables

#-- @depends which; ipset
#-- @test which which && ipset help
which ipset

#-- @depends which; sqlite3-cli
#-- @test which which && sqlite3 --help
which sqlite3

#-- @depends which; haserl
#-- @test which which && haserl --help
which haserl

# Test ubus and expected objects

#-- @depends ubus; netifd
#-- @test ubus list
ubus list network.interface.lan

#-- @depends ubus
#-- @test ubus list
ubus list network.interface.wan

#-- @depends ubus; arpwatch
#-- @test ubus list
ubus list com.netdumasoftware.arpwatch

#-- @depends ubus; ctwatch
#-- @test ubus list
ubus list com.netdumasoftware.ctwatch

# Verify entry points and api exist
#-- @depends test
#-- @test test 1
test -x /www/cgi-bin/url-routing.lua

#-- @depends test; ndtech1-api
#-- @test test -e /dumaos/api/cli.lua
test -x /dumaos/api/cli.lua

#-- @depends test; ndtech1-api
#-- @test test -d /dumaos/api/libs
test -d /dumaos/api/libs/

#-- @depends test
#-- @test test -d /dumaos/apps/system/com.netdumasoftware.procmanager
test -d /dumaos/apps/system/com.netdumasoftware.procmanager/

#-- @depends test; autoadmin
#-- @test test -d /dumaos/apps/system/com.netdumasoftware.autoadmin
test -d /dumaos/apps/system/com.netdumasoftware.autoadmin/

#-- @depends test; devicemanager
#-- @test test -d /dumaos/apps/system/com.netdumasoftware.devicemanager
test -d /dumaos/apps/system/com.netdumasoftware.devicemanager/

#-- @depends test
#-- @test test -d /dumaos/apps/system/com.netdumasoftware.networkmonitor
test -d /dumaos/apps/system/com.netdumasoftware.networkmonitor/

#-- @depends test; neigh-watch
#-- @test test -d /dumaos/apps/system/com.netdumasoftware.neighwatch
test -d /dumaos/apps/system/com.netdumasoftware.neighwatch/

#-- @depends test
#-- @test test -d /dumaos/apps/system/com.netdumasoftware.desktop
test -d /dumaos/apps/system/com.netdumasoftware.desktop/

#-- @depends test
#-- @test test -d /dumaos/apps/system/com.netdumasoftware.systeminfo
test -d /dumaos/apps/system/com.netdumasoftware.systeminfo/

# Test overlay file system is writable
#-- @depends echo
#-- @test echo procmanager
echo -n "1" > /dumaos/testwrite

#-- @depends cat
#-- @test which cat
x=$(cat /dumaos/testwrite)

#-- @depends test
#-- @test test 1
test "$x" = "1"

#-- @depends rm
#-- @test which rm
rm /dumaos/testwrite

# Test tmp file system is writable

#-- @depends echo
#-- @test echo procmanager
echo -n "1" > /tmp/testwrite

#-- @depends cat
#-- @test which cat
x=$(cat /tmp/testwrite)

#-- @depends test
#-- @test test 1
test "$x" = "1"

#-- @depends rm
#-- @test which rm
rm /tmp/testwrite

#-- @depends echo
#-- @test echo procmanager
echo "DumaOS ready!"
