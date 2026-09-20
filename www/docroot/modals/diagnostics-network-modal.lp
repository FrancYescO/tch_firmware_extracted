--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local ipairs = ipairs
local match, format = string.match, string.format

local ports = {}
local ports_name = {}
local ports_speed = {}
local remote_wlan_port

local check_wlan_remote = {
  port = "uci.ethernet.mapping.@mapping[0].port",
  is_enabled = "uci.ethernet.mapping.@mapping[0].wlan_remote"
}
content_helper.getExactContent(check_wlan_remote)

if check_wlan_remote.is_enabled == "1" then
  remote_wlan_port = check_wlan_remote.port
end

local is_gpon = false
local gpon_params = {
  sfp_enabled = "uci.env.rip.sfp",
}

content_helper.getExactContent(gpon_params)
if gpon_params["sfp_enabled"] == "1" then
   is_gpon = true
end
    
-- read the eth interfaces through "sys.eth.port" and update the "ports" and "ports_name" variable
-- if the interface is up, update the corresponding port's speed information as well
local ethifs = proxy.get("sys.eth.port.")
for k,v in ipairs(ethifs) do
  if v["param"] == "speed" then
     local iface = match(v["path"], "sys.eth.port.@(eth%d)") or match(v["path"], "sys.eth.port.@(moca%d)")
     if iface ~= remote_wlan_port or iface ~= "eth5" then
       ports[#ports+1] = iface
       if iface == "eth4" then
        ports_name[#ports_name+1] = T"WAN Port"
       else
        ports_name[#ports_name+1] = format(T"Port %d", #ports_name+1)
       end
       if v["value"] ~= "" then
         ports_speed [iface] = v["value"]
       end
     end
  end
end

-- reading the eth interfaces through "sys.eth.port" will not be in ascending order
table.sort(ports)

local post_content
if ngx.var.request_method == "POST" then
    post_content = ngx.req.get_post_args()
    local base_path
    if post_content["stats_reset"] == "RESET" then
      local resetPorts = {"eth0", "eth1", "eth2", "eth3","eth4","wl0","wl1"}
       local setTable = {}
       for _, v in ipairs(resetPorts) do
           if v == "wl0" or v == "wl1" then
               setTable[format("rpc.wireless.ssid.@%s.stats.reset", v)] = "1"
           else
               setTable[format("sys.class.net.@%s.statistics.reset", v)] = "1"
           end
       end
       if proxy.set(setTable) then
          proxy.apply()
       end
    end
end

-- resetting traffic counters button
local clear_network_stats = {
    controls = {
      class = "clear_network_stats"
    },
    button = {
      ["data-name"] = "stats_reset",
      ["data-value"] = "RESET"
    }
}

local wan_info = {}
for i,v in ipairs(ports) do
  local base_path = "uci.ethernet.port.@"
  wan_info[i] = base_path .. v .. ".wan"
end
wan_info = proxy.get(wan_info)

local eth = {}
for i,v in ipairs(ports) do
    local base_path = "sys.class.net.@" .. v
    eth["op" .. v] = base_path .. ".operstate"
    eth["sp" .. v] = base_path .. ".speed"
end
content_helper.getExactContent(eth)

local portAttr = {
    socket = {
        class = "socket-form"
    }
}
ngx.print(ui_helper.createHeader(T"Diagnostics", false, false, 2), '\
<div class="modal-body update">');
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-diagnostics.lp")

-- dummy form so that refresh button knows which page to reload, keep it
ngx.print('\
  <form class="form-horizontal" method="post" action="modals/diagnostics-network-modal.lp">\
  </form>\
  <fieldset id="diagnostics-network-tab">\
    <legend>', T"Ports State", '</legend>\
    <div class="control-group">\
      <div class="controls">');
        for i,v in ipairs(ports) do
		ngx.print('<div class="span2 simple-desc">');
            if wan_info[i].value == "1" then
              portAttr.socket.class = "red socket-form"
            else
              portAttr.socket.class = "yellow socket-form"
            end
            local port_ref = i
            if i == 5 then
              port_ref = "WAN"
            end
            ngx.print(ui_helper.createSwitchPort(tostring(port_ref), eth["op" .. v], eth["sp" .. v], portAttr))
            -- todo replace speed with actual speed
            if eth["op" .. v] == "up" then
            ngx.print('\
              <p class="socket-legend" id = "', v, '">', T"Connected", '<p>');
              if(ports_speed[v]) then
                ngx.print('<p class="socket-legend">(', format(T"%s Mbps", ports_speed[v]), ')</legend>');
              end
            else
              ngx.print('<p class="socket-legend grayLight" id = "', v, '">', T"Not connected", '<p>');
            end
          ngx.print('</div>');
        end
      ngx.print('</div>\
    </div>\
    </fieldset>\
    <fieldset id="diagnostics-network-tab-2">\
    <legend>', T"Network Statistics", '</legend>');
    if proxy.getPN("rpc.wireless.ssid.@wl0.", true) then
      ports[#ports+1] = "wl0"
      ports_name[#ports_name+1] = "WiFi-2.4Ghz"
    end
    if proxy.getPN("rpc.wireless.ssid.@wl1.", true) then
      ports[#ports+1] = "wl1"
      ports_name[#ports_name+1] = "WiFi-5Ghz"
    end
    if is_gpon then
      if proxy.getPN("rpc.optical.Interface.1.Stats.", true) then
        ports[#ports+1] = "gpon"
        ports_name[#ports_name+1] = "GPON"
      end
    end
    local base_path
    local param = {"rx_bytes", "rx_bytes", "tx_bytes", "rx_packets", "tx_packets", "rx_errors", "tx_errors"}
    local gpon_param = {"BytesReceived", "BytesReceived", "BytesSent", "PacketsReceived", "PacketsSent", "ErrorsReceived", "ErrorsSent"}
    local datarows ={}
    for i,v in ipairs(ports) do
      datarows[i]={}
      if v == "wl1" or v == "wl0" then
         base_path = "rpc.wireless.ssid.@" .. v ..".stats."
      elseif v == "gpon" then
         base_path = "rpc.optical.Interface.1.Stats."
      else
         base_path = "sys.class.net.@" .. v .. ".statistics."
      end
      if v == "gpon" then
        for kk,vv in ipairs(gpon_param) do
          datarows[i][kk] = base_path .. vv
        end
      else
        for kk,vv in ipairs(param) do
          datarows[i][kk] = base_path .. vv
        end
      end
      content_helper.getExactContent(datarows[i])
    end


    --re-write the first column
    for i,v in ipairs(ports_name) do
      datarows[i][1] = v
    end

    local full_array={}
    for i=1, 7 do
      full_array[i]={}
        for z=1, 7 do
          full_array[i][z]="data"..z
        end
     end

    --Column Names
    local columns ={}
    for i=1, 7 do
       columns[i]={}
    end
    columns[1]["header"] = T"Interface"
    columns[2]["header"] = T"Rx Bytes"
    columns[3]["header"] = T"Tx Bytes"
    columns[4]["header"] = T"Rx Packets"
    columns[5]["header"] = T"Tx Packets"
    columns[6]["header"] = T"Rx Errors"
    columns[7]["header"] = T"Tx Errors"
    local options = { tableid = "networkstats", canEdit = false, canAdd = false, canDelete = false }
    -- table that shows the Statistics data
    ngx.print(ui_helper.createTable(columns, datarows, options), '\
    <center>',
      ui_helper.createSimpleButton(T"Reset Stats", "icon-bolt", clear_network_stats), '\
    </center>\
  </fieldset>\
</div>',
ui_helper.createFooter()); 