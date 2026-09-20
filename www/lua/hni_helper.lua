local M = {}
local dm = require("datamodel")
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local setmetatable = setmetatable
local gmatch = string.gmatch

local function parse_uri(uri)
    local request = {}
    for v in gmatch(uri, "[^/]+") do
        request[#request+1] = v
    end
    return request
end

local function dm_get(path)
  local result = dm.get(path)
  return result and result[1].value
end

local operations = setmetatable({
   ["wifi_doctor"] = { "uci.wifi_doctor_agent.config.enabled", "1", "0" },
   ["tls-vsparc"] = { "Device.Services.X_TELSTRA_THOR.Vsparc.Start", "1", "0" },
   ["tls-thor"] = { "Device.Services.X_TELSTRA_THOR.Platform.Enabled", "1", "0" },
}, untaint_mt)

local ext_operations = setmetatable( {}, untaint_mt)
local autofailover = dm_get("uci.wansensing.global.autofailover")
if autofailover == "0" or autofailover == "1" then
    ext_operations.wifidoctor = { "uci.wifi_doctor_agent.config.cs_url", "https://device-auth-ap.wifi-doctor.org/oauth/token", "" }
end

local function get_status(name)
  local status = setmetatable({}, untaint_mt)
  for k,v in pairs(operations) do
    status[k] = dm_get(v[1])
  end
  if name then
    return { [name]=status[name] }
  end
  return status
end

local function module_set(start, name)
  local set_table = {}
  local status = {}
  local action = start and 2 or 3
  if name then
    local operation = operations[name]
    local ext_operation = ext_operations[name]
    if operation then
      local old_value = dm_get(operation[1])
      if old_value and old_value ~= operation[action] then
        set_table[operation[1]] = operation[action]
        if ext_operation then
          set_table[ext_operation[1]] = ext_operation[action]
        end
      end
      status[name] = operation[action]
    else
      return nil, "Application not found"
    end
  else
    for k,v in pairs(operations) do
      local old_value = dm_get(v[1])
      if old_value then
        if old_value ~= v[action] then
          set_table[v[1]] = v[action]
          local ext_operation = ext_operations[k]
          if ext_operation then
            set_table[ext_operation[1]] = ext_operation[action]
          end
        end
      status[k] = v[action]
      end
    end
  end
  if next(set_table) then
    dm.set(set_table)
    dm.apply()
  end
  return status
end

local function print_header()
  ngx.print('<!DOCTYPE HTML>',
  '<html>',
    '<head>',
    '<meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">',
    '<meta charset="UTF-8">',
    '<link href="/css/gw-telstra.css" rel="stylesheet">',
    '<!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->',
    '<script src="/js/main-telstra-min.js" ></script>',
    '<title>Telstra Gateway</title>',
    '</head>',
    '<body style="background-image:none">')
end

local function print_footer()
  ngx.print('</body>','</html>')
end

local function print_status(status)
  local html = {}
  if next(status) then
    for k,v in pairs(status) do
      html[#html + 1] = ui_helper.createLabel(k,v)
    end
    ngx.print(html)
  else
    ngx.print("Application not found")
  end
end

local function process()
    local uri = ngx.var.request_uri
    local request = parse_uri(uri)
    ngx.header["Content-type"] = "text/html"
    print_header()
    ngx.print('<div class="container toplevel">',
     '<div class="row">',
     '<div class="span11">',
     '<form class="form-horizontal">',
     '<fieldset>',
     '<legend>Information</legend>')
    if request[1] == "hni" then
        if request[2] == "start" or request[2] == "stop" then
            local status, msg = module_set(request[2] == "start",request[3])
            if not status then
              ngx.print(msg)
              return
            end
            ngx.print("Application " .. request[2] .. " is completed")
            print_status(status)
        else
            print_status(get_status(request[2]))
        end
    end
    ngx.print('</fieldset></form></div></div></div>')
    print_footer()
end

M.process = process

return M
