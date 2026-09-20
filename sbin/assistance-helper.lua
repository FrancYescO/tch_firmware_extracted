#! /usr/bin/lua
local dm = require("datamodel")

local assistant_intf = {}
local cfg=dm.get("uci.web.assistance.")
if cfg then
  for _, entry in ipairs(cfg) do
    if entry.param == "interface" then
      local name = string.match(entry.path:format("%s"),"%.@([^.]*)%.")
      if name then
        if entry.value == "" then
          assistant_intf[name] = "wan"
        else
          assistant_intf[name] = string.format("%s", entry.value)
        end
      end
    end
  end
end

local inactive_assistants = {}
for k,v in pairs(assistant_intf) do
  local result = dm.get("rpc.network.interface.@" .. v ..".ipaddr")
  local ipaddr
  if result then
    ipaddr = result[1].value
  end
  if ipaddr ~= "" and ipaddr ~= nil then
    os.execute(string.format("wget http://127.0.0.1:55555/ra?%s=on_permanent_srpuci_ -O - 2>/dev/null", k))
  else
    inactive_assistants[#inactive_assistants+1] = k
  end
end

-- release job from crontab
if #inactive_assistants == 0 then
   os.execute("sed -i '/assistance-helper.lua/d' /etc/crontabs/root")
end
