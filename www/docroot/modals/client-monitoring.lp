--pretranslated: do not change this file
 
-- Enable localization

gettext.textdomain('webui-core')
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local vdf_helper = require("vodafone_helper")
local post_helper = require("web.post_helper")
local ipairs, ngx, pairs, string, tonumber = ipairs, ngx, pairs, string, tonumber
local match, format  = string.match, string.format
local secondsToUptime = vdf_helper.secondsToUptime
local timeFormat = vdf_helper.timeFormat
local json = require("dkjson")

--Function to get values dynamically for the device chosen to monitor by iterate over access points and looking for the associated stations, uniquely identified via their MAC address
-- @function getDynamicValues
-- @param mac , mac address of the device selected for monitor
local function getDynamicValues(mac)
  local ssidPath, count =  "", 0
  local content = {}
  local basePath = "rpc.wireless.ap."
  local apPaths={true}
  for i,v in ipairs(proxy.getPN("uci.wireless.wifi-ap.", true)) do
    apPaths[i] = v.path.."iface"
  end
  local pathValue = proxy.get(unpack(apPaths))
  local macFound, macAddressPath, macAddressValue, ap
  for _, v in ipairs(pathValue) do
    if v.value == "wl0" or v.value == "wl1" then
      ap = match(v.path, "@([^%.]+)")
      macAddressPath = basePath.."@"..ap..".station."
      macAddressValue = content_helper.convertResultToObject(macAddressPath, proxy.get(macAddressPath))
      for _, w in  ipairs(macAddressValue) do
        macFound = match(w.paramindex, "@([^%.]+)")
        if macFound == mac and (w.flags ~= "" and w.rssi ~= "0") then
          ssidPath = format("rpc.wireless.ssid.@%s.", v.value)
          count = count + 1
          content = {
            rx_bytes = w.rx_bytes,
            tx_bytes = w.tx_bytes,
            assoc_time = w.assoc_time,
            ps_off_on_transistions = w.ps_off_on_transistions,
            rx_phy_rate = w.rx_phy_rate,
            tx_phy_rate = w.tx_phy_rate,
            rx_data_rate = w.rx_data_rate,
            tx_data_rate = w.tx_data_rate,
            flags = w.flags,
            rssi = w.rssi,
            capabilities = w.capabilities,
          }
        elseif count == 0 then
          content = {
            rx_bytes = "0",
            tx_bytes = "0",
            assoc_time = "0",
            ps_off_on_transistions = "0",
            rx_phy_rate = "0",
            tx_phy_rate = "0",
            rx_data_rate = "0",
            tx_data_rate = "0",
            flags = "",
            rssi = "0",
            capabilities = w.capabilities,
          }
        end
      end
    end
  end

  if content.rssi == "0" then
    content.rssi ="-100"
  end

  local days, hours, min, sec = secondsToUptime(tonumber(content.assoc_time))
  content.assoc_time = timeFormat(days, hours, min, sec)
  local ssid_content = {
    ssid = ssidPath .. "ssid",
    radio = ssidPath .. "radio",
  }
  content_helper.getExactContent(ssid_content)
  content.ssid = ssid_content.ssid
  content.freq = ""
  if ssid_content.radio == "radio_5G" then
    content.freq = "5GHz"
  elseif ssid_content.radio == "radio_2G" then
    content.freq = "2.4GHz"
  end
  ngx.print(json.encode(content))
end

local args = ngx.req.get_uri_args()
local dynDevice = args["device"]

--check the device value
if not post_helper.validateStringIsMAC(dynDevice) then
  dynDevice = nil
end

if args["ajaxreq"] == "1" then
  getDynamicValues(args["mac"])
  ngx.exit(ngx.HTTP_OK)
end

local ssids = {}
local ssidPath = "rpc.wireless.ssid."
local ssidPathValue = content_helper.convertResultToObject(ssidPath, proxy.get(ssidPath))
local ssid
for _, v in ipairs (ssidPathValue) do
  ssid = match (v.paramindex, "@([^%.]+)")
  if ssid then
    ssids[ssid] = {
      radio = v.radio,
      ssid = v.ssid,
    }
  end
end

