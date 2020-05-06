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
allowed[ "mmpbx.profile"                ] = { "get" }
allowed[ "wireless"                     ] = { "reload" }
allowed[ "wireless.accesspoint.station" ] = { "get" }
allowed[ "wireless.radio"               ] = { "get" }
allowed[ "wireless.radio.acs"           ] = { "rescan" }

return allowed

