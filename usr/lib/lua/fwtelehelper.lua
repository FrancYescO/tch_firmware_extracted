local setmetatable = setmetatable
local uci = require("transformer.mapper.ucihelper")
local duplicator = require("transformer.mapper.multiroot").duplicate
local fwcommon = require("fwcommon")

local TeleMap = {}
TeleMap.__index = TeleMap

local function get(self)
  return function(data, option)
    local binding = {}
    binding.config = data.config
    binding.sectionname = data.sectionname
    binding.option = option
    return uci.get_from_uci(binding)
  end
end

local function getall(self)
  return function(data)
    local binding = {}
    binding.config = data.config
    binding.sectionname = data.sectionname
    return uci.getall_from_uci(binding)
  end
end

local function set(self)
  return function(data, option)
    local binding = {}
    binding.config = data.config
    binding.sectionname = data.sectionname
    if option then
      binding.option = option
      uci.set_on_uci(binding, data.options[option], self.commitapply)
    else
      for k,v in pairs(data.options) do
        binding.option = k
        uci.set_on_uci(binding, v, self.commitapply)
      end
    end
    self.transactions[binding.config] = true
  end
end

local function add(self)
  return function(data)
    local binding = {}
    binding.config = data.config
    binding.sectionname = data.sectionname
    uci.set_on_uci(binding, data.sectiontype, self.commitapply)
    self.transactions[binding.config] = true
  end
end

local function del(self)
  return function(data)
    local binding = {}
    binding.config = data.config
    binding.sectionname = data.sectionname
    uci.delete_on_uci(binding, self.commitapply)
    self.transactions[binding.config] = true
  end
end

local function each(self)
  return function(data, func)
    local binding = {}
    binding.config = data.config
    binding.sectionname = data.sectiontype
    uci.foreach_on_uci(binding, func)
  end
end

local M = {}


--- perform given action on all outstanding transaction
-- @param tele [table] a connection object
-- @param action [function] the function to call for each transaction
local function finalize_transactions(self, action)
  local binding = {}
  for config in pairs(self.transactions) do
    binding.config = config
    action(binding)
  end
  self.transactions = {}
end

function TeleMap:commit()
  finalize_transactions(self, uci.commit)
end

function TeleMap:revert()
  finalize_transactions(self, uci.revert)
end

function TeleMap:CheckTimeFormat(time)
  local h, m = time:match("^(%d%d):(%d%d)$")
  if not h or not m or tonumber(h) > 23 or (not m:match("00") and not m:match("30")) then
    return false
  else
    return true
  end
end

local ufn_binding = {config = "user_friendly_name"}

function TeleMap:SetUfnDevice(sectionname, option, value)
  ufn_binding.sectionname = sectionname
  ufn_binding.option = option
  uci.set_on_uci(ufn_binding, value, self.commitapply)
  self.transactions[ufn_binding.config] = true
end

function TeleMap:DelUfnDevice(sectionname)
  ufn_binding.sectionname = sectionname
  ufn_binding.option = nil
  uci.delete_on_uci(ufn_binding, self.commitapply)
  self.transactions[ufn_binding.config] = true
end

function TeleMap:RenameUfnDevice(sectionname, newname)
  ufn_binding.sectionname = sectionname
  ufn_binding.option = nil
  uci.rename_on_uci(ufn_binding, newname)
end

function TeleMap:GetUfnDevice(sectionname, option)
  ufn_binding.sectionname = sectionname
  ufn_binding.option = option
  return uci.get_from_uci(ufn_binding)
end

function TeleMap:GetUfnDeviceAll(sectionname)
  ufn_binding.sectionname = sectionname
  ufn_binding.option = nil
  return uci.getall_from_uci(ufn_binding)
end

-- @param mapping [table] the mapping
-- @param register [function] the register function
-- @param id [string] the identification for the mapping name
-- @param reglist [table] all the strings to be registed
function M.register(mapping, register, id, reglist)
  local duplicates = duplicator(mapping, id, reglist)
  for _, dupli in ipairs(duplicates) do
    register(dupli)
  end
end

function M.SetTeleMapping(map, commitapply)
  local tele = {
    map = map,
    commitapply = commitapply,
    transactions = {}
  }
  local proxy = {
    get = get(tele),
    getall = getall(tele),
    set = set(tele),
    add = add(tele),
    del = del(tele),
    each = each(tele),
  }
  tele.mgr = fwcommon.SetProxy(proxy)

  setmetatable(tele, TeleMap)
  return tele
end

return M
