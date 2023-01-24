local M = {}
local open = io.open
local logger = require("transformer.logger")
local uci = require("transformer.mapper.ucihelper")
local pairs, remove = pairs, os.remove

local bfdecho_name_to_index = {
  DiagnosticsResult = 1,
  IPAddressUsed = 2,
}
local bfdecho_data = {}
local transactions = {}
local clearusers={}
local bfdecho_pid = 0
local uci_binding={}

local function transaction_set(binding, pvalue, commitapply)
  uci.set_on_uci(binding, pvalue, commitapply)
  transactions[binding.config] = true
end

function M.clear_bfdecho_results(user)
    remove("/tmp/bfdecho_".. user)
    bfdecho_data[user] = {}
end

function M.read_bfdecho_results(user, name)
  if(name ~= nil) then
    local idx = bfdecho_name_to_index[name]

    -- return cached result
      if bfdecho_data[user] then
        if bfdecho_data[user][idx] then
          return bfdecho_data[user][idx]
        end
      end
    local my_data ={}
    -- check if bfdecho command is still running
    if bfdecho_pid ~= 0 then return "0" end

    -- read results from bfdecho
    local fh, msg = open("/tmp/bfdecho_".. user)
    if not fh then
      -- no results present
      logger:debug("bfdecho results not found: " .. msg)
      return "0"
    end

    for line in fh:lines() do
      my_data[#my_data + 1] = line
    end
    fh:close()
    bfdecho_data[user]=my_data
    return my_data[idx]
  else
    return nil
  end
end

function M.startup(user, binding)
  uci_binding[user] = binding
  -- check if /etc/config/bfdecho exists, if not create it
  local f = open("/etc/config/bfdecho")
  if not f then
    f = open("/etc/config/bfdecho", "w")
    if not f then
      error("could not create /etc/config/bfdecho")
    end
    f:write("config user '".. user .."'\n")
    f:close()
    uci.set_on_uci(uci_binding[user]["Timeout"], 1)
    uci.set_on_uci(uci_binding[user]["DSCP"], 18)
    uci.set_on_uci(uci_binding[user]["ProtocolVersion"], "IPv4")
    uci.set_on_uci(uci_binding[user]["DiagnosticsState"], "None")
  else
    local value = uci.get_from_uci({config = "bfdecho", sectionname = user})
    if value == '' then
      uci.set_on_uci({config = "bfdecho", sectionname = user},"user")
      uci.set_on_uci(uci_binding[user]["Timeout"], 1)
      uci.set_on_uci(uci_binding[user]["DSCP"], 18)
      uci.set_on_uci(uci_binding[user]["ProtocolVersion"], "IPv4")
      uci.set_on_uci(uci_binding[user]["DiagnosticsState"], "None")
    end
  end
  uci.set_on_uci(uci_binding[user]["DiagnosticsState"], "None")
  uci.commit({ config = "bfdecho"})
  return user
end

function M.uci_bfdecho_get(user, pname)
  local value
  local config = "bfdecho"

  if not uci_binding[user] then
    uci_binding[user] = {
      DiagnosticsState = { config = config, sectionname = user, option = "state" },
      Interface = { config = config, sectionname = user, option = "interface" },
      ProtocolVersion = { config = config, sectionname = user, option = "iptype" },
      Timeout = { config = config, sectionname = user, option = "timeout" },
      DSCP = { config = config, sectionname = user, option = "dscp" },
    }
  end
  if uci_binding[user][pname] then
    value = uci.get_from_uci(uci_binding[user][pname])
    -- Internally, we need to distinguish between Requested and InProgress; IGD does not
    if pname == "DiagnosticsState" and value == "InProgress" then
      value = "Requested"
    end
  else
    return nil, "invalid parameter"
  end
  return value
end

function M.uci_bfdecho_set(user, pname, pvalue, commitapply)
  if pname == "DiagnosticsState" then
    if pvalue ~= "Requested" and pvalue ~= "None" then
      return nil, "invalid value"
    end
    clearusers[user] = true
    transaction_set(uci_binding[user][pname], pvalue, commitapply)
  else
    local state = uci.get_from_uci(uci_binding[user]["DiagnosticsState"])
    if (state ~= "Requested" and  state ~= "None") then
      transaction_set(uci_binding[user]["DiagnosticsState"], "None", commitapply)
    end
    transaction_set(uci_binding[user][pname], pvalue, commitapply)
  end
end

function M.uci_bfdecho_commit()
  for cl_user in pairs(clearusers) do
    M.clear_bfdecho_results(cl_user)
  end
  clearusers={}
  for config in pairs(transactions) do
    local binding = {config = config}
    uci.commit(binding)
  end
  transactions = {}
end

function M.uci_bfdecho_revert()
  clearusers={}
  for config in pairs(transactions) do
    local binding = {config = config}
    uci.revert(binding)
  end
  transactions = {}
end

return M
