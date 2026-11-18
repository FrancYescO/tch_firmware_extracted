--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2017 -          Technicolor Delivery Technologies, SAS **
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

local ubus = require("ubus")
local s_conn = ubus.connect()
local s_objs
local s_notify = 0

local M = setmetatable({}, { __index = ubus })

function M.send_event(name, data)
  if s_notify ~= 0 then
    s_conn:notify(s_objs.lcm.__ubusobj, name, data)
  end
  -- TODO: ideally we only send notifications but right now cwmpd
  -- is informed about LCM changes through Transformer data model events
  -- and that one currently only supports ubus events
  s_conn:send("lcm." .. name, data)
end

function M.reinit()
  s_conn:close()
  s_conn = ubus.connect()
end

function M.add(objs)
  s_objs = objs
  objs.lcm.__subscriber_cb = function(subs)
    s_notify = subs
  end
  return s_conn:add(objs)
end

function M.call(...)
  return s_conn:call(...)
end

function M.reply(...)
  return s_conn:reply(...)
end

return M
