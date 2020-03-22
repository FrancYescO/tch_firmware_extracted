--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local ipairs = ipairs
local match, format = string.match, string.format

local ports = {"eth0", "eth1", "eth2", "eth3"}
local first_column_txt = {"Port 1", "Port 2", "Port 3", "Port 4"}

local post_content
if ngx.var.request_method == "POST" then
    post_content = ngx.req.get_post_args()
    local base_path
    if post_content["stats_reset"] == "RESET" then
      local resetPorts = {"eth0", "eth1", "eth2", "eth3","eth4","wl0","wl1","pppoe-wan"}
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

local isEth4Included = false
if proxy.getPN("sys.class.net.@eth4.", true) then
    ports[#ports+1] = "eth4"
    first_column_txt[#first_column_txt+1] = "Port 5"
    isEth4Included = true
end

local eth = {}
for k,v in ipairs(ports) do
    local base_path = "sys.class.net.@" .. v
    eth["op" .. v] = base_path .. ".operstate"
    eth["sp" .. v] = base_path .. ".speed"
end
content_helper.getExactContent(eth)

local ports_speed = {}
local speed = proxy.get("sys.eth.port.")
for _,f in ipairs(speed) do
  if f["param"] == "speed"  and f["value"] ~= "" then
     ports_speed [match(f["path"], "sys.eth.port.@(eth%d)")] = f["value"]
  end
end

local portAttr = {
    socket = {
        class = "socket-form"
    }
}
  ngx.print('\
');  ngx.print(ui_helper.createHeader(T"Diagnostics", false, false, 2) ); ngx.print('\
<div class="modal-body update">\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-diagnostics.lp")
  ngx.print('\
');  
-- dummy form so that refresh button knows which page to reload, keep it
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/diagnostics-network-modal.lp">\
  </form>\
  <fieldset id="diagnostics-network-tab">\
    <legend>');  ngx.print( T"Ports State" ); ngx.print('</legend>\
    <div class="control-group">\
      <label class="control-label">');  ngx.print( T"Type supported" ); ngx.print('</label>\
      <div class="controls">\
        ');  for k,v in ipairs(ports) do  ngx.print('\
          <div class="span2 simple-desc">\
          ');  
            if isEth4Included and k == #ports then
              portAttr.socket.class = "red socket-form"
            end
            ngx.print(ui_helper.createSwitchPort(tostring(k), eth["op" .. v], eth["sp" .. v], portAttr))
            -- todo replace speed with actual speed
            if eth["op" .. v] == "up" then
            ngx.print('\
              <p class="socket-legend" id = "');  ngx.print(v); ngx.print('">');  ngx.print( T"Connected" ); ngx.print('<p>\
              ');  if(ports_speed[v]) then  ngx.print('\
                <p class="socket-legend">(');  ngx.print( format(T"%s Mbps", ports_speed[v]) ); ngx.print(')</legend>\
              ');  end   ngx.print('\
            ');  else   ngx.print('\
              <p class="socket-legend grayLight" id = "');  ngx.print(v); ngx.print('">');  ngx.print( T"Not connected" ); ngx.print('<p>\
            ');  end   ngx.print('\
          </div>\
        ');  end   ngx.print('\
      </div>\
    </div>\
    <legend>');  ngx.print( T"Network Statistics" ); ngx.print('</legend>\
    ');  
    if proxy.getPN("rpc.wireless.ssid.@wl0.", true) then
      ports[#ports+1] = "wl0"
      first_column_txt[#first_column_txt+1] = "WiFi-2.4Ghz"
    end
    if proxy.getPN("rpc.wireless.ssid.@wl1.", true) then
      ports[#ports+1] = "wl1"
      first_column_txt[#first_column_txt+1] = "WiFi-5Ghz"
    end
    if proxy.get("sys.class.net.@pppoe-wan.") then
      ports[#ports+1] = "pppoe-wan"
      first_column_txt[#first_column_txt+1] = "Wan"
    end
    local base_path
    local param = {"rx_bytes", "rx_bytes", "tx_bytes", "rx_packets", "tx_packets", "rx_errors", "tx_errors"}
    local datarows ={}
    for k,v in ipairs(ports) do
      datarows[k]={}
      if v == "wl1" or v == "wl0" then
         base_path = "rpc.wireless.ssid.@" .. v ..".stats."
      else
         base_path = "sys.class.net.@" .. v .. ".statistics."
      end
      for kk,vv in ipairs(param) do
        datarows[k][kk] = base_path .. vv
      end
      content_helper.getExactContent(datarows[k])
    end

    --re-write the first column
    for k,v in ipairs(first_column_txt) do
      datarows[k][1] = v
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
    ngx.print(ui_helper.createTable(columns, datarows, options))
      ngx.print('\
    <center>\
      ');  ngx.print( ui_helper.createSimpleButton(T"Reset Stats", "icon-bolt", clear_network_stats)); ngx.print('\
    </center>\
  </fieldset>\
</div>\
');  ngx.print(ui_helper.createFooter() ); ngx.print('\
'); 