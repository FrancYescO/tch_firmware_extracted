--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local session = ngx.ctx.session
local role = session:getrole()
local proxy = require("datamodel")
local wanIntf = post_helper.getActiveInterface()

function getValidateNumberInRange(min, max, value)
  local isNotNumber = value and string.find(value, "[^%d]+")
  local helptext = T"Input must be a number"
  if isNotNumber then
    return nil, helptext
  end
  if min and max then
    helptext = string.format(T"Input must be a number between %d and %d included", min, max)
  elseif not min and not max then
    helptext = T"Input must be a number"
  elseif not min then
    helptext = string.format(T"Input must be a number smaller than %d included", max)
  elseif not max then
    helptext = string.format(T"Input must be a number greater than %d included", min)
  end

  local num = tonumber(value)
  if not num then
    return nil, helptext
  end
  if min and num < min then
    return nil, helptext
  end
  if max and num > max then
    return nil, helptext
  end
  return true
end


function setLanRelay(dname)
  local sfp_check = proxy.get("uci.env.rip.sfp")[1].value or ""

  if sfp_check == "1" then
    proxy.del("uci.network.interface.@lan.pppoerelay.")
    proxy.add("uci.network.interface.@lan.pppoerelay.")
    proxy.set("uci.network.interface.@lan.pppoerelay.@1.value",dname)
  end
end

local pathifname = string.format("uci.network.interface.@%s.ifname", wanIntf)
local iface = proxy.get(pathifname)[1].value
local connection = "ptm0"
local path = ""
local vid = ""
local dname = ""
local difname = ""

local function getVID()
  if string.match(iface, "eth") then
    connection = "eth4"
    path = "uci.network.device.@"..wanIntf.."eth4."
    if string.match(iface, "%.") then
      difname = string.match(iface, "eth4%.[%d]+")
      vid = string.match(difname, "[^eth4%.]+")
    else
      if proxy.get(path) then
        vid = proxy.get(path.."vid")[1].value
        dname = proxy.get(path.."name")[1].value
        difname = proxy.get(path.."ifname")[1].value
      end
    end
  elseif string.match(iface, "atm") then
    connection = "atmwan"
    path = "uci.network.device.@wanatmwan."
    if string.match(iface, "%.") then
      difname = string.match(iface, "atmwan%.[%d]+")
      vid = string.match(difname, "[^atmwan%.]+")
    else
      if proxy.get(path) then
        vid = proxy.get(path.."vid")[1].value
        dname = proxy.get(path.."name")[1].value
        difname = proxy.get(path.."ifname")[1].value
      end
    end
  else
    path = "uci.network.device.@wanptm0."
    if string.match(iface, "%.") then
      difname = string.match(iface, "ptm0%.[%d]+")
      vid = string.match(difname, "[^ptm0%.]+")
    else
      if proxy.get(path) then
        vid = proxy.get(path.."vid")[1].value
        dname = proxy.get(path.."name")[1].value
        difname = proxy.get(path.."ifname")[1].value
      end
    end
  end
end
getVID()

if ngx.var.request_method == "POST" then
  local content = ngx.req.get_post_args()
  if content["action"]=="SAVE" then
    range, helpmes = getValidateNumberInRange(2, 4094, content["intf_vlanid"])
    if role ~= "engineer" then
      content["auswahlliste"] = "devnot"
    end
    if content["auswahlliste"] == "devnot" then
      if range and (content["intf_vlanid"] ~= vid or content["intf_vlan"] ~= "0") then
        if proxy.get(path) then
          dname = proxy.get(path.."name")[1].value
          if content["intf_vlanid"] then
          proxy.set(path.."vid", content["intf_vlanid"])
          end
          proxy.set(pathifname, dname)
          setLanRelay(dname)
          proxy.set(path.."ifname", connection)
        else
          proxy.add("uci.network.device.", string.format("%s%s", wanIntf, connection ))
          proxy.set(path.."type","8021q")
          proxy.set(path.."name","wan"..connection)
          proxy.set(path.."macaddr", proxy.get("uci.env.rip.eth_mac")[1].value)
          dname = proxy.get(path.."name")[1].value
          if content["intf_vlanid"] then
          proxy.set(path.."vid", content["intf_vlanid"])
          end
          proxy.set(pathifname, dname)
          setLanRelay(dname)
          proxy.set(path.."ifname", connection)
        end
        if content["intf_vlanid"] then
        vid = content["intf_vlanid"]
        end
        difname = string.format("wan%s", connection)
        message_helper.pushMessage(T"Changes saved successfully", "success")
      elseif helpmes then
        if content["intf_vlan"] and content["intf_vlan"]~="0" then
          if content["intf_vlanid"] then
          vid = content["intf_vlanid"]
          end
          difname = string.format("wan%s", connection)
          message_helper.pushMessage(T"Some parameters failed validation", "error")
        else
          helpmes = nil
        end
      end
    elseif content["auswahlliste"] == "dotnot" then
      if range and (content["intf_vlanid"]~=vid or content["intf_vlan"]~="0") then
        if proxy.get(path) and proxy.get(path.."ifname")[1].value ~="" then
          proxy.set(path.."ifname", "")
        end
        if content["intf_vlanid"] then
        difname = string.format("%s.%s",connection, content["intf_vlanid"])
        vid = content["intf_vlanid"]
        proxy.set(pathifname, string.format("%s.%s",connection, content["intf_vlanid"]))
        setLanRelay(string.format("%s.%s",connection, content["intf_vlanid"]))
        end
      end
    end
    proxy.apply()
    if content["intf_vlan"] and content["intf_vlan"]=="0" then
      if proxy.get(path) then
        proxy.set(path.."ifname", "")
      end
      proxy.set(pathifname, connection)
      setLanRelay(connection)
      proxy.apply()
      difname = ""
      message_helper.pushMessage(T"Changes saved successfully", "success")
    end
    iface = proxy.get(pathifname)[1].value
    if string.match(iface, "eth") then
      connection = "eth4"
      path = "uci.network.device.@"..wanIntf.."eth4."
      if not string.match(iface, "%.") then
        if proxy.get(path) then
          dname = proxy.get(path.."name")[1].value
        end
      end
    elseif string.match(iface, "ptm") then
      connection = "ptm0"
      path = "uci.network.device.@wanptm0."
      if not string.match(iface, "%.") then
        if proxy.get(path) then
          dname = proxy.get(path.."name")[1].value
        end
      end
    else
      connection = "atmwan"
      path = "uci.network.device.@wanatmwan."
      if not string.match(iface, "%.") then
        if proxy.get(path) then
          dname = proxy.get(path.."name")[1].value
        end
      end
    end
  end