local outputDetails, clients = {}, {}
local deviceExist = 0
local apPath = "rpc.wireless.ap."
local apPathValue = content_helper.convertResultToObject(apPath,proxy.get(apPath))
local hostPathValue = content_helper.convertResultToObject("rpc.hosts.host.",proxy.get("rpc.hosts.host."))
for _, v in ipairs(apPathValue) do
  local clientPath, ap, clientPathValue, client
  if v.ssid == "wl0" or v.ssid == "wl1" then
    ap = match(v.paramindex, "@([^%.]+)")
    if ap and ssids[format("%s", v.ssid)] then
      clientPath = "rpc.wireless.ap.@" .. ap .. ".station."
      clientPathValue = content_helper.convertResultToObject(clientPath, proxy.get(clientPath))
      for _, w in ipairs(clientPathValue)  do
        client = match(w.paramindex, "@([^%.]+)")
        for _, host in ipairs(hostPathValue) do
          if host["L2Interface"] == "wl1" or host["L2Interface"] == "wl1_1" or host["L2Interface"] == "eth5" or host["L2Interface"] == "wl0" or host["L2Interface"] == "wl0_1" then
            if host.State == "1" then
              if w.flags ~= "" and w.rssi ~= "0" then
                clients[client] = {
                  ap       = ap,
                  radio    = ssids[format("%s", v.ssid)]["radio"],
                  ssid     = ssids[format("%s", v.ssid)]["ssid"],
                  path     = clientPath.."@"..client..".",
                  hostname = client,
                }
                if client == dynDevice then
                  deviceExist = 1
                  outputDetails = {
                    ap       = ap,
                    radio    = ssids[format("%s", v.ssid)]["radio"],
                    ssid     = ssids[format("%s", v.ssid)]["ssid"],
                    path     = clientPath.."@"..client..".",
                    hostname = client,
                    mac      = client,
                  }
                break
                end
              end
            end
          end
        end
      end
    end
  end
end

local MACAddress
for _, v in ipairs(hostPathValue) do
  MACAddress = format("%s",v.MACAddress)
  if clients[MACAddress] then
    if v.FriendlyName ~= "" then
      clients[MACAddress]["hostname"] = v.FriendlyName
    end
    if MACAddress == dynDevice then
      if v.FriendlyName ~= "" then
        outputDetails["hostname"] = v.FriendlyName
      end
    end
  end
end

local clientSelect = {}
local path = outputDetails["path"]
if deviceExist == 0 then dynDevice = nil end
if dynDevice and path then
  local content = {
    rx_bytes = path .. "rx_bytes",
    tx_bytes = path .. "tx_bytes",
    assoc_time = path .. "assoc_time",
    state = path .. "state",
    ps_off_on_transistions = path .. "ps_off_on_transistions",
    rx_phy_rate = path .. "rx_phy_rate",
    tx_phy_rate = path .. "tx_phy_rate",
    rx_data_rate = path .. "rx_data_rate",
    tx_data_rate = path .. "tx_data_rate",
    capabilities = path .. "capabilities",
    flags = path .. "flags",
  }
  content_helper.getExactContent(content)
  for k,v in pairs(content) do
    outputDetails[k] = v
  end
