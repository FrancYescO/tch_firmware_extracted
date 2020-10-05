
local require = require
local pcall = pcall
local error = error
local setmetatable = setmetatable

--$ require("lcm.store.none_store")
--$ require("lcm.store.file_store")

local function create_storage(store, location)
  local store_info = store.init(location)
  local st = {
    save = function(_, pkg)
      return store.save(store_info, pkg)
    end,
    list = function()
      return store.list(store_info)
    end,
    load = function(_, ID)
      return store.load(store_info, ID)
    end,
    remove = function(_, ID)
      return store.remove(store_info, ID)
    end,
  }
  st.__index = st
  return setmetatable({}, st)
end


local function load_store(type)
  type = type or "none"
  local ok, store = pcall(require, "lcm.store."..type.."_store")
  if not ok then
    error("storage type "..type.." is unknown")
  end
  return store
end

local M = {}

function M.open(type, location)
  local store = load_store(type)
  return create_storage(store, location)
end

return M