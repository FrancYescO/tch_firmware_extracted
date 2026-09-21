local ngx = ngx
local format, find, gsub, gmatch, sub = string.format, string.find, string.gsub, string.gmatch,string.sub
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")

local M = {}

function M.createdatatable(data)
   for x = 1, #data do
      ngx.print(format('<div class="divtable"><span class="index_r span">%s</span><span class="title_r span">%s</span><span class="value_r span">%s</span></div><br/>', data[x][1], data[x][2], data[x][3]))
   end

  
end

function M.string2table(s)
   local t = {}
   for x = 1, s:len() do
      t[#t+1] = s:sub(x, x)
   end
   return t
end

function M.getInternetDetails(Type)
   if Type:sub(1 ,3) == "PPP" then 
       local content_uci = {
        wan_auto = "uci.network.interface.@wan.auto",
      }
      content_helper.getExactContent(content_uci)
      local content_rpc = {
        wan_ppp_state = "rpc.network.interface.@wan.ppp.state",
        wan_ppp_error = "rpc.network.interface.@wan.ppp.error",
        ipaddr = "rpc.network.interface.@wan.ipaddr",
      }
      content_helper.getExactContent(content_rpc)
      
      local ppp_state_map = {
          disabled = T"Disabled",
          disconnecting = T"Disconnecting",
          connected = T"Connected",
          connecting = T"Connecting",
          disconnected = T"Disconnected",
          error = T"Error",
          AUTH_TOPEER_FAILED = T"Authentication failed",
          NEGOTIATION_FAILED = T"Negotiation failed",
      }
      local ppp_light_map = {
          disabled = "off",
          disconnected = "red",
          disconnecting = "orange",
          connecting = "orange",
          connected = "green",
          error = "red",
          AUTH_TOPEER_FAILED = "red",
          NEGOTIATION_FAILED = "red",
      }
  
      
      local ppp_status
      if content_uci.wan_auto ~= "0" then
        -- WAN enabled
        content_uci.wan_auto = "1"
        ppp_status = format("%s", content_rpc.wan_ppp_state) -- untaint
        if ppp_status == "" then
          ppp_status = "connecting"
        end
      
        if not (content_rpc.wan_ppp_error == "" or content_rpc.wan_ppp_error == "USER_REQUEST") then
          if ppp_state_map[content_rpc.wan_ppp_error] then
              ppp_status = content_rpc.wan_ppp_error
          else
              ppp_status = "error"
          end
        end
      else
        -- WAN disabled
        ppp_status = "disabled"
      end
      return {  status = ppp_state_map[ppp_status], light = ppp_light_map[ppp_status],ip = content_rpc["ipaddr"]}
   elseif Type:sub(1 ,6) == "Bridge" then 
      return {  status = 1, light = "green",ip = ""}
   else
      local cs = {
      uci_wan_auto = "uci.network.interface.@wan.auto",
      ipaddr = "rpc.network.interface.@wan.ipaddr",
      }
    
      content_helper.getExactContent(cs)
      
      -- Figure out interface state
      local dhcp_state = "connecting"
      local dhcp_state_map = {
          disabled = T"Disabled",
          connected = T"On",
          connecting = T"Connecting",
      }
      
      local dhcp_light_map = {
        disabled = "off",
        connecting = "orange",
        connected = "green",
      }
      
      if cs["uci_wan_auto"] ~= "0" then
          cs["uci_wan_auto"] = "1"
          if cs["ipaddr"]:len() > 0 then
              dhcp_state = "connected"
          else
              dhcp_state = "connecting"
          end
      else
          dhcp_state = "disabled"
      end

      return { status = dhcp_state_map[dhcp_state],light = dhcp_light_map[dhcp_state], ip = cs["ipaddr"]}   
   end
end

return M