--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local format,find,sub,untaint = string.format, string.find, string.sub, string.untaint
local floor, ipairs = math.floor, ipairs
local currentuserrole = ngx.ctx.session:getrole()
local timezone = require("transformer.shared.timezone")
local gVCS = post_helper.getValidateCheckboxSwitch()
local session = ngx.ctx.session
local currentuser = session:getusername()
local gOV = post_helper.getOrValidation
local gAV = post_helper.getAndValidation
local process = require 'tch.process'
local telstra_helper = require("telstra_helper")
local symbolv1 = telstra_helper.symbolnamev1
local symbolv2 = telstra_helper.symbolnamev2
local untaint_mt = require("web.taint").untaint_mt
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Modem", "modem")
local configuration = post_helper.getVariantValue(variantHelper, "configuration")

local function wait_for_completion(base_path, return_json, filename)
  local state_path = base_path .. "state"
  local info_path = base_path .. "info"
  local sleep_time = 0.250
  local max_time = 5
  local total_time = 0
  local content
  repeat
    ngx.sleep(sleep_time)
    total_time = total_time + sleep_time

    content = { state = state_path, info = info_path }
    content_helper.getExactContent(content)

    if content.state ~= "Requested" then
      break
    end
  until (total_time >= max_time)
  if filename then
    os.remove(filename)
  end
  if content.state ~= "Complete" then
    if content.state == "Requested" then
      ngx.log(ngx.ERR, "Timeout on ", base_path)
    else
      ngx.log(ngx.ERR, format('Error on %s (state="%s", info="%s")',
      base_path, content.state, content.info or ""))
    end
    if return_json then
      ngx.print('{ "error":"10" }')
      ngx.exit(ngx.OK)
    else
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
  end
end

local function export_config()
  local export_rpc_path = "rpc.system.config.export."

  local content = {
    export_state = export_rpc_path .. "state",
    export_location = export_rpc_path .. "location",
    export_filename = export_rpc_path .. "filename",
  }

  -- Get transformer content
  content_helper.getExactContent(content)

  if content.export_state ~= "Requested" then
    -- start new export request
    local uptime = content_helper.readfile("/proc/uptime", "number", floor)
    content.export_filename = format("config_export.%d", uptime)

    proxy.set({ [export_rpc_path .. "filename"] = content.export_filename })
    proxy.set({ [export_rpc_path .. "state"] = "Requested" })
  end

  -- wait for completion; does not return on error or timeout
  wait_for_completion(export_rpc_path)

  -- return exported data
  ngx.header.content_disposition = "attachment; filename=config.bin"
  ngx.header.content_type = "application/octet-stream"
  ngx.header.set_cookie = "fileDownload=true; Path=/"  -- the JS download code requires this cookie
  local export_path = untaint(content.export_location .. content.export_filename)
  local f = io.open(export_path, "r")
  ngx.print(f:read("*all"))
  f:close()

  -- cleanup (reset state and remove export file)
  proxy.set({ [export_rpc_path .. "filename"] = "" })

  -- and we're done
  ngx.exit(ngx.HTTP_OK)
end

local function receive_file(filename, match)
  function do_receive(outfile, match)
    local upload = require("web.fileupload")
    local form, err = upload.fromstream()
    if not form then
      return false, 1, "failed to create upload ctx: " .. err
    end
    local totalsize = 0
    local file
    local discard = false
    while true do
      local token, data, err = form:read()
      if not token then
        return false, 2, "read failed: " .. err
      end
      if token == "header" then
        if not discard and not file and find(data[2], match, 1, true) then
          file = outfile
        end
        if not discard and not file then
          return false, 3, "failed to start receiving file"
        end
      elseif token == "body" then
        if file then
          totalsize = totalsize + #data
          file:write(data)
        end
      elseif token == "part_end" then
        if file then
          file = nil
          discard = true
        end
      elseif token == "eof" then
        break
      end
    end
    return true
  end

  local file = io.open(filename, "w")
  local result, err_code, err_msg
  if file then
    result, err_code, err_msg = do_receive(file, match)
  else
    file = io.open("/dev/null", "w")
    do_receive(file, match)
    result = false
    err_code = 4
    err_msg = "internal error"
  end

  file:close()

  return result, err_code, err_msg
end

