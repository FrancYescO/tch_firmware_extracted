
local require = require
local open = io.open
local remove = os.remove

local lfs = require 'lfs'
local json = require 'dkjson'
local file = require 'tch.posix.file'

local filepath = require "lcm.store.filepath"

local M = {}


local function create_location_dir(location)
  local path = filepath.split(location)
  if #path <= 1 then
    error("invalid db location")
  end
  local dir_present, err = filepath.mkdir(path)
  if not dir_present then
    error(err)
  end
  path[#path+1] = ""
  return filepath.join(path)
end

function M.init(location)
  return {
    prefix = create_location_dir(location)
  }
end

local function filename_for_ID(store_info, ID)
  if ID then
    return store_info.prefix..ID
  end
end

local function sync_save_dir(store_info)
  local fd = file.open(store_info.prefix, file.O_RDONLY)
  if fd then
    fd:fsync()
    fd:close()
  end
end

local function write_data(filename, data)
  local f = file.open(filename, file.O_WRONLY + file.O_CREAT + file.O_TRUNC)
  if f then
    f:write(data)
    f:fsync()
    f:close()
    return true
  end
end

function M.save(store_info, pkg)
  local filename = filename_for_ID(store_info, pkg.ID)
  if not filename then
    return
  end

  if write_data(filename, json.encode(pkg, {indent=true})) then
    sync_save_dir(store_info)
  end
end

function M.list(store_info)
  local ids = {}
  local dir = store_info.prefix
  for ID in lfs.dir(dir) do
    local name = filename_for_ID(store_info, ID)
    if lfs.attributes(name, "mode")=="file" then
      ids[#ids+1] = ID
    end
  end
  return ids
end

function M.load(store_info, ID)
  local filename = filename_for_ID(store_info, ID)
  if not filename then
    return
  end

  local f = open(filename, "rb")
  if f then
    local raw = f:read("*a")
    local pkg = json.decode(raw)
    f:close()
    return pkg
  end
end

function M.remove(store_info, ID)
  local filename = filename_for_ID(store_info, ID)
  if not filename then
    return
  end
  remove(filename)
end

return M