else
  clientSelect[#clientSelect+1] = {"0" , T"None selected"}
end
for i,v in pairs(clients) do
  clientSelect[#clientSelect+1] = {i, v.hostname}
end
  ngx.print('\
\
<script>\
  $(function () {\
    $(\'select\').chosen({\
      disable_search_threshold: 100000,\
      allow_single_deselect: true\
    });\
  });\
</script>\
<h1><span>');  ngx.print(T"Client Monitor"); ngx.print('</span></h1>\
<h2><span>');  ngx.print(T"The information below shows the results of the latest scan of your local area from your client devices."); ngx.print('</span></h2>\
\
<h3><span>');  ngx.print(T"Selection"); ngx.print('</span></h3>\
\
<div class="h3-content vdf-table selection">\
  <div class="vdf-row">\
    <div class="left">\
      <span>');  ngx.print(T"Choose Device"); ngx.print('</span>\
    </div>\
    <div class="right" id="top-info-mode">\
      <select name="" id="client-sel-devices" style="display: block;">\
        ');  for _,v in pairs(clientSelect) do  ngx.print('\
          <option ');  if v[1] == dynDevice then  ngx.print(' selected ');  end  ngx.print(' value = "');  ngx.print(v[1]); ngx.print('">');  ngx.print(v[2]); ngx.print('</option>\
        ');  end  ngx.print('\
      </select>\
    </div>\
  </div>\
  <div class="vdf-row">\
    <div class="left"><span>');  ngx.print(T"Refresh List"); ngx.print('</span></div>\
    <div class="right">\
      <input class="button button-blank" id="client-btn-refresh" value="');  ngx.print(T"Refresh"); ngx.print('" type="button">\
    </div>\
  </div>\
</div>\
\
');  if dynDevice then   ngx.print('\
<div class="content-client-monitoring">\
  <h3><span>');  ngx.print(T"Device Details"); ngx.print('</span></h3>\
  <div class="h3-content no-padding-bottom">\
    <div class="message message-info">\
      ');  ngx.print(T"All the information is given from the client perspective."); ngx.print('\
    </div>\
  </div>\
\
  <div class="h3-content vdf-table device-details">\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(T"Host Name"); ngx.print('</span>\
      </div>\
      <div class="right">\
        <span id= "client-info-hostname">');  ngx.print(outputDetails["hostname"]); ngx.print('</span>\
      </div>\
    </div>\
\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(T"Frequency"); ngx.print('</span>\
      </div>\
      <div class="right">\
        ');  local freq = "2.4GHz"
          if outputDetails["radio"] == "radio_5G" then
          freq = "5GHz"
        end  ngx.print('\
        <span id = "client-info-freq">');  ngx.print(freq); ngx.print('</span>\
      </div>\
    </div>\
\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(T"SSID"); ngx.print('</span>\
      </div>\
      <div class="right">\
        <span id = "client-info-ssid">');  ngx.print(outputDetails["ssid"]); ngx.print('</span>\
      </div>\
    </div>\
\
    <div class="vdf-row">\
      <div class="left">\
        <span >');  ngx.print(T"MAC Address"); ngx.print('</span>\
      </div>\
      <div class="right">\
        <span id = "client-info-macaddr">');  ngx.print(string.upper(outputDetails["mac"])); ngx.print('</span>\
      </div>\
    </div>\
\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(T"Devices Compatibilities"); ngx.print('</span>\
      </div>\
      <div class="right">\
        <span id = "client-info-capabilities">');  ngx.print(outputDetails["capabilities"]); ngx.print('</span>\
      </div>\
    </div>\
\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(T"Active"); ngx.print('</span>\
      </div>\
      <div class="right">\
        <span id = "client-info-active">');  ngx.print(outputDetails["flags"]); ngx.print('</span>\
      </div>\
    </div>\
\
    ');  if outputDetails["radio"] ~= "radio_5G" then  ngx.print('\
      <div class="vdf-row">\
        <div class="left">\
          <span>');  ngx.print(T"Power Transition"); ngx.print('</span>\
        </div>\
        <div class="right">\
          <span id = "client-info-ps">');  ngx.print(outputDetails["ps_off_on_transistions"]); ngx.print('</span>\
        </div>\
      </div>\
    ');  end  ngx.print('\
\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(T"RSSI"); ngx.print('</span>\
      </div>\
      <div class="right">\
        <div id="chartcontainerwifi"><div class="spacer"/><div id="scale1wifi" class="scalewifi">-0dBm</div><div id="scale2wifi" class="scalewifi">-100dBm</div><div id="rssivalue" class="scalewifi">-50dBm</div></div>\
      </div>\
    </div>\
\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(T"PHY Rate"); ngx.print('</span>\
      </div>\
      <div class="right client-monitor">\
        <img src="/img/look_4/buttons/button-left.png" class="arrow-down">&nbsp;<span id = "client-info-phyrate1">');  ngx.print(outputDetails["tx_phy_rate"]/1000); ngx.print('Mbs</span> &nbsp;\
        <img src="/img/look_4/buttons/button-left.png" class="arrow-up">&nbsp;<span id = "client-info-phyrate2">');  ngx.print(outputDetails["rx_phy_rate"]/1000); ngx.print('Mbs</span>\
      </div>\
    </div>\
\
    ');  if outputDetails["radio"] ~= "radio_5G" then  ngx.print('\
      <div class="vdf-row">\
        <div class="left">\
          <span>');  ngx.print(T"Data Rate"); ngx.print('</span>\
        </div>\
        <div class="right">\
          <img src="/img/look_4/buttons/button-left.png" class="arrow-down">&nbsp;<span id = "client-info-datarate1">');  ngx.print(outputDetails["tx_data_rate"]/1000); ngx.print('Kbs</span> &nbsp;\
          <img src="/img/look_4/buttons/button-left.png" class="arrow-up">&nbsp;<span id = "client-info-datarate2">');  ngx.print(outputDetails["rx_data_rate"]/1000); ngx.print('Kbs</span>\
        </div>\
      </div>\
    ');  end  ngx.print('\
\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(T"Time Connected"); ngx.print('</span>\
      </div>\
      <div class="right">\
        ');  local days,hours,min,sec = secondsToUptime(tonumber(outputDetails["assoc_time"]))  ngx.print('\
        <span id = "assoc_time">');  ngx.print(timeFormat(days,hours,min,sec)); ngx.print('</span>\
      </div>\
    </div>\
  </div>\
</div>\
');  end  ngx.print('\
\
<script>\
var timerajax\
var url = \'/modals/client-monitoring.lp\';\
\
function loadModal() {\
  var deviceSelected = $("#client-sel-devices").val();\
  if (timerajax){clearTimeout(timerajax)};\
  $("#content").load(url, \'device=\'+deviceSelected);\
}\
\
function getInfo(mac,ap,getpath)\
{\
  var checktimer = 1000;\
  var gets =  {}\
  gets.ajaxreq = "1";\
  gets.mac = mac;\
  gets.path = getpath;\
  gets.ap = ap;\
  $.getJSON(url, gets )\
  .done(function( data ) {\
    var phyRateUp = (Math.floor(data.tx_phy_rate / 10)/100);\
    var phyRateDown = (Math.floor(data.rx_phy_rate / 10)/100);\
    $("#client-info-phyrate1").text(phyRateUp + " Mbs  ");\
    $("#client-info-phyrate2").text(phyRateDown + " Mbs");\
    if(data.freq != "5GHz"){\
      var dataRateUp = data.tx_data_rate;\
      var dataRateDown = data.rx_data_rate;\
      var dataRateUpTxt = " Kbs";\
      var dataRateDownTxt = " Kbs";\
      if (dataRateUp > 5000){\
        dataRateUp = (Math.floor(dataRateUp / 10)/100);\
        dataRateUpTxt = " Mbs";\
      }\
      if (dataRateDown > 5000){\
        dataRateDown = (Math.floor(dataRateDown / 10)/100);\
        dataRateDownTxt = " Mbs";\
      }\
      $("#client-info-datarate1").text(dataRateUp + dataRateUpTxt );\
      $("#client-info-datarate2").text(dataRateDown + dataRateDownTxt);\
      $("#client-info-ps").text(data.ps_off_on_transistions);\
    }\
    $("#client-info-active").text(data.flags);\
    $("#assoc_time").text(data.assoc_time);\
    $("#rssivalue").html(data.rssi + "dBm");\
    $("#client-info-capabilities").text(data.capabilities);\
    $("#client-info-freq").text(data.freq);\
    $("#client-info-ssid").text(data.ssid);\
    bars(data.rssi);\
  })\
  timerajax = window.setTimeout(function () {getInfo(mac,ap);}, checktimer);\
}\
$(function() {\
  $("#chartcontainerwifi").css({\'left\': \'20px\', \'margin\' : \'0px\'});\
  $("#client-sel-devices").change(function() {\
    loadModal();});\
  $("#client-btn-refresh").click(function() {\
    loadModal();});\
  ');  if dynDevice then  ngx.print('\
    getInfo("');  ngx.print(outputDetails["mac"]); ngx.print('","');  ngx.print(outputDetails["ap"]); ngx.print('","');  ngx.print(path); ngx.print('")\
  ');  end  ngx.print('\
});\
\
// Wifi chart scripts\
var countWifi = 0;\
function bars(x){\
  var y = 100 + parseInt(x);\
  var x = parseInt(x) * - 1;\
  $("#chartcontainerwifi").append(\'<div class=\\"barswifi\\" id=\\"bar-\'+countWifi+\'\\"></div>\');\
  var $d = $("#bar-"+countWifi)\
  var color = \'#FF0000\'; //default red\
  if (x <= 55){\
    color =  \'#00FF00\'; //green\
  }else if (x<80 && x>55){\
    color =  \'#FF9900\'; //orange\
  }\
  $d.css({\'height\': y+\'px\', \'left\': $(\'#chartcontainerwifi\').width() + \'px\', \'background-color\': color }).appendTo(\'#div-1\');\
  $(".barswifi").each(function(){\
    $(this).animate({\
      \'left\': $(this).position().left -5,\
      \'opacity\': $(this).css(\'opacity\')-0.02,\
      \'filter\': \'alpha(opacity=\'+toString(($(this).css(\'opacity\')-0.02)*100)+\')\'\
    },\'1500\');\
    if ($(this).position().left < 0){$(this).remove();}\
  });\
  countWifi++;\
}\
</script>\
'); 