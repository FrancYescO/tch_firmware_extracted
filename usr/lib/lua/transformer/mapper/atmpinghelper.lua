local M={}

local open = io.open
local logger = require("transformer.logger")
local uci = require("transformer.mapper.ucihelper")
-- needed to create named section
local cursor = require('uci').cursor()
local pairs = pairs

local config = "wanatmf5loopback"
local sectiontype = "wanatmf5loopback"

local transactions = {}
local clear = {}

local function transaction_set(binding, pvalue, commitapply)
  uci.set_on_uci(binding, pvalue, commitapply)
  transactions[binding.config] = true
end

local uci_binding = {
  DiagnosticsState = { config = config, sectionname = "", option = "state" },
  NumberOfRepetitions = { config = config, sectionname = "", option = "count" },
  Timeout = { config = config, sectionname = "", option = "timeout" },
}
local binding={config=config,sectionname="",option=""}

function M.adapt_uci_binding(interface)

  if uci_binding["DiagnosticsState"]["sectionname"]~=interface then
    for _,v in pairs(uci_binding) do
      v["sectionname"]=interface
    end
  end
end

local atmf5loopback_name_to_index = {
  SuccessCount = 1,
  FailureCount = 2,
  MinimumResponseTime = 3,
  MaximumResponseTime = 4,
  AverageResponseTime = 5
}

local atmf5loopback_data = {}

local function clear_atmf5loopback_results(interface)
  os.remove("/tmp/atmping_" .. interface)
  atmf5loopback_data[interface] = {}
end

local function read_atmf5loopback_results(interface,name)

  if name ~= nil then
    local idx = atmf5loopback_name_to_index[name]

    -- return cached result
    if atmf5loopback_data[interface] and atmf5loopback_data[interface][idx] then
      return atmf5loopback_data[interface][idx]
    end

    -- read results from atmping
    local fh, msg = open("/tmp/atmping_" .. interface)
    if not fh then
      -- no results present
      logger:debug("atm ping results not found: " .. msg)
      return "0"
    end

    if atmf5loopback_data[interface]==nil then
      atmf5loopback_data[interface]={}
    end

    for line in fh:lines() do
      atmf5loopback_data[interface][#atmf5loopback_data[interface] + 1] = line
    end
    fh:close()
    return atmf5loopback_data[interface][idx]
  else
    return nil
  end
end

-- create default wanatmf5loopback section for interface if it doesn't exist yet.
-- This is done on a separate cursor to avoid contamination.
function M.create_defaults_on_uci(interface)
  local f = open("/etc/config/wanatmf5loopback")
  if not f then
    f = open("/etc/config/wanatmf5loopback", "w")
    if not f then
      error("could not create /etc/config/wanatmf5loopback")
    end
  end
  f:close()
  -- only create if it doesn't exist yet
  if uci.get_from_uci(uci_binding["DiagnosticsState"])=='' then
    -- reload cursor
    cursor:load(config)
    -- create section
    cursor:set(config,interface,sectiontype)
    -- add options
    local binding = uci_binding["DiagnosticsState"]
    cursor:set(binding.config, binding.sectionname, binding.option, 'None')
    binding = uci_binding["NumberOfRepetitions"]
    cursor:set(binding.config, binding.sectionname, binding.option, '1')
    binding = uci_binding["Timeout"]
    cursor:set(binding.config, binding.sectionname, binding.option, '5000')
    -- remove any dangling results
    os.remove("/tmp/atmping_" .. interface)
    -- commit
    cursor:commit(config)
    cursor:unload(config)
  end
end



-- function called when transformer starts up.
-- cleans all atmping results and sets state to None for all interfaces in uci wanatmf5loopback
function M.startup(commitapply)
  -- check if /etc/config/wanatmf5loopback exists
  local f = open("/etc/config/wanatmf5loopback")
  if f then
    f:close()
    uci.foreach_on_uci({config=config,sectionname=sectiontype},function(s)
      uci.set_on_uci({config=config,sectionname=s['.name'],option="state"},'None')
      -- remove any dangling results
      os.remove("/tmp/atmping_" .. s['.name'])
    end)
    uci.commit({config=config})
  end
end

--function gets results from ping tests
function M.getResults(interface, pname)
  local value=""
  if uci_binding[pname] then
    value = uci.get_from_uci(uci_binding[pname])
    if pname == "DiagnosticsState" and value=='InProgress' then
     value='Requested'
    end
  else
    value = read_atmf5loopback_results(interface, pname)
  end
  return value
end

--function starts ping test
function M.starttest(interface, pname, pvalue, commitapply)
    if pname == "DiagnosticsState" then
      if pvalue ~= "Requested" then
        return nil, "invalid value"
      end
      clear[#clear+1]=interface
      transaction_set(uci_binding["DiagnosticsState"], "None")
      transaction_set(uci_binding[pname], pvalue,commitapply)
    else
      local state=uci.get_from_uci(uci_binding["DiagnosticsState"])
      if state~='Requested' and state ~= 'None' then
        -- reset to None
        transaction_set(uci_binding["DiagnosticsState"], 'None',commitapply)
      end
      transaction_set(uci_binding[pname], pvalue,nil)
    end
end

--Get the key of the xdsl interface
function M.getIntf()
  local key = {}
  local network_binding = { sectionname = "interface", config = "network", option = "ifname", default = "" }
  local atm_binding = { sectionname ="atmdevice", config = "xtm", option = "path", default ="" }
  uci.foreach_on_uci(network_binding, function(s)
    local ifname = uci.get_from_uci({
            config = "network", sectionname = s['.name'], option = "ifname"})
    uci.foreach_on_uci(atm_binding,function(se)
            if type(ifname) ~= 'table' then
               if string.find(ifname, se['.name']) ~= nil then
                   key[#key + 1] = se['.name']
                   print("key :".. se['.name'])
               end
            else
              for _,v in pairs(ifname) do
                if v == se['.name'] then
                  key[#key + 1] = se['.name']
                  print("key :".. se['.name'])
				end
              end
	  		end
    end)
  end)
  -- Store key to avoid uci lookup next time this function is called
  -- TODO caching is disabled for now since this needs transformer to restart after config changes
  --getIntf = function() return key end
  return key
end

function M.atm_commit()
  if #clear > 0 then
    for _,interface in pairs(clear) do
      clear_atmf5loopback_results(interface)
    end
    clear = {}
  end
  for config,_ in pairs(transactions) do
    local binding = {config = config}
    uci.commit(binding)
  end
  transactions = {}
end

function M.atm_revert()
  clear = {}
  for config,_ in pairs(transactions) do
    local binding = {config = config}
    uci.revert(binding)
  end
  transactions = {}
end

return M