local function import_config()
  local import_rpc_path = "rpc.system.config.import."
  local filename = "importconfig.bin"

  local content = {
    import_state = import_rpc_path .. "state",
    import_location = import_rpc_path .. "location"
  }
  content_helper.getExactContent(content)
  if content.import_state == "Requested" then
    ngx.log(ngx.ERR, "import already in progress")
    ngx.print('{ "error":"0" }')
    ngx.exit(ngx.OK)
  end

  local rcv_ok, rcv_errno, rcv_errmsg = receive_file(untaint(content.import_location) .. filename, 'name="configfile"')

  if not rcv_ok then
    ngx.log(ngx.ERR, rcv_errmsg)
    ngx.print('{ "error":"' .. rcv_errno .. '" }')
    ngx.exit(ngx.OK)
  end

  -- start actual import through rpc
  proxy.set({ [import_rpc_path .. "filename"] = filename })
  proxy.set({ [import_rpc_path .. "state"] = "Requested" })

  -- wait for completion
  wait_for_completion(import_rpc_path, true, filename)
  ngx.print('{ "success":"true" }')
  -- import is completed; reboot by scheduling a timer so
  -- we can still get our response out
  ngx.timer.at(0, function()
    proxy.set({ ["rpc.system.reboot"] = "GUI" })
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

local function upgradefw()
  local fwupgrade_rpc_path = "rpc.system.fwupgrade."
  local filename = "fwupgrade.bin"

  local content = {
    fwupgrade_state = fwupgrade_rpc_path .. "state",
    fwupgrade_location = fwupgrade_rpc_path .. "location"
  }
  content_helper.getExactContent(content)
  if content.fwupgrade_state == "Requested" then
    ngx.log(ngx.ERR, "upgrade already in progress")
    ngx.print('{ "error":"0" }')
    ngx.exit(ngx.OK)
  end

  -- flush the web template cache
  lp.flush()

  local dl = untaint(content.fwupgrade_location) .. filename
  process.execute("rm", {"-f", dl})
  process.execute("mkfifo", {dl})

  -- start actual upgrade through rpc
  -- sysupgrade will create the pipe
  -- separate requests as the order is important
  proxy.set({[fwupgrade_rpc_path .. "filename"] = filename})
  proxy.set({[fwupgrade_rpc_path .. "state"] = "Requested"})

  -- force GC to run to try to prevent lua from taking more memory during
  -- the upgrade action by having it reclaim some unused objects. This won't
  -- shrink the linux memory usage, but it might prevent it from becoming
  -- even bigger.
  collectgarbage()
  receive_file(dl, 'name="upgradefile"')
  ngx.print('{ "success":"true" }')
  ngx.exit(ngx.HTTP_OK)
end

local function upgradefwstatus()
  local fwupgrade_rpc_path = "rpc.system.fwupgrade."

  local content = {
    fwupgrade_state = fwupgrade_rpc_path .. "state",
    fwupgrade_location = fwupgrade_rpc_path .. "location",
    fwupgrade_filename = fwupgrade_rpc_path .. "filename",
    fwupgrade_info = fwupgrade_rpc_path .. "info",
    fwupgrade_errorcode = fwupgrade_rpc_path .. "errorcode"
  }
  content_helper.getExactContent(content)

  ngx.header.content_type = "application/json"
  if content.fwupgrade_state == "Requested" then
    ngx.print('{ "success":"true" }')
  else
    os.remove(untaint(content.fwupgrade_location .. content.fwupgrade_filename))
    ngx.log(ngx.ERR, "fwupgrade failed: ")
    ngx.print('{ "success":"false" , "errorcode":"' .. untaint(content.fwupgrade_errorcode) .. '" }')
  end

  ngx.exit(ngx.HTTP_OK)
end

local function resetreboot(path, value)
  proxy.set(path, value)
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

-- Colors:
-- cyan = blue + green
-- magenta = blue + red
-- orange = green + red
-- white = blue + green + red
--
-- LED maps:
-- internet/lte/voip/dect = RGO
-- ethernet/mobile/wireless = G


local LOW = "2"
local MID = "5"
local HIGH = "8"

local RGO_map = setmetatable({
  low =    {red = LOW,  green = LOW,  orange = LOW},
  middle = {red = MID,  green = MID,  orange = MID},
  high =   {red = HIGH, green = HIGH, orange = HIGH},
}, untaint_mt)

local G_map = setmetatable({
  low =    {green = LOW},
  middle = {green = MID},
  high =   {green = HIGH},
}, untaint_mt)

local leds_map = setmetatable({
  internet = RGO_map,
  ethernet = G_map,
  mobile = G_map,
  lte = RGO_map,
  voip = RGO_map,
  wireless = G_map,
  dect = RGO_map,
}, untaint_mt)

local ledlevel_values = setmetatable({
  low = true,
  middle = true,
  high = true,
}, untaint_mt)

local levels_map = RGO_map

function getLedLevel(red, green, blue)
  local level = "high"
  for color1, brightness1 in pairs(levels_map) do
    if brightness1["red"] == red and brightness1["green"] == green then
      return color1
    end
  end
  return level
end

local led_levels = {
  {"low", T"<strong>Low</strong>"},
  {"middle", T"<strong>Medium</strong>"},
  {"high", T"<strong>High</strong>"},
}

local brightness = {
  red = "uci.ledfw.brightness.@brightness[0].red",
  green = "uci.ledfw.brightness.@brightness[0].green",
  blue = "uci.ledfw.brightness.@brightness[0].blue",
}

local mmpbxPhonebookFlushKeepDefaultPath = "rpc.mmpbx.phonebook.flush.keepDefault"

local mmpbxPhonebookFlushKeepAllPath = "rpc.mmpbx.phonebook.flush.keepAll"

local cui = {
  upgradefw = "uci.web.uiconfig.@uidefault.upgradefw",
}
content_helper.getExactContent(cui)

-- Handle fwupgrade/configimport/configexport specific GET/POSTs.
if ngx.req.get_method() == "POST" then
  local action = ngx.req.get_uri_args().action
  -- do not call get_post_args before we know that we don't have a file sent otherwise it will fail
  if action == "import_config" then
    return import_config()
  end
  if action == "upgradefw" then
    if not post_helper.isUpgradeAllowed(cui.upgradefw, currentuserrole) then
      ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
    return upgradefw()
  end
  -- now process non-file POSTs
  local action = ngx.req.get_post_args().action
  if action == "export_config" then
    return export_config()
  end
  if action == "system_reset" then
    proxy.set("rpc.mmpbxbrcmdect.registration.clear", "all")
    proxy.set("uci.env.var.rtfds", "1") -- "rpc.system.reset" should be "rtfd --soft" for telstra
    ngx.sleep(8)
    local retain_mode = ngx.req.get_post_args().retain
    if retain_mode == "default" then
      proxy.set(mmpbxPhonebookFlushKeepDefaultPath, "1")
    elseif retain_mode == "all" then
      proxy.set(mmpbxPhonebookFlushKeepAllPath, "1")
    end
    return resetreboot("rpc.system.reset", "1")
  end
  if action == "system_reboot" then
    return resetreboot("rpc.system.reboot", "GUI")
  end
  local postargs = ngx.req.get_post_args()
  local ledlevel = postargs["ledlevel"]
  if ledlevel_values[ledlevel] then
    local led_paths = proxy.getPN("uci.ledfw.brightness.", true)
    for _,v in ipairs(led_paths) do
      local led_path = v.path
      local led_name = proxy.get(led_path .. "name")
      if led_name and led_name[1].value then
        local name = led_name[1].value
        if leds_map[name] and leds_map[name][ledlevel] then
          for color1, brightness1 in pairs(leds_map[name][ledlevel]) do
            proxy.set(led_path .. color1, brightness1)
          end
        end
      end
    end

    proxy.apply()
  end
elseif ngx.req.get_method() == "GET" then
  local action = ngx.req.get_uri_args().action
  local content = {
    fwflash_size = "uci.env.var.banksize"
  }
  content_helper.getExactContent(content)

  if action == "upgradefwstatus" and post_helper.isUpgradeAllowed(cui.upgradefw, currentuserrole) then
    return upgradefwstatus()
  end
  if action == "getbanksize" then
    ngx.header.content_type = "application/json"
    ngx.print('{ "success":"true" , "banksize":"' .. untaint(content.fwflash_size) .. '" }')
    ngx.exit(ngx.HTTP_OK)
  end
end

local led_path = "uci.ledfw.brightness.@brightness[0].name"
local led_internet = proxy.get(led_path)
local led_level
if led_internet and led_internet[1].value == "internet" then
  content_helper.getExactContent(brightness)
  led_level = getLedLevel(brightness["red"], brightness["green"], brightness["blue"])
end

-- Non-configurable data
local content = {
  vendor = "uci.env.var.company_name",
  product_name = "uci.env.var.prod_friendly_name",
  software_name = "uci.version.version.@version[0].marketing_name",
  software_version = "uci.version.version.@version[0].marketing_version",
  firmware_version = "uci.version.version.@version[0].version",
  hardware_version = "uci.env.rip.board_mnemonic",
  dsl_version = "rpc.xdsl.dslversion",
  factory_id = "uci.env.rip.factory_id",
  serial_number = "uci.env.rip.serial",
  mac_address = "uci.env.rip.eth_mac",
  fwversion_prefix = "uci.versioncusto.override.fwversion_prefix",
  fwversion_suffix = "uci.versioncusto.override.fwversion_suffix",
  fwversion_override = "uci.versioncusto.override.fwversion_override",
}

local retain_contact_mode_map = {
    { "0", T'Default Contact&nbsp'},
    { "1", T'All Contact'},
}


content_helper.getExactContent(content)
if content["firmware_version"] then
  local version = content["firmware_version"]
  content["firmware_version"] = content.fwversion_prefix .. sub(version, 1, find(version, "%-[^%-]*$") - 1) .. content.fwversion_suffix
  if content.fwversion_override then
    if content.fwversion_override == "override1" then
      content["firmware_version"] = content.fwversion_prefix .. sub(version, 1, find(version, "%-") -1) .. content.fwversion_suffix
    end
  end
end
content["uptime"] = content_helper.readfile("/proc/uptime","number",floor)
content["system_time"] = os.date("%F %T", os.time())

-- NTP Servers
local ntp_columns = {
  {
    header = T"Server name",
    name = "ntp_server",
    param = "value",
    type = "text",
  }
}

local function validateNTP(value, object, key)
  local validateStringIsIPv4 = post_helper.validateStringIsIP(4)
  local validateStringIsIPv6 = post_helper.validateStringIsIP(6)

-- Adding localdevicemask in post to find the input is a network or broadcast IPv4 address in advancedIPValidation
  object["localdevmask"] = proxy.get("uci.network.interface.@lan.netmask")[1].value
  local ntp_servers = session:retrieve("ntp_data")
  if ntp_servers then
    for _,v in pairs(ntp_servers) do
       if (v[1] == value) then
         return nil, T"Duplicate entry is not allowed"
       end
    end
  end

  local ok, errmsg, wholeNumber
  wholeNumber = string.gsub(value,"%.","")
  if post_helper.getValidateWholeNumber(wholeNumber) then
    ok, errmsg = validateStringIsIPv4(value)
    if not ok then
      return nil, errmsg
    end
    if post_helper.validateIPv4Netmask(value) then
      return nil, T"Cannot use IPv4 subnet mask."
    end
    local ipaddr = proxy.get("rpc.network.interface.@lan.ipaddr")[1].value
    local wan_ipaddr = proxy.get("rpc.network.interface.@wan.ipaddr")[1].value
    if ipaddr and ipaddr == value then
      return nil, T("Cannot use the " .. symbolv2 .. " IP address.")
    elseif wan_ipaddr and wan_ipaddr == value then
      return nil, T("Cannot use the " .. symbolv2 .. " WAN IP address.")
    else
      return gOV(gAV(post_helper.reservedIPValidation, post_helper.advancedIPValidation), validateStringIsIPv6)(value, object, key)
    end
  else
    if not validateStringIsIPv6(value) then
      return post_helper.validateStringIsDomainName(value)
    else
      return true
    end
  end
end

local ntp_valid = {
  ntp_server = validateNTP
}

local ntp_options = {
  tableid = "ntp_servers",
  basepath = "uci.system.ntp.server.@.",
  createMsg = T"Add new NTP server",
  minEntries = 1,
  maxEntries = 3,
}
local ntp_data, ntp_helpmsg = post_helper.handleTableQuery(ntp_columns, ntp_options, nil, nil, ntp_valid)


-- Configurable system parameters
local system_params = {
  system_timezone = "uci.system.system.@system[0].timezone",
  system_zonename = "uci.system.system.@system[0].zonename",
  system_network_timezone = "uci.system.system.@system[0].network_timezone",
}

local system_valid = {
  system_timezone = function(value, object, key)
    local gui_tz = value
    local valid, helpmsg = post_helper.validateNonEmptyString(value)
    if valid then
      local tz_value, zonename_value = string.match(gui_tz,'(.*)_timezone_(.*)')

      --tz_value is the matched result from tz_helper.lua, can not be empty string
      if not tz_value or not zonename_value then
        return valid, helpmsg
      end

      object["system_timezone"] = tz_value
      object["system_zonename"] = zonename_value
    end
    return valid, helpmsg
  end,
  system_zonename = function(value, object,key)
    return true
  end,
  system_network_timezone = function(value, object, key)
    local err,msg = gVCS(value, object, key)
    if not err then
      return err,msg
    end

    if object[key] == "1" then
      object["system_timezone"] = nil
      object["system_zonename"] = nil
    end
    return true
  end,
}

local system_data,system_helpmsg = post_helper.handleQuery(system_params, system_valid)

-- Get timezones
local timezones = require("tz_helper")

local function getTimeZoneName(list, isRemote)
  local default_tztable = {
    [true] = "UTC",
    [false] = nil,
  }

  local tz = system_data["system_timezone"]
  local tz_name = system_data["system_zonename"]
  if tz == "" then
    return default_tztable[isRemote]
  end

  if isRemote then
    local tz_table = {
      ["AEST-10AEDT"] = "Australia/NSW-VIC",
      ["AEST-10"] = "Australia/QLD",
      ["ACST-9:30ACDT"] = "Australia/SA",
      ["ACST-9:30"] = "Australia/NT",
      ["AWST-8"] = "Australia/WA",
    }
    default_tztable[isRemote] = tz
    local timezoneValue = tz
    local timezoneValuePos = string.find(timezoneValue,",")
    if timezoneValuePos~=nil then
      timezoneValue = string.sub(timezoneValue, 1, timezoneValuePos-1)
    end
    for k, v in pairs(tz_table) do
      if k == timezoneValue then
        return v
      end
    end
  end

  if tz_name ~= "" then
    if isRemote then
      return tz_name
    else
      return tz .. "_timezone_" .. tz_name
    end
  end

  for _,v in ipairs(list) do
    local key = string.match(v[1], "^([^_]*)")
    if key == tz then
      if isRemote then
        return v[2]
      else
        return v[1]
      end
    end
  end
  return default_tztable[isRemote]
end
local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T(symbolv2), true, true, nil, help_link) ); ngx.print('\
<div class="modal-body update">\
');  ngx.print(ui_helper.createMessages(message_helper.popMessages())); ngx.print('\
<fieldset>\
  <legend>');  ngx.print( T"Global Information" ); ngx.print('</legend>\
    <form class="form-horizontal" method="post" action="modals/gateway-modal.lp">\
<div class="row">\
<div class="span11">\
<div class="span5">\
');  
    local basic = {
        span = {
            class = "span5"
        },
    }
    local advanced = {
        group = {
            class = "advanced hide",
        },
        span = {
            class = "span5"
        },
    }
    local wait_for_reboot = {
        group = {
            class = "wait-for-reboot"
        },
        button = {
            id = "btn-system-reboot",
            class = "custom-handler"
        }
    }
    local rebooting = {
        alert = {
            class = "alert hide",
            id = "rebooting-msg"
        }
    }
    local wait_for_reset = {
        group = {
            class = "wait-for-reset"
        },
        button = {
            id = "btn-system-reset",
            class = "custom-handler"
        }
    }
    local resetting = {
        alert = {
            class = "alert hide",
            id = "resetting-msg"
        }
    }
    local confirming = {
        alert = {
            class = "alert hide",
            id = "confirming-msg"
        }
    }
    local export_config = {
        button = {
            class = "export-config custom-handler"
        }
    }
    local exporting_alert = {
        alert = {
            class = "alert-info hide",
            id = "exporting-msg"
        }
    }
    local exporting_fail = {
        alert = {
            class = "alert-error hide",
            id = "export-failed-msg"
        }
    }
    local import_config = {
        button = {
            class = "import-config custom-handler",
            id = "btn-import"
        }
    }
    local importing_nofile = {
        alert = {
            class = "alert-error hide",
            id = "import-nofile-msg"
        }
    }
    local importing_alert = {
        alert = {
            class = "alert-info hide",
            id = "importing-msg"
        }
    }
    local importing_fail = {
        alert = {
            class = "alert-error hide",
            id = "import-failed-msg"
        }
    }
    local importing_wrong_ext_fail = {
        alert = {
            class = "alert-error hide",
            id = "import-wrong-ext-msg"
        }
    }
    local importing_too_big_fail = {
        alert = {
            class = "alert-error hide",
            id = "import-too-big-msg"
        }
    }
    local upgradefw = {
        button = {
            class = "upgradefw",
            id = "btn-upgrade"
        }
    }
    local upgrading_nofile = {
        alert = {
            class = "alert-error hide",
            id = "upgrade-nofile-msg"
        }
    }
    local upgrading_transfer = {
        alert = {
            class = "alert hide",
            id = "upgrade-transfer-msg"
        }
    }
    local upgrading_busy = {
        alert = {
            class = "alert hide",
            id = "upgrade-busy-msg"
        }
    }
    local upgrading_fail = {
        alert = {
            class = "alert-error hide",
            id = "upgrade-failed-msg"
        }
    }
    local upgrading_wrong_ext_fail = {
        alert = {
            class = "alert-error hide",
            id = "upgrade-wrong-ext-msg"
        }
    }
    local upgrading_too_big_fail = {
        alert = {
            class = "alert-error hide",
            id = "upgrade-too-big-msg"
        }
    }
    local nw_enable_class = {
        input = {
            class = "monitor-changes",
            --disabled = "disabled",
        }
    }
    local default_tz_class = {
        group = {
            class = "monitor-system_network_timezone monitor-1"
        }
    }
    local user_tz_class = {
        group = {
            class = "monitor-system_network_timezone monitor-0"
        }
    }
    local retain_mmpbx_contacts_attr = {
        input = {
            class = "monitor-changes no-save",
            id = "retain_mmpbx_contacts_id"
        },
    }
    local retain_contact_mode_attr = {
        group = {
            class ="monitor-retain_mmpbx_contacts monitor-1",
        },
        input = {
            class = "no-save",
        },
    }

    local html = {}
    html[#html + 1] = ui_helper.createLabel(T"Product Vendor", content["vendor"], basic)
    html[#html + 1] = ui_helper.createLabel(T"Product Name", content["product_name"], basic)
    html[#html + 1] = ui_helper.createLabel(T"Software Version", content["software_version"], basic)
    html[#html + 1] = ui_helper.createLabel(T"Firmware Version", content["firmware_version"], basic)
    html[#html + 1] = ui_helper.createLabel(T"Hardware Version", content["hardware_version"], basic)
    html[#html + 1] = ui_helper.createLabel(T"DSL Version", content["dsl_version"], basic)
    html[#html + 1] = ui_helper.createLabel(T"Serial Number", content["factory_id"] .. content["serial_number"], basic)
    html[#html + 1] = ui_helper.createLabel(T"MAC Address", content["mac_address"], basic)
    html[#html + 1] = ui_helper.createLabel(T"Uptime", post_helper.secondsToTime(content["uptime"]), basic)
    html[#html + 1] = ui_helper.createLabel(T"System Time", content["system_time"], basic)
    --html[#html + 1] = ui_helper.createInputSelect(T"Timezone", "system_timezone", timezones, system_data["system_timezone"], basic)
    html[#html + 1] = ui_helper.createCheckboxSwitch(T"Network Timezone", "system_network_timezone", system_data["system_network_timezone"], nw_enable_class)
    local currentTZ_remote = getTimeZoneName(timezones, true)
    local currentTZ_gui = getTimeZoneName(timezones, false)
    html[#html + 1] = ui_helper.createLabel(T"Current Timezone", currentTZ_remote, default_tz_class)
    html[#html + 1] = ui_helper.createInputSelect(T"Current Timezone", "system_timezone", timezones, currentTZ_gui, user_tz_class)
    if led_level then
      html[#html + 1] = ui_helper.createSliderSelect(T"Led Level", "ledlevel", led_levels, led_level, basic)
    end
    ngx.print(html)
  ngx.print('\
</div>\
<div class="span5">\
');  
    html = {}
    html[#html + 1] = ui_helper.createButton(T"Restart Device", T"Restart", "icon-refresh", wait_for_reboot)
    html[#html + 1] = ui_helper.createButton(T"Factory Defaults", T"Reset", "icon-bolt", wait_for_reset)
if ngx.ctx.session:hasAccess("/modals/mmpbx-contacts-modal.lp") then
    html[#html + 1] = ui_helper.createCheckboxSwitch(T"Retain Contacts", "retain_mmpbx_contacts", "false", retain_mmpbx_contacts_attr)
end
    html[#html + 1] = string.format('<div class="control-group controls">')
    html[#html + 1] = ui_helper.createAlertBlock(T"Restarting, please wait...", rebooting)
    html[#html + 1] = ui_helper.createAlertBlock(T"Resetting to factory defaults, please wait...", resetting)
    html[#html + 1] = ui_helper.createAlertBlock(T"All your configuration and registrations will be lost. Are you sure to reset the modem?", confirming)
    html[#html + 1] = string.format([[
      <div id="reset-changes" class="hide">
        <div id="reset-confirm" class="btn btn-primary" data-dismiss="modal">%s</div>
        <div id="reset-cancel" class="btn">%s</div>
      </div>
    </div>
    ]], T"Confirm", T"Cancel")
    ngx.print(html)
  ngx.print('\
</div>\
</div>\
<div class="span7">\
');  
html = {}
      -- NTP servers
      html[#html + 1] = format('<div class="control-group advanced hide"><label class="control-label">%s</label><div class="controls">', T"NTP servers")
      html[#html + 1] = ui_helper.createTable(ntp_columns, ntp_data, ntp_options, nil, ntp_helpmsg)
      html[#html + 1] = '</div></div>'
ngx.print(html)
  ngx.print('\
');  
html = {}
      if (configuration and currentuser == "test") or not configuration then
        html[#html + 1] = ui_helper.createButton(T"Export Configuration", T"Export", "icon-download-alt", export_config)
        html[#html + 1] = ui_helper.createAlertBlock(T"Exporting configuration, please wait...", exporting_alert)
        html[#html + 1] = ui_helper.createAlertBlock(T"Exporting failed; please try again.", exporting_fail)
        html[#html + 1] = '</form><form class="form-horizontal" id="form-import" method="post" action="modals/gateway-modal.lp?action=import_config" enctype="multipart/form-data">'
        html[#html + 1] = '<div class="control-group">'
        html[#html + 1] = format('<label class="control-label">%s</label>', T"Import Configuration")
        html[#html + 1] = '<div class="controls">'
        html[#html + 1] = '<input type="file" name="configfile" id="file-import">&nbsp;'
        html[#html + 1] = ui_helper.createSimpleButton(T"Import", "icon-upload-alt", import_config)
        html[#html + 1] = '</div></div>'
        html[#html + 1] = ui_helper.createAlertBlock(T"No file selected.", importing_nofile)
        html[#html + 1] = ui_helper.createAlertBlock(T"Importing configuration, please wait...", importing_alert)
        html[#html + 1] = ui_helper.createAlertBlock(T"Importing failed; please try again.", importing_fail)
        html[#html + 1] = ui_helper.createAlertBlock(T"Importing failed; Invalid file used: expected file with extension bin.  Please use correct file.", importing_wrong_ext_fail)
        html[#html + 1] = ui_helper.createAlertBlock(T"Importing failed; Invalid file used: file too large.  Please use correct.  Please use correct file..", importing_too_big_fail)
      end
      if post_helper.isUpgradeAllowed(cui.upgradefw, currentuserrole) then
        html[#html + 1] = '</form><form class="form-horizontal" id="form-upgradefw" method="post" action="modals/gateway-modal.lp?action=upgradefw" enctype="multipart/form-data">'
        html[#html + 1] = '<div class="control-group">'
        html[#html + 1] = format('<label class="control-label">%s</label>', T"Upgrade firmware")
        html[#html + 1] = '<div class="controls">'
        html[#html + 1] = '<input type="file" name="upgradefile" id="file-upgradefw">&nbsp;'
        html[#html + 1] = ui_helper.createSimpleButton(T"Upgrade", "icon-shield", upgradefw)
        html[#html + 1] = '</div></div>'
        html[#html + 1] = ui_helper.createAlertBlock(T"No file selected.", upgrading_nofile)
        html[#html + 1] = ui_helper.createAlertBlock(T"Uploading firmware, please wait...", upgrading_transfer)
        html[#html + 1] = ui_helper.createAlertBlock(T"Firmware upgrade in progress, please wait...", upgrading_busy)
        html[#html + 1] = ui_helper.createAlertBlock("", upgrading_fail)
        html[#html + 1] = ui_helper.createAlertBlock(T"Firmware upgrade failed.  Invalid file used: expected file with extension rbi.  Please use correct firmware.", upgrading_wrong_ext_fail)
        html[#html + 1] = ui_helper.createAlertBlock(T"Firmware upgrade failed.  Invalid file used: file too large.  Please use correct firmware.", upgrading_too_big_fail)
      end
      ngx.print(html)
      ngx.print('\
</div>\
</div>\
    </form>\
  </fieldset>\
</div>\
<script>\
(function() {\
  var refreshTimeOut = 5000;\
  var refreshDelay = 3000;\
  var target = $(".modal form").attr("action");\
\
  function resetreboot(msg, msg_dst, action) {\
    msg_dst.after(msg);\
    msg.removeClass("hide");\
    msg[0].scrollIntoView();\
    $.post(\
      target,\
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      wait_for_webserver_down,\
      "json"\
    );\
    return false;\
  }\
  $("#btn-system-reboot").click(function() {\
    return resetreboot($("#rebooting-msg"), $(this), "system_reboot");\
  });\
\
  $("#btn-system-reset").click(function() {\
    $("#confirming-msg").removeClass("hide");\
    $("#reset-changes").removeClass("hide");\
  });\
\
  function resetWithRetainValue(msg, msg_dst, action, retain_value) {\
    msg_dst.after(msg);\
    msg.removeClass("hide");\
    msg[0].scrollIntoView();\
    $.post(\
      target,\
      { action: action, retain: retain_value, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      wait_for_webserver_down,\
      "json"\
    );\
    return false;\
  }\
\
  $("#reset-confirm").click(function() {\
    $("#confirming-msg").addClass("hide");\
    $("#reset-changes").addClass("hide");\
    $("#btn-system-reset").addClass("hide");\
    var retain_contact_mode = "default"\
    if ($("#retain_mmpbx_contacts_id").prop("checked")) {\
        retain_contact_mode = "all";\
    }\
    return resetWithRetainValue($("#resetting-msg"), $("#btn-system-reset"), "system_reset", retain_contact_mode);\
  });\
\
  $("#reset-cancel").click(function() {\
    $("#confirming-msg").addClass("hide");\
    $("#reset-changes").addClass("hide");\
    $("#resetting-msg").addClass("hide");\
  });\
\
  $(".export-config").click(function() {\
    $.fileDownload(target, {\
      httpMethod: "POST",\
      data: new Array({ name : "action", value : "export_config" },\
                      { name : "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content") }),\
      prepareCallback: function() {\
        $("#export-failed-msg").addClass("hide");\
        var exporting_msg = $("#exporting-msg");\
        exporting_msg.removeClass("hide");\
        exporting_msg[0].scrollIntoView();\
      },\
      successCallback: function() {\
        $("#exporting-msg").addClass("hide");\
      },\
      failCallback: function() {\
        var export_failed_msg = $("#export-failed-msg");\
        export_failed_msg.removeClass("hide");\
        export_failed_msg[0].scrollIntoView();\
        $("#exporting-msg").addClass("hide");\
      }\
    });\
    return false;\
  });\
\
  $(".import-config").click(function() {\
    var nofile_msg = $("#import-nofile-msg");\
    var wrongext_msg = $("#import-wrong-ext-msg");\
    var toobig_msg = $("#import-too-big-msg");\
    if ($("#file-import").val() == "") {\
      nofile_msg.removeClass("hide");\
      nofile_msg[0].scrollIntoView();\
      return false;\
    }\
    nofile_msg.addClass("hide");\
\
    var validExtensions = [\'bin\'];\
    var fileName = $("#file-import").val();\
    var fileNameExt = fileName.substr(fileName.lastIndexOf(\'.\') + 1);\
    if ($.inArray(fileNameExt, validExtensions) == -1){\
        wrongext_msg.removeClass("hide");\
	wrongext_msg[0].scrollIntoView();\
	return false;\
    }\
    var fileSize = $("#file-import")[0].files[0].size;\
    if (fileSize > 1048576) {\
        toobig_msg.removeClass("hide");\
	toobig_msg[0].scrollIntoView();\
	return false;\
    }\
\
    var _this = $(this).parents(".control-group");\
    $("#import-failed-msg").addClass("hide");\
    var importing_msg = $("#importing-msg");\
    importing_msg.removeClass("hide");\
    importing_msg[0].scrollIntoView();\
    $.fileUpload($("#form-import"), {\
      params: { CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      completeCallback: function(form, response) {\
        $("#importing-msg").addClass("hide");\
        if (response.success) {\
          var msg = $("#rebooting-msg");\
          var msg_dst = $(_this);\
          msg_dst.after(msg);\
          msg.removeClass("hide");\
          msg[0].scrollIntoView();\
          wait_for_webserver_down();\
        }\
        else {\
          $("#import-failed-msg").removeClass("hide");\
        }\
      }\
    });\
    return false;\
  });\
\
  function wait_for_upgradefw() {\
    var msg = $("#upgrade-busy-msg");\
    var msg_dst = $(this);\
    msg_dst.after(msg);\
    msg.removeClass("hide");\
    msg[0].scrollIntoView();\
    function waitForShutdownOrError() {\
      $.ajax({ url: target, data: "action=upgradefwstatus", timeout: refreshTimeOut, dataType: "json" })\
      .done(function(data) {\
        if (data.success == "true") {\
          window.setTimeout(waitForShutdownOrError, refreshDelay);\
        }\
        else {\
          msg.addClass("hide");\
          var failure_msg = $("#upgrade-failed-msg");\
          switch (data.errorcode) {\
          case "1":\
            failure_msg.text("');  ngx.print( T'Firmware upgrade failed.  Insufficient free memory available. Please reboot and try again.' ); ngx.print('");\
            break;\
          case "10":\
          case "255":\
            failure_msg.text("');  ngx.print( T'Firmware upgrade failed; please use the correct firmware.' ); ngx.print('");\
            break;\
          default:\
            failure_msg.text("');  ngx.print( T'Firmware upgrade failed.' ); ngx.print('");\
            break;\
          }\
          failure_msg.text(failure_msg.text() + " (');  ngx.print( T'Errorcode: ' ); ngx.print('" + data.errorcode + ")")\
          failure_msg.removeClass("hide");\
          failure_msg[0].scrollIntoView();\
        }\
      })\
      .fail(wait_for_webserver_running)\
    }\
    window.setTimeout(waitForShutdownOrError, refreshDelay);\
    return false;\
  }\
\
  $(".upgradefw").click(function() {\
    var nofile_msg = $("#upgrade-nofile-msg");\
    var wrongext_msg = $("#upgrade-wrong-ext-msg");\
    var toobig_msg = $("#upgrade-too-big-msg");\
    if ($("#file-upgradefw").val() == "") {\
      nofile_msg.removeClass("hide");\
      nofile_msg[0].scrollIntoView();\
      return false;\
    }\
    nofile_msg.addClass("hide");\
\
    var validExtensions = [\'rbi\',\'fw\'];\
    var fileName = $("#file-upgradefw").val();\
    var fileNameExt = fileName.substr(fileName.lastIndexOf(\'.\') + 1);\
    if ($.inArray(fileNameExt, validExtensions) == -1){\
        wrongext_msg.removeClass("hide");\
	wrongext_msg[0].scrollIntoView();\
	return false;\
    }\
    wrongext_msg.addClass("hide");\
    var fileSize = $("#file-upgradefw")[0].files[0].size;\
\
    $.ajax({ url: target, data: "action=getbanksize", timeout: refreshTimeOut, dataType: "json" })\
      .done(function(data) {\
          if (data.success == "true") {\
	    var targetBankSize = Number(data.banksize);\
\
	    if (fileSize > targetBankSize) {\
    		toobig_msg.removeClass("hide");\
		toobig_msg[0].scrollIntoView();\
		return false;\
	    }\
	  }\
      })\
    toobig_msg.addClass("hide");\
\
    var _this = $(this).parents(".control-group");\
    $("#upgrade-failed-msg").addClass("hide");\
    var upgrading_msg = $("#upgrade-transfer-msg");\
    upgrading_msg.removeClass("hide");\
    upgrading_msg[0].scrollIntoView();\
    $.fileUpload($("#form-upgradefw"), {\
      params: { CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      completeCallback: function(form, response) {\
        $("#upgrade-transfer-msg").addClass("hide");\
        if (response.success) {\
          wait_for_upgradefw.call(_this);\
        }\
        else {\
          $("#upgrade-failed-msg").removeClass("hide");\
        }\
      }\
    });\
    return false;\
  });\
}());\
</script>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 