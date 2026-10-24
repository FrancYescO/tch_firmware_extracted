--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2015 - 2016  -  Technicolor Delivery Technologies, SAS **
** - All Rights Reserved                                                **
** Technicolor hereby informs you that certain portions                 **
** of this software module and/or Work are owned by Technicolor         **
** and/or its software providers.                                       **
** Distribution copying and modification of all such work are reserved  **
** to Technicolor and/or its affiliates, and are not permitted without  **
** express written authorization from Technicolor.                      **
** Technicolor is registered trademark and trade name of Technicolor,   **
** and shall not be used in any manner without express written          **
** authorization from Technicolor                                       **
*************************************************************************/
--]]

local allowed = {}

-- Object, { method, method, ...}
--    Object names are listed as in `ubus list` output
--    `ubus list -v` lists each object's methods (get, reload, etc.),
--    its output may be used to compile this list.
allowed[ "hostmanager.device"           ] = { "get" }
allowed[ "mmdbd.calllog"                ] = { "list" }
allowed[ "mmdbd.call.statistics"        ] = { "get", "reset" }
allowed[ "mmpbx.call"                   ] = { "get" }
allowed[ "mmpbx.defaultdevice.call"     ] = { "start", "get", "end" }
allowed[ "mmpbx.profile"                ] = { "get" }
allowed[ "mmpbx.rtp.session"            ] = { "list" }
allowed[ "mmpbx.tracelevel"             ] = { "set" }
allowed[ "mmpbxrvsipnet.tracelevel"     ] = { "set" }
allowed[ "mobiled.leds"                 ] = { "get" }
allowed[ "mobiled.sim.pin"              ] = { "get" }
allowed[ "mobiled"                      ] = { "status" }
allowed[ "mobiled.device"               ] = { "get", "profiles", "errors", "capabilities" }
allowed[ "mobiled.network"              ] = { "sessions", "serving_system", "time" }
allowed[ "mobiled.radio"                ] = { "signal_quality" }
allowed[ "mobiled.sim"                  ] = { "get" }
allowed[ "mobiled.sim.pin"              ] = { "unlock", "unblock", "change", "enable", "disable" }
allowed[ "mobiled.sms"                  ] = { "get" }
allowed[ "mobiled.platform"             ] = { "get", "capabilities" }
allowed[ "wireless"                     ] = { "reload" }
allowed[ "wireless.accesspoint.station" ] = { "get" }
allowed[ "wireless.radio"               ] = { "get" }
allowed[ "wireless.radio.acs"           ] = { "rescan" }

return allowed