end
local check = string.match(iface, "%.") and "dotnot" or "devnot"
local notationintf = string.match(difname,"[%w]+") and string.match(difname,"[%w]+") or "empty"
if not post_helper.isFeatureEnabled("broadBandModalTI", role) then
  notationintf = 1
end
if string.match(difname, "%.") then
  difname = string.match(difname, "[%w]+")
end

local intf_state
local intf_state_map = {
  disabled = T"VLAN disabled",
  connected = T"VLAN enabled",
  disconnected = T"VLAN not connected"
}
local intf_light_map = {
  disabled = "off",
  disconnected = "red",
  connected = "green",
}

intf_state = difname ~= "" and "connected" or "disabled"

local wan = {
  iface = string.format("uci.network.interface.@%s.ifname", wanIntf)
}
content_helper.getExactContent(wan)

local iface = string.match(wan.iface, "([^%.]+)")
local vVLANID = post_helper.getValidateNumberInRange(0,4095)
local intf_vlan
local intf_vlanid

local mapValid = {
  intf_vlanid = function(value, object, key)
    intf_vlan = ngx.req.get_post_args().intf_vlan
    intf_vlanid = value
    if intf_vlan == "1" then
      local res, help = vVLANID(value)
      if not res then
        return res, help
      end
      object.intf_vlanid = iface .. '.' .. value
    else
      object.intf_vlanid = iface
    end
    return true
  end,
}

local mapParams = {
  intf_vlanid = string.format("uci.network.interface.@%s.ifname", wanIntf)
}
local content = {}

if not post_helper.isFeatureEnabled("broadBandModalTI", role) then
  content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
  local vid = string.match(content.intf_vlanid, "%.(%d+)$")
  content.intf_vlan = vid and "1" or "0"
  content.intf_vlanid = intf_vlanid or vid
end
  ngx.print('\
\
<fieldset>\
  ');  
    if (role ~= "admin" and post_helper.isFeatureEnabled("broadBandModalView", role)) or not post_helper.isFeatureEnabled("broadBandModalPVC", role) then   ngx.print('\
      <legend>');  ngx.print( T"Internet channel" ); ngx.print('</legend>\
     ');  local liste = {
        {"devnot", "Device"},
        {"dotnot", "Dot"}
      }
      local html = {}
      local vlanswitchclass = {
        input = {
          class = "monitor-changes"
        },
        values = {on = notationintf, off = ""}
      }

      local vlanidclass = {
        group = {
          class = string.format("monitor-intf_vlan monitor-%s", notationintf)
        }
      }

    if role ~= "admin" then
      if post_helper.isFeatureEnabled("broadBandModalTI", role) then
        html[#html + 1] = ui_helper.createSwitch(T"Using VLAN", "intf_vlan", difname, vlanswitchclass)
        if role == "engineer" then
          html[#html + 1] = ui_helper.createInputRadio(T"Notation", "auswahlliste" , liste, check, vlanidclass)
        end
        html[#html + 1] = ui_helper.createInputText(T"VLAN ID", "intf_vlanid", vid, vlanidclass, helpmes)
      else
        vlanswitchclass.values = {}
        html[#html + 1] = ui_helper.createSwitch(T"Using VLAN", "intf_vlan", content["intf_vlan"], vlanswitchclass)
        html[#html + 1] = ui_helper.createInputText(T"VLAN ID", "intf_vlanid", content["intf_vlanid"], vlanidclass, helpmes)
      end
    else
      html[#html + 1] = ui_helper.createLight(T"Using VLAN", nil, intf_state_map[intf_state], { light = { class = intf_light_map[intf_state] } })
      html[#html + 1] = ui_helper.createLabel(T"VLAN ID", vid, vlanidclass)
    end
    ngx.print(html)
  end
    ngx.print('\
</fieldset>\
'); 