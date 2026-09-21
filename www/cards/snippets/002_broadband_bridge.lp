--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format, match = string.format, string.match
local floor = math.floor
local tonumber = tonumber

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local bridged = require("bridgedmode_helper")
local wanIntf = post_helper.getActiveInterface()
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Broadband", "card")
local proxy = require("datamodel")

if post_helper.getVariantValue(variantHelper, "bridgedMode") then
  wanIntf = "lan"
end

local wan = {
  iface = format("uci.network.interface.@%s.ifname", wanIntf)
}

if not post_helper.getVariantValue(variantHelper, "bridgedMode") then
  wan.brigeMode_enabled = "rpc.network.dmz.enabled"
  content_helper.getExactContent(wan)
else
  content_helper.getExactContent(wan)
  wan.brigeMode_enabled = bridged.isBridgedMode() and "1" or "0"
end

-- Figure out interface state
local intf_state_map = {
  disabled = T"Bridge disabled",
  connected = T"Bridge connected",
  disconnected = T"Bridge not connected",
}

local intf_light_map = {
  disabled = "off",
  disconnected = "red",
  connected = "green",
}
local intf_state = "disabled"

for v in string.gmatch(wan.iface, "[^%s]+") do
  -- Here we just try to remove the potential vlan id from the interface name.
  local iface = string.match(v, "([^%.]+)")
  iface = iface:untaint()
  local stats = {
    operstate = "sys.class.net.@" .. iface .. ".operstate",
    carrier = "sys.class.net.@" .. iface .. ".carrier",
  }
  content_helper.getExactContent(stats)

  if stats.operstate == "up" then
    if stats.carrier ~= "0" then
      intf_state = "connected"
    else
      intf_state = intf_state ~= "connected" and "disconnected"
    end
  end
end

local xdsl_data = {}
local other_line_xdsl_data = {}
local dsl_switch_params = {}
local dsl_switch_valid = {}
local dsl_switch_data, dsl_switch_helpmsg

local dslSupport = proxy.getPN("sys.class.xdsl.", true)
-- xdsl data
if dslSupport and next(dslSupport) then
  xdsl_data = {
    dsl_status = "sys.class.xdsl.@line0.Status",
    dsl_linerate_up = "sys.class.xdsl.@line0.UpstreamCurrRate",
    dsl_linerate_down = "sys.class.xdsl.@line0.DownstreamCurrRate",
  }
  content_helper.getExactContent(xdsl_data)

  other_line_xdsl_data = {
    dsl_status = "sys.class.xdsl.@line1.Status",
    dsl_linerate_up = "sys.class.xdsl.@line1.UpstreamCurrRate",
    dsl_linerate_down = "sys.class.xdsl.@line1.DownstreamCurrRate",
  }
  content_helper.getExactContent(other_line_xdsl_data)

  -- DSL enable switch
  dsl_switch_params = {
    dsl_enable = "sys.class.xdsl.@line0.Enable",
  }
  dsl_switch_valid = {
    dsl_enable = post_helper.validateBoolean,
  }
  dsl_switch_data, dsl_switch_helpmsg = post_helper.handleQuery(dsl_switch_params, dsl_switch_valid)
end

local session = ngx.ctx.session

local switchName = nil
local modalPath = nil

local bridgedMode = false
if wan.brigeMode_enabled == "1" or bridged.isBridgedMode() then
  bridgedMode = true
end

local file_path = "modals/"..(not bridgedMode and "broadband-modal.lp" or "broadband-bridge-modal.lp")
if session:hasAccess("/"..file_path) then
     modalPath = file_path
end
if session:hasAccess("/modals/admin_broadband-modal.lp") then
  modalPath = "modals/admin_broadband-modal.lp"
end

  ngx.print('\
\
');  ngx.print( ui_helper.createCardHeader(T"Broadband", modalPath, switchName, dsl_switch_data and dsl_switch_data["dsl_enable"]) ); ngx.print('\
');  if post_helper.isFeatureEnabled("noCardBackgroundIcons", role) then   ngx.print('\
  <div class="content">\
');  else   ngx.print('\
  <div class="content card_bg" data-bg-text="&#xf0ac;">\
');  end  ngx.print('\
');  
  local iconUp = "<i id=\"Line_Rate_Up\" class=\"icon-upload icon-small gray\"></i> "
  local iconDown = " <i id=\"Line_Rate_Down\" class=\"icon-download icon-small gray\"></i> "
  local html = {}
  html[#html+1] = ui_helper.createSimpleLight(nil, intf_state_map[intf_state], {light = {class = intf_light_map[intf_state]}})
  if not post_helper.getVariantValue(variantHelper, "hideBridgeInterface") then
    html[#html+1] = "<p class=\"subinfos bridge-interface\">"
    html[#html+1] = format(T'Interfaces:<strong>%s</strong>', wan.iface)
    html[#html+1] = '</p>'
  end
  ngx.print(html)
  if (xdsl_data and xdsl_data["dsl_status"] == "Up") or (other_line_xdsl_data and other_line_xdsl_data["dsl_status"] == "Up") then
    ngx.print(
      "<div class=\"light green\" id=\"Broadband_LED\"></div><p id=\"Broadband_Status_Id\">",
      T"Connected",
      "</p>"
    )
    -- After disabling broadband the page immediately refreshes. At this time the state is still up but the line
    -- rate is already cleared.
    local rate_up = tonumber(xdsl_data["dsl_linerate_up"])
    local rate_down = tonumber(xdsl_data["dsl_linerate_down"])
    local other_line_rate_up = tonumber(other_line_xdsl_data["dsl_linerate_up"])
    local other_line_rate_down = tonumber(other_line_xdsl_data["dsl_linerate_down"])

    if (rate_up and rate_down) or (other_line_rate_up and other_line_rate_down) then
      if rate_up and rate_down then
        rate_up = floor(rate_up / 10) / 100
        rate_down = floor(rate_down / 10) / 100
      else
        rate_up = 0
        rate_down = 0
      end
      if other_line_rate_up and other_line_rate_down then
        rate_up = rate_up + (floor(other_line_rate_up / 10) / 100)
        rate_down = rate_down + (floor(other_line_rate_down / 10) / 100)
      end
      ngx.print(
        "<p  class=\"subinfos subinfosBroadband\">&emsp; ",
        iconUp,
        format("%.2f Mbps", rate_up),
        iconDown,
        format('%.2f Mbps', rate_down),
        "</p>"
      )
    end
  elseif xdsl_data and xdsl_data["dsl_status"] == "NoSignal" and other_line_xdsl_data and other_line_xdsl_data["dsl_status"] == "NoSignal" then
    ngx.print(
      "<div class=\"light red\" id=\"Broadband_LED\"></div><p>",
      T"Disconnected",
      "</p>"
    )
  elseif xdsl_data and xdsl_data["dsl_status"] == "Unknown" then
    ngx.print(
      "<div class=\"light orange\" id=\"Broadband_LED\"></div><p>",
      T"Connecting",
      "</p>"
    )
  end
  ngx.print('\
\
</div>\
'); 