--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lfs = require("lfs")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local firstPage = "/modals/diagnostics-connection-modal.lp"
local session = ngx.ctx.session
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local role = session:getrole()
local wanIntf = post_helper.getActiveInterface()

if session:hasAccess(firstPage) and
  session:hasAccess("/modals/diagnostics-xdsl-modal.lp") and
  session:hasAccess("/modals/diagnostics-ping-modal.lp") and
  session:hasAccess("/modals/diagnostics-network-modal.lp") and not session:isdefaultuser()
  then

local xdsl_exist = false
if lfs.attributes("/etc/config/xdsl", "mode") == "file" then
  xdsl_exist = true
end

local isExtender = false
local prod_name = proxy.get("uci.version.version.@version[0].product")
prod_name = prod_name and prod_name[1].value
if prod_name and prod_name:match(".*_extender.*") then
  isExtender = true
end

  ngx.print('\
\
<div class = "span3">\
  <div class = "smallcard">\
\
    ');  
      local eth4_data = {
	eth4_status = "sys.eth.port.@eth4.status",
	intf_name = string.format("uci.network.interface.@%s.ifname", wanIntf)
      }
        content_helper.getExactContent(eth4_data)
        local eth4Intf = string.match(eth4_data["intf_name"], "eth4") or ""
        if eth4Intf == "" then
          local dev_name = "uci.network.device.@"..eth4_data["intf_name"]..".ifname"
          eth4Intf = proxy.get(dev_name) and proxy.get(dev_name)[1] and proxy.get(dev_name)[1].value or ""
        end
        ngx.print(ui_helper.createCardHeader(T"Diagnostics", (xdsl_exist and (eth4Intf ~= "eth4" and eth4_data["eth4_status"] ~= "up")) and "modals/diagnostics-xdsl-modal.lp" or not isExtender and "modals/diagnostics-connection-modal.lp" or "modals/diagnostics-ping-modal.lp"))
      ngx.print('\
      ');  if not post_helper.isFeatureEnabled("style", role) then   ngx.print('\
        <div class = "content card_bg" data-bg-text="&#xf0e4;">\
        <table align = "center" cellspacing = "10%" cellpadding = "10%" class="diagnostic_card_table">\
          <tr>\
          ');  if not isExtender then   ngx.print('\
            <td><div data-toggle="modal" data-remote="modals/diagnostics-connection-modal.lp" data-id="diagnostics-connection-modal"><img href="#" rel="tooltip" data-original-title="CONNECTION" src="/img/connection-established.png" alt="connection"></div></td>\
          ');  end   ngx.print('\
          <td><div data-toggle="modal" data-remote="modals/diagnostics-network-modal.lp" data-id="diagnostics-network-modal"><img href="#" rel="tooltip" data-original-title="NETWORK" src="/img/network_sans-32.png" alt="network"></div></td></tr>\
        </table>\
      ');  else   ngx.print('\
        <div class = "content">\
        <table align = "center" cellspacing = "10%" cellpadding = "10%" class="diagnostic_card_table">\
	  ');  if xdsl_exist and eth4Intf ~= "eth4" then   ngx.print('\
            <tr>\
            <td><div data-toggle = "modal" data-remote = "modals/diagnostics-xdsl-modal.lp" data-id = "diagnostics-xdsl-modal"><img  href = "#" rel = "tooltip" data-original-title = "XDSL" src = "/img/bandwidth-px-png.png" alt = "dsl"></div></td>\
          ');  end   ngx.print('\
            <td><div data-toggle = "modal" data-remote = "modals/diagnostics-ping-modal.lp" data-id = "diagnostics-ping-modal"><img href = "#" rel = "tooltip" data-original-title = "PING" src = "/img/pocket-32-black.png" alt = "ping/trace"></div></td></tr>\
            <tr>\
            ');  if not isExtender then   ngx.print('\
              <td><div data-toggle = "modal" data-remote = "modals/diagnostics-connection-modal.lp" data-id = "diagnostics-connection-modal"><img href = "#" rel = "tooltip" data-original-title = "CONNECTION" src = "/img/connection-established.png" alt = "connection"></div></td>\
            ');  end   ngx.print('\
            <td><div data-toggle = "modal" data-remote = "modals/diagnostics-network-modal.lp" data-id = "diagnostics-network-modal"><img href = "#" rel = "tooltip" data-original-title = "NETWORK" src = "/img/network_sans-32.png" alt = "network"></div></td></tr>\
        </table>\
      ');  end   ngx.print('\
    </div>\
  </div>\
</div>\
');  end   ngx.print('\
'); 