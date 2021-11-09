--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local ipairs = ipairs
local match, format = string.match, string.format
local post_helper = require("web.post_helper")
local session = ngx.ctx.session
local role = session:getrole()
local ports_speed = {}
local ports = {}
local ports_name = {}
local remote_wlan_port
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Diagnostics", "networkPage")
local wireless_index = {}
local check_wlan_remote = {
  port = "uci.ethernet.mapping.@mapping[0].port",
  is_enabled = "uci.ethernet.mapping.@mapping[0].wlan_remote"
}
content_helper.getExactContent(check_wlan_remote)
if check_wlan_remote.is_enabled == "1" then
  remote_wlan_port = check_wlan_remote.port
end

for _, v in ipairs(proxy.getPN("rpc.wireless.ssid.", true)) do
  local wireless_ssid = match(v.path, ".*@([^%.]+)%.")
  if wireless_ssid then
    wireless_index[#wireless_index + 1] = wireless_ssid
  end
end

local is_gpon = false
local gpon_params = {
  sfp_enabled = "uci.env.rip.sfp",
  gpon_state = "rpc.optical.link.SfpLinkStatus"
}

content_helper.getExactContent(gpon_params)
if gpon_params["sfp_enabled"] == "1" then
  is_gpon = true
end

-- read the eth interfaces through "sys.eth.port" and update the "ports" and "ports_name" variable
-- if the interface is up, update the corresponding port's speed information as well
local ethifs = proxy.get("sys.eth.port.")
local lanwanmode_supported = proxy.get("rpc.Ethernet.X_000E50_Eth4lanwanmode") and proxy.get("rpc.Ethernet.X_000E50_Eth4lanwanmode")[1] and proxy.get("rpc.Ethernet.X_000E50_Eth4lanwanmode")[1].value or ""

for _, ethernetValue in ipairs(ethifs) do
  if ethernetValue["param"] == "speed" then
    local iface = match(ethernetValue["path"], "sys.eth.port.@(eth%d)") or match(ethernetValue["path"], "sys.eth.port.@(moca%d)")
    if iface ~= remote_wlan_port then
      -- Add all the available ethernet ports to be reset
      wireless_index[#wireless_index + 1] = iface
      if lanwanmode_supported ~= "0"  or  ( lanwanmode_supported == "0" and iface ~= "eth3" ) or proxy.get("uci.qos.device.@eth3.classgroup")[1].value ~= "TO_WAN" then
	ports[#ports+1] = iface
        ports_name[#ports_name+1] = format(T"Port %d", #ports_name+1)
        if ethernetValue["value"] ~= "" then
          ports_speed [iface] = ethernetValue["value"]
        end
        if lanwanmode_supported == "1" and iface == "eth3" then break end
      end
    end
  end
end

-- reading the eth interfaces through "sys.eth.port" will not be in ascending order
table.sort(ports)

local post_content
if ngx.var.request_method == "POST" then
  post_content = ngx.req.get_post_args()
  if post_content["stats_reset"] == "RESET" then
    local setTable = {}
    for _, portsValue in ipairs(wireless_index) do
      if string.match(portsValue, "^wl") then
        setTable[format("rpc.wireless.ssid.@%s.stats.reset", portsValue)] = "1"
      else
        setTable[format("sys.class.net.@%s.statistics.reset", portsValue)] = "1"
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
for wanPorts, wanPortsValue in ipairs(ports) do
  local base_path = "uci.ethernet.port.@"
  wan_info[wanPorts] = base_path .. wanPortsValue .. ".wan"
end
wan_info = proxy.get(wan_info)

local eth = {}
for _, portsValue in ipairs(ports) do
  local base_path = "sys.class.net.@" .. portsValue
  eth["op" .. portsValue] = base_path .. ".operstate"
  eth["sp" .. portsValue] = base_path .. ".speed"
end
content_helper.getExactContent(eth)

local wlan = {}
local wirelessStates = content_helper.convertResultToObject("sys.hosts.host.", proxy.get("sys.hosts.host."))
for interface, value in pairs(wirelessStates) do
  if value.InterfaceType == "wireless" and value.State == "1" then
    if value.L2Interface == "^wds" then
      if value.Radio == "radio_2G" then
        wlan["wl0"] = "connected"
      elseif value.Radio == "radio_5G" then
        wlan["wl1"] = "connected"
      end
    else
      wlan[string.untaint(value.L2Interface)] = "connected"
    end
  end
end


local function convertData(val)
  val = tonumber(val)
  if (val > 1024*1024*1024) then
    val = val/(1024*1024*1024)
    return format("%.2f", val) .. " GB"
  elseif (val > 1024*1024) then
    val = val/(1024*1024)
    return format("%.2f", val) .. " MB"
  elseif (val > 1024) then
    val = val/1024
    return format("%.2f", val) .. " kB"
  elseif (val > 0) then
    return val .. " B"
  end
  return val
end

local portAttr = {
  socket = {
    class = "socket-form"
  }
}
  ngx.print('\
');  ngx.print( ui_helper.createHeader(T"Diagnostics", false, false, 2) ); ngx.print('\
<div class = "modal-body update">\
  ');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-diagnostics.lp")
    ngx.print('\
  ');  
    -- dummy form so that refresh button knows which page to reload, keep it
    ngx.print('\
  <form class = "form-horizontal" method = "post" action = "modals/diagnostics-network-modal.lp">\
  </form>\
    <fieldset id = "diagnostics-network-tab">\
      <legend>');  ngx.print( T"Network Statistics" ); ngx.print('</legend>\
      ');  
      if post_helper.isFeatureEnabled("diagnosticsNetworkPortsList", role) then
        local wireless = proxy.get("rpc.wireless.ssid.")
        local wirelessindex = content_helper.convertResultToObject("rpc.wireless.ssid.@.",wireless)
        for _, wirelessList in ipairs(wirelessindex) do
          ports[#ports+1] = wirelessList.paramindex
          if string.match(wirelessList.paramindex, "wl0") then
            ports_name[#ports_name+1] = wirelessList.ssid.."(2.4GHz)"
          else
            ports_name[#ports_name+1] = wirelessList.ssid.."(5GHz)"
          end
        end
      else
        if proxy.getPN("rpc.wireless.ssid.@wl0.", true) then
          ports[#ports+1] = "wl0"
          ports_name[#ports_name+1] = "WiFi-2.4Ghz"
        end
        if proxy.getPN("rpc.wireless.ssid.@wl1.", true) then
          ports[#ports+1] = "wl1"
          ports_name[#ports_name+1] = "WiFi-5Ghz"
        end
      end
      if is_gpon then
        if proxy.getPN("rpc.optical.Interface.1.Stats.", true) then
          ports[#ports+1] = "gpon"
          ports_name[#ports_name+1] = "GPON"
        end
      end
      local base_path
      local param = {"rx_bytes", "rx_bytes", "rx_bytes", "rx_bytes", "tx_bytes", "rx_packets", "tx_packets", "rx_errors", "tx_errors"}
      local gpon_param = {"BytesReceived", "BytesReceived", "BytesReceived", "BytesReceived", "BytesSent", "PacketsReceived", "PacketsSent", "ErrorsReceived", "ErrorsSent"}
      local datarows = {}
      for networkStatcs, networkStatcsValue in ipairs(ports) do
        datarows[networkStatcs] = {}
        if string.match(networkStatcsValue, "^wl") then
          base_path = "rpc.wireless.ssid.@" .. networkStatcsValue ..".stats."
          elseif networkStatcsValue == "gpon" then
            base_path = "rpc.optical.Interface.1.Stats."
          else
            base_path = "sys.class.net.@" .. networkStatcsValue .. ".statistics."
          end
          if networkStatcsValue == "gpon" then
            for gponParam, gponParamValue in ipairs(gpon_param) do
              datarows[networkStatcs][gponParam] = base_path .. gponParamValue
            end
          else
            for params, paramsValue in ipairs(param) do
              datarows[networkStatcs][params] = base_path .. paramsValue
            end
          end
        content_helper.getExactContent(datarows[networkStatcs])
      end
      for row, col in ipairs(datarows) do
        datarows[row] = {}
        for index, val in pairs(col) do
          if index == 4 or index == 5 then
            datarows[row][index] = convertData(val)
          else
            datarows[row][index] = val
          end
        end
      end
      --re-write the first column
      for portsName, portsNameValue in ipairs(ports_name) do
        datarows[portsName][1] = portsNameValue
      end

      -- re-write the second and third column
      for portState, portStateValue in ipairs(ports) do
        if portState <= #wan_info then
          if wan_info[portState].value == "1" then
            portAttr.socket.class = "red socket-form"
          else
            portAttr.socket.class = "yellow socket-form"
          end
          datarows[portState][2] = ui_helper.createSwitchPort(tostring(portState), eth["op" .. portStateValue], eth["sp" .. portStateValue], portAttr)
        end
        if eth["op" .. portStateValue] == "up" then
          datarows[portState][3] = [[<p class="socket-legend" id =]].. portStateValue ..[[>]].. T"Connected"..[[<p> ]]
          if (ports_speed[portStateValue]) then
            datarows[portState][3] = datarows[portState][3]..[[<p class="socket-legend">]]..format(T"%s Mbps", ports_speed[portStateValue])
          end
        else
          datarows[portState][3] = [[ <p class="socket-legend grayLight" id =]]..portStateValue..[[>]]..T"Not connected"..[[<p>]]
        end
        if string.match(portStateValue, "^wl") then
          datarows[portState][2] = ""
          if wlan[portStateValue] == "connected" then
            datarows[portState][3] = [[<p class="socket-legend" id =]].. portStateValue ..[[>]].. T"Connected"..[[<p> ]]
          end
        end
        if is_gpon and portStateValue == "gpon" then
          datarows[portState][2] = [[<div id = "sfp-icon">
          <img src = "../img/SFP_new.png" alt = "SFP Icon" style = "width:10%"></img></div>]]
	   if gpon_params["gpon_state"] == "Up" then
             datarows[portState][3] = [[<p class="socket-legend" id =]].. portStateValue ..[[>]].. T"Connected"..[[<p> ]]
	   end
        end
      end

      for _, ethernetValue in ipairs(ethifs) do
        if match(ethernetValue["path"], "sys.eth.port.@(moca%d)") then
          datarows[9][2] = [[<div id = "sfp-icon">
          <img src = "../img/moca.png" alt = "SFP Icon" style = "width:10%"></img>
        </div>]]
        end
      end

      --Column Names
      local columns = {}
      for columnsValue = 1, 9 do
        columns[columnsValue] = {}
      end
        columns[1]["header"] = T"Interface"
        columns[2]["header"] = T"Ports State"
        columns[3]["header"] = T"Connected Status"
        columns[4]["header"] = T"Rx Bytes"
        columns[5]["header"] = T"Tx Bytes"
        columns[6]["header"] = T"Rx Packets"
        columns[7]["header"] = T"Tx Packets"
        columns[8]["header"] = T"Rx Errors"
        columns[9]["header"] = T"Tx Errors"
        local options = { tableid = "networkstats", canEdit = false, canAdd = false, canDelete = false }
        -- table that shows the Statistics data
        ngx.print(ui_helper.createTable(columns, datarows, options))
        ngx.print('\
      <center>\
        ');  ngx.print( ui_helper.createSimpleButton(T"Reset Stats", "icon-bolt", clear_network_stats)); ngx.print('\
      </center>\
  </fieldset>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 