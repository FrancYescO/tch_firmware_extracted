local M = {}
local open = io.open
local logger = require("transformer.logger")
local uci = require("transformer.mapper.ucihelper")
local config = "traceroute"
local match, sub = string.match, string.sub
local pairs, ipairs, tonumber, tostring = pairs, ipairs, tonumber, tostring
local os, error, print = os, error, print
local helper = require("transformer.mapper.nwcommon")

local transactions = {}
local clearusers={}
local traceroute_results = {}
local traceroute_totaltime = {}

local uci_binding={}

local function transaction_set(binding, pvalue, commitapply)
  uci.set_on_uci(binding, pvalue, commitapply)
  transactions[binding.config] = true
end

function M.clear_traceroute_results(user)
  os.remove("/tmp/traceroute_"..user)
  traceroute_results[user] = nil
  traceroute_totaltime[user] = 0
end

function M.read_traceroute_results(user, name)
-- if traceroute_results is not empty, we have cached results
  if (traceroute_results[user]) then
    return traceroute_results[user], traceroute_totaltime[user]
  end

  local results={}

  local fh, msg = open("/tmp/traceroute_".. user)
  if not fh then
    -- no results present
    logger:debug("traceroute results not found: " .. msg)

    return results, 0
  end

  local totaltime = tonumber(fh:read())

  local count = 1
  for line in fh:lines() do
    local host, ip, times = match(line, "(%S+)%s+(%S+)%s+(%S+)")
    -- Limit to 16
    times = times and sub(times, 1, 16)

    -- If the reverse DNS lookup failed, clear out Hostname
    if (host == ip) then
      host = ""
    end
    results[count] = { host, ip, times, "0" }
    count = count + 1
  end

  -- cache results
  traceroute_results[user], traceroute_totaltime[user] = results, totaltime

  return results, totaltime
end

function M.startup(user, binding)
  uci_binding[user] = binding
  -- check if /etc/config/traceroute exists, if not create it
  local f = open("/etc/config/traceroute")
  if not f then
    f = open("/etc/config/traceroute", "w")
    if not f then
      error("could not create /etc/config/traceroute")
    end
    f:write("config  user '".. user .."'\n")
    f:close()
    uci.set_on_uci(uci_binding[user]["NumberOfTries"], 3)
    uci.set_on_uci(uci_binding[user]["Timeout"], 5000)
    uci.set_on_uci(uci_binding[user]["DataBlockSize"], 38)
    uci.set_on_uci(uci_binding[user]["DSCP"], 0)
    uci.set_on_uci(uci_binding[user]["MaxHopCount"], 30)
    else
    local value = uci.get_from_uci({config = "traceroute", sectionname = user})
    if value == '' then
      uci.set_on_uci({config = "traceroute", sectionname = user},"user")
      -- Populate defaults
      uci.set_on_uci(uci_binding[user]["NumberOfTries"], 3)
      uci.set_on_uci(uci_binding[user]["Timeout"], 5000)
      uci.set_on_uci(uci_binding[user]["DataBlockSize"], 38)
      uci.set_on_uci(uci_binding[user]["DSCP"], 0)
      uci.set_on_uci(uci_binding[user]["MaxHopCount"], 30)
    end
  end
  uci.set_on_uci(uci_binding[user]["DiagnosticsState"], "None")
  uci.commit({config = "traceroute"})
  return user
end

function M.uci_traceroute_get(user, pname)
  local value

  if uci_binding[user] == nil then
     uci_binding[user]= {
          DiagnosticsState = { config = config, sectionname = user, option = "state" },
          Interface = { config = config, sectionname = user, option = "interface" },
          Host = { config = config, sectionname = user, option = "host" },
          NumberOfTries = { config = config, sectionname = user, option = "tries" },
          Timeout = { config = config, sectionname = user, option = "timeout" },
          DataBlockSize = { config = config, sectionname = user, option = "size" },
          DSCP = { config = config, sectionname = user, option = "dscp" },
          MaxHopCount = { config = config, sectionname = user, option = "hopcount" },
        }
  end

  if uci_binding[user][pname] then
    value = uci.get_from_uci(uci_binding[user][pname])

    -- Internally, we need to distinguish between Requested and InProgress; IGD does not
    if pname == "DiagnosticsState" and value == "InProgress" then
      value = "Requested"
    end
  elseif (pname == "ResponseTime") then
    local hops, time = M.read_traceroute_results(user)
    value = (time and tostring(time)) or "0"
  else
    return nil, "invalid parameter"
  end
  return value
end

function M.uci_traceroute_set(user, pname, pvalue, commitapply)
  if pname == "DiagnosticsState" then
    if (pvalue ~= "Requested" and pvalue ~= "None") then
      return nil, "invalid value"
    elseif pvalue == "Requested" and user == "device2" then
      local intf = M.uci_traceroute_get(user, "Interface")
      if intf ~= "" then
        local ipStatus = helper.get_ubus_interface_status(intf)
        if ipStatus and ipStatus['ipv4-address'] and ipStatus['ipv4-address'][1] then
          M.ipAddress = ipStatus['ipv4-address'][1]['address']
        elseif ipStatus and ipStatus['ipv6-address'] and ipStatus['ipv6-address'][1] then
          M.ipAddress = ipStatus['ipv6-address'][1]['address']
        end
      end
    end
    clearusers[user] = true
    transaction_set(uci_binding[user]["DiagnosticsState"], pvalue, commitapply)
  elseif (pname == "ResponseTime") then
    return nil, "invalid parameter"
  else
    local state = uci.get_from_uci(uci_binding[user]["DiagnosticsState"])
    if (state ~= "Requested") then
      transaction_set(uci_binding[user]["DiagnosticsState"], "None", commitapply)
    end
    transaction_set(uci_binding[user][pname], pvalue, commitapply)
  end
end

function M.uci_traceroute_commit()
  for cl_user,_ in pairs(clearusers) do
    M.clear_traceroute_results(cl_user)
  end
  clearusers={}
  for config,_ in pairs(transactions) do
    local binding = {config = config}
    uci.commit(binding)
  end
  transactions = {}
end

function M.uci_traceroute_revert()
  clearusers={}
  for config,_ in pairs(transactions) do
    local binding = {config = config}
    uci.revert(binding)
  end
  transactions = {}
end

return M
