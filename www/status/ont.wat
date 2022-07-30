local setmetatable = setmetatable
local date, time = os.date, os.time
local format, find, sub = string.format, string.find, string.sub
local untaint = string.untaint
local floor = math.floor
local content_helper = require("web.content_helper")
local api = require("fwapihelper")
local dm = require("datamodel")
--test_vari


local function get_sec_info()
  local data = {};
  data["enable"] = dm.get("rpc.env.custovar.ONTmode")[1].value
  data["ont_value"] = "end"
  return data
end

local function set_sec_info(arg)
  dm.set("rpc.env.custovar.ONTmode", string.format("%s",arg.enable))
  dm.apply()
  return true
end

local function get_ont_info()
  local data = {};
  data["enable_ont"] = dm.get("rpc.env.custovar.ONTmodeGUIbutton")[1].value
  data["ont_available"] = "end"
  return data
end

local get_set_value = {
  name = "ont_value",
  get = function()
    return get_sec_info()
  end,
  set = function(args)
    return set_sec_info(args)
  end
}

local get_ont_value = {
  name = "ont_available",
  get = function()
    return get_ont_info()
  end
}

register(get_set_value)
register(get_ont_value)
