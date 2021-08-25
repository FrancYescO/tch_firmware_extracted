#!/bin/sh
# (C) NETDUMA Software 2018
# 
# Preprocess language files for fast translation

#-- @depends ubus
#-- @test ubus list
ubus call com.netdumasoftware.procmanager prepare_language '{ "force" : true }'

#-- @depends test
#-- @test test 1
if [ $? -ne 0 ]; then
  #-- @depends lua
  #-- @test lua -v
  TRANSLATE_FROM_CLI=true lua /dumaos/apps/system/com.netdumasoftware.procmanager/translation.lua
fi

#-- @depends sync
#-- @test which sync
sync
