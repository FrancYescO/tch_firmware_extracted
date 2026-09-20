--pretranslated: do not change this file

--[[
   Check Page - Netlynk to check software and config 
   A:David Relf
   E:david.relf@technicolor.com
   
   
   V1.0 - Initial version with Change control
]]
local format, match, sub= string.format, string.match, string.sub
local print= ngx.print
-- Enable localization
gettext.textdomain('webui-core')
local proxy = require("datamodel")

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local httpilua = require("httpi_info_data")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")

local content, JSON = nil,{}
function split(x, sep)
        local sep, fields = sep or ":", {}
        local pattern = format("([^%s]+)", sep)
        x:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

local args = ngx.req.get_uri_args()
for key, val in pairs(args) do
  if key=="dsl" then 
    content = "dsl" 
  elseif key=="eth" then 
    content = "eth" 
  elseif key=="WS" then
    content = "WS"
  elseif key=="ppp" then
    content = "PPP"
  elseif key=="dhcp" then
    content = "DHCP"
  end 
end

--Default Output for Netlynk----------------------------------------------------
if not content then
      local cui = {
          nsplink    = "uci.web.uiconfig.@uidefault.nsplink",
          advanced   = "uci.web.uiconfig.@uidefault.alwaysadvanced",
          version    = "uci.version.version.@version[0].version",
          eth_mac    = "uci.env.rip.eth_mac",
          wli_mac    = "uci.env.rip.wifi_mac",
      }
      content_helper.getExactContent(cui)
      
      local content = {
            isp_present = "sys.ispconfig.Present",
      }
      
      content_helper.getExactContent(content)
      
      local version = ""
      local tmpsplit = split(cui.version, "-")
      if #tmpsplit > 1 then
         version = format("%s-%s-%s",tmpsplit[1],tmpsplit[2],tmpsplit[3])
      end
      
      
      JSON = {FWVersion = version, ETH_MAC = cui.eth_mac,WIFI_MAC = cui.wli_mac, ISPConfig = content.isp_present}
--------------------------------------------------------------------------------
elseif content == "dsl" then
--Output for xDSL---------------------------------------------------------------
      local OLD_DSL = args["old_dsl"] or ""
      local getdata = proxy.get("sys.class.xdsl.@line0.Status","sys.class.xdsl.@line0.UpstreamCurrRate","sys.class.xdsl.@line0.DownstreamCurrRate")
      local dsl_status = getdata[1].value or ""
      local dsl_up = getdata[2].value or ""
      local dsl_down = getdata[3].value or ""JSON = {DSL = dsl_status, OLD_DSL = OLD_DSL, DOWN = dsl_down, UP = dsl_up}
--------------------------------------------------------------------------------
elseif content == "eth" then
--Output for ETH----------------------------------------------------------------
      local OLD_ETH = args["old_eth"] or ""
      local getdata = proxy.get("sys.eth.port.@eth4.status","sys.eth.port.@eth4.mode","sys.eth.port.@eth4.speed")
      local eth_status = getdata[1].value 
      local eth_mode = getdata[2].value or ""
      local eth_speed = getdata[3].value or ""
      JSON = {ETH = eth_status, OLD_ETH = OLD_ETH, ETH_MODE = eth_mode, ETH_SPEED = eth_speed}
--------------------------------------------------------------------------------
elseif content == "WS" then
--Output for WS-----------------------------------------------------------------
      local OLD_L2 = args["old_L2"] or ""
      local L2 = proxy.get("uci.wansensing.global.l2type")[1].value or ""
      JSON = {L2 = L2, OLD_L2 = OLD_L2}
--------------------------------------------------------------------------------
elseif content == "PPP" then
--Output for PPP-----------------------------------------------------------------
      local OLD_PPP = args["old_ppp"] or ""
      local ip6prefix_path = "rpc.network.interface.@wan6.ip6prefix"
      for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
        local intf = string.match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
        if intf then
          if intf == "6rd" then
            ip6prefix_path = "rpc.network.interface.@6rd.ip6prefix"
          end
        end
      end
      local getdata = proxy.get("rpc.network.interface.@wan.ppp.state","rpc.network.interface.@wan.ppp.error","uci.network.interface.@wan.auto","rpc.network.interface.@wan.ipaddr","uci.network.interface.@wan.ipv6",ip6prefix_path)
      local PPP = getdata[1].value or ""
      local PPP_ERROR = getdata[2].value or ""
      local PPP_AUTO = getdata[3].value or ""
      local PPP_IP = getdata[4].value or ""
      local PPP_IPv6 = getdata[5].value or ""
      local PPP_IPv6PREFIX = getdata[6].value or ""
      JSON = {PPP = PPP, OLD_PPP = OLD_PPP, PPP_ERROR = PPP_ERROR, PPP_AUTO = PPP_AUTO, PPP_IP = PPP_IP, PPP_IPv6 = PPP_IPv6, PPP_IPv6PREFIX = PPP_IPv6PREFIX}
--------------------------------------------------------------------------------
elseif content == "DHCP" then
--Output for DHCP-----------------------------------------------------------------
      local ip6prefix_path = "rpc.network.interface.@wan6.ip6prefix"
      for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
        local intf = string.match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
        if intf then
          if intf == "6rd" then
            ip6prefix_path = "rpc.network.interface.@6rd.ip6prefix"
          end
        end
      end
      local OLD_DHCP = args["old_dhcp"] or ""
      local getdata = proxy.get("uci.network.interface.@wan.auto","rpc.network.interface.@wan.ipaddr","uci.network.interface.@wan.ipv6",ip6prefix_path)
      local DHCP_AUTO = getdata[1].value or ""
      local DHCP = getdata[2].value or ""
      local DHCP_IPv6 = getdata[3].value or ""
      local DHCP_IPv6PREFIX = getdata[4].value or ""
      JSON = {DHCP = DHCP, OLD_DHCP = OLD_DHCP, DHCP_AUTO = DHCP_AUTO, DHCP_IPv6 = DHCP_IPv6, DHCP_IPv6PREFIX = DHCP_IPv6PREFIX}
--------------------------------------------------------------------------------
end
  local html = {}
  for k,v in pairs(JSON) do 
      html[#html+1] = format("\"%s\":\"%s\"",k,v) 
      html[#html+1] = ","
  end
  table.remove(html, #html)
  ngx.print('{', html, '}')
