--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')
local lp = require("web.lp")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local ipairs =  ipairs
local iconUp = "<i class=\"icon-upload icon-small gray\"></i> "
local iconDown = "<i class=\"icon-download icon-small gray\"></i> "
local floor = math.floor
local match, format  = string.match, string.format
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Wireless", "clientMonitor")
local PacketsInfoAndCurrentTime = post_helper.getVariantValue(variantHelper, "PacketsInfoAndCurrentTime")
local TIMERJS = 1000
local session = ngx.ctx.session

local function secondsToTime(uptime)
  if not uptime or uptime == "" then return T"Not Connected" end
  local days =  floor(uptime / 86400)
  local hours =  floor(uptime / 3600) % 24
  local minutes = floor(uptime / 60) % 60
  local seconds = uptime % 60
  if (days > 0) then
    return format(T"%d days %d hours %d minutes %d seconds", days, hours, minutes, seconds)
  elseif (hours > 0) then
    return format(T"%d hours %d minutes %d seconds", hours, minutes, seconds)
  elseif (minutes > 0) then
    return format(T"%d minutes %d seconds", minutes, seconds)
  else
    return format(T"%d seconds", seconds)
  end
end
local sentcountstart = 0
local recvcountstart = 0

--AJAX Part
local function AJAX(mac)
  local  ssid_path, count =  "", 0
  local content = {}
  local path = "rpc.wireless.ap."
  local path_value = content_helper.convertResultToObject(path, proxy.get(path))
  local mac_found , mac_address_path ,mac_address_value ,ap
  for _,pathVal in ipairs(path_value) do
     ap = match(pathVal.paramindex, "@([^%.]+)")
     mac_address_path = path.."@"..ap..".station."
     mac_address_value = content_helper.convertResultToObject(mac_address_path, proxy.get(mac_address_path))
     for _,macAddr in  ipairs(mac_address_value) do
       mac_found = match(macAddr.paramindex, "@([^%.]+)")
       if mac_found == mac:untaint() and (macAddr.flags ~= "" and macAddr.rssi ~= "0") then
         ssid_path = format("rpc.wireless.ssid.@%s.", pathVal.ssid)
         count = count +1
         content = {
           rx_bytes = macAddr.rx_bytes,
           tx_bytes = macAddr.tx_bytes,
           assoc_time = macAddr.assoc_time,
           rx_phy_rate = macAddr.rx_phy_rate,
           tx_phy_rate = macAddr.tx_phy_rate,
           flags = macAddr.flags,
           rssi = macAddr.rssi,
           capabilities = macAddr.capabilities,
          }
        elseif count == 0 then
          content = {
            rx_bytes = "0",
            tx_bytes = "0",
            assoc_time = "0",
            rx_phy_rate = "0",
            tx_phy_rate = "0",
            flags = "",
            rssi = "0",
            capabilities = macAddr.capabilities,
          }
        end
      end
  end
  if content.rssi == "0" then content.rssi ="-100" end
  content.assoc_time = secondsToTime(content.assoc_time)
  local ssid_content = {
     ssid = ssid_path .. "ssid",
     radio = ssid_path .. "radio",
  }
  content_helper.getExactContent(ssid_content)
   content.ssid = ssid_content.ssid
   content.freq = ""
   if ssid_content.radio == "radio_5G" then
         content.freq = "5GHz"
   elseif ssid_content.radio == "radio_2G" then
         content.freq = "2.4GHz"
   end

  local html = {}
  html[#html+1]="{"
  for k,v in pairs(content) do
    html[#html+1]=format("\"%s\":\"%s\"",k,v)
    html[#html+1]=","
  end
  html[#html]="}"
  ngx.print(html)
end

local args = ngx.req.get_uri_args()

local dyn_device = args["device"]

--check the device value
if not post_helper.validateStringIsMAC(dyn_device) then
    dyn_device = nil
end

if args["ajaxreq"] == "1" then
   AJAX(args["mac"])
   ngx.exit(ngx.HTTP_OK)
end

--AJAX End
--Collect the Wireles Client details

local type5G = proxy.get("uci.wireless.wifi-device.@radio_5G.type")
type5G = type5G and type5G[1].value or ""
local ssids = {}
local ssid_path = "rpc.wireless.ssid."
local ssid_path_value = content_helper.convertResultToObject(ssid_path, proxy.get(ssid_path))
local ssid
for _,ssidVal in ipairs (ssid_path_value) do
    ssid = match (ssidVal.paramindex , "@([^%.]+)")
    if ssid then
      if post_helper.getVariantValue(variantHelper, "ssidNetwork") then
        ssids[ssid] = {
            radio = ssidVal.radio,
            ssid = ssidVal.ssid,
            network = ssidVal.network
        }
      else
        if not match(ssidVal.ssid , "wifi1x") then
          ssids[ssid] = {
            radio = ssidVal.radio,
            ssid = ssidVal.ssid
          }
        end
      end
    end
end

local clients = {}
local output_details = {}
local online = 0
local ap_path = "rpc.wireless.ap."
local ap_path_value = content_helper.convertResultToObject(ap_path,proxy.get(ap_path))
local client_path, ap, client_path_value, client

for _,path in ipairs(ap_path_value) do
    ap = match(path.paramindex, "@([^%.]+)")
    if ap then
        if ssids[format("%s", path.ssid)] then
            client_path = "rpc.wireless.ap.@" .. ap .. ".station."
            client_path_value = content_helper.convertResultToObject(client_path,proxy.get(client_path))
            for _,clientPath in ipairs(client_path_value)  do
               client = match(clientPath.paramindex, "@([^%.]+)")
               if clientPath.flags ~= "" and clientPath.rssi ~= "0" then
                    clients[client] = {
                        ap = ap,
                        radio = ssids[format("%s", path.ssid)]["radio"],
                        ssid = ssids[format("%s", path.ssid)]["ssid"],
                        network = ssids[format("%s", path.ssid)]["network"],
                        path = client_path.."@"..client..".",
                        hostname = client,
                    }
                    if client == dyn_device then
                        online = 1
                        output_details = {
                            ap = ap,
                            radio = ssids[format("%s", path.ssid)]["radio"],
                            ssid = ssids[format("%s", path.ssid)]["ssid"],
                            path = client_path.."@"..client..".",
                            hostname = client,
                            mac = client,
                    }
                    end
                end
            end
        end
    end
end
local host_path = "sys.hosts.host."
local host_path_value = content_helper.convertResultToObject(host_path,proxy.get(host_path))

local multiapPath = "rpc.multiap.device."
local multiapData = content_helper.convertResultToObject(multiapPath, proxy.get(multiapPath))

local local_intf = {}
local MACAddress
for _, val in pairs(multiapData) do
  if type(val) == "table" then
    if val.local_interfaces then
      local_intf[ #local_intf + 1] = val.local_interfaces:untaint()
    end
  end
end

for _, host in ipairs(host_path_value) do
  MACAddress = format("%s", host.MACAddress)
  for _, intf in pairs(local_intf or {}) do
    if match(intf, MACAddress) then
      for cMAC in pairs(clients or {}) do
        if match(intf, cMAC) then
          MACAddress = cMAC
          break
        end
      end
    end
  end
  if clients[MACAddress] then
    if MACAddress == dyn_device then
     output_details["hostname"] = post_helper.getVariantValue(variantHelper, "hostname") and clients[MACAddress].hostname or host.FriendlyName
    end
    clients[MACAddress]["hostname"] = host.FriendlyName ~= "" and host.FriendlyName or "Unknown-" .. host.MACAddress
  end
end

local client_select = {}
local path = output_details["path"]
if online == 0 then dyn_device = nil end
if dyn_device and path then

   local content = {
      rx_bytes = path .. "rx_bytes",
      tx_bytes = path .. "tx_bytes",
      assoc_time = path .. "assoc_time",
      state = path .. "state",
      rx_phy_rate = path .. "rx_phy_rate",
      tx_phy_rate = path .. "tx_phy_rate",
      capabilities = path .. "capabilities",
      flags = path .. "flags",
  }
   if post_helper.getVariantValue(variantHelper, "PacketsInfoAndCurrentTime") then
     content["Packets_Sent"] = path .. "tx_packets"
     content["Packets_Received"] = path .. "rx_packets"
   end
   content_helper.getExactContent(content)
   for index, data in pairs(content) do
       output_details[index] = data
    end

   if dyn_device and post_helper.getVariantValue(variantHelper, "PacketsInfoAndCurrentTime") then
    sentcountstart = output_details["Packets_Sent"]
    recvcountstart = output_details["Packets_Received"]
   end

else
   client_select[#client_select+1] = {"0" , T"None selected"}
end

for index, clientVal in pairs(clients) do
  if post_helper.getVariantValue(variantHelper, "hotspot") then
    if clientVal.network ~= "hotspot" then
      client_select[#client_select+1] = {index, clientVal.hostname}
    end
  else
    client_select[#client_select+1] = {index, clientVal.hostname}
  end
end

local isNewLayout = proxy.get("uci.env.var.em_new_ui_layout")
isNewLayout = isNewLayout and isNewLayout[1].value or "0"
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Wireless Client Monitor", false, false))   ngx.print('\
\
<div class="modal-body update">\
');  
  if isNewLayout == "1" then
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-wireless.lp")
  end
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/wireles-client-modal.lp">\
    ');  
    local html = {}
    html[#html + 1] = ui_helper.createMessages(message_helper.popMessages())
      ngx.print('\
    <fieldset>\
      <legend>');  ngx.print( T"Selection" ); ngx.print('</legend>\
      ');  
      if isNewLayout == "1" then
        local info_alert = {
          alert = {
            class = "alert-info"
          },
        }
        if session:hasAccess("/modals/easymesh-configuration-modal-newEM.lp") then
          html[#html + 1] = ui_helper.createAlertBlock(format("%s <a href=\"javascript:tch.loadModal('/modals/easymesh-configuration-modal-newEM.lp')\"> %s </a>", T"Only clients connected to this device are monitored here.A full list of clients can be obtained on the", T"Easymesh page"), info_alert)
        end
      end
      local clientSelect = {
        group = {
            class = "",
        },
        select = {
            class = "span6"
        }
      }
    html[#html + 1] = ui_helper.createInputSelect(T"Choose Device", "client_selected", client_select, dyn_device, clientSelect)
    local refresh_style = {

        button = {
          id = "btn-refresh",
        }
      }
    html[#html + 1] = ui_helper.createButton(T"Refresh List", T"Refresh", "icon-refresh", refresh_style)
    ngx.print(html)
      ngx.print('\
    </fieldset>\
    ');  if dyn_device then   ngx.print('\
    <fieldset>\
      <legend>');  ngx.print( T"Device Details" ); ngx.print('</legend>\
      ');  
      html = {}
        local host_style = {
          span = {
            id = "Host",
            class = "span6"
          }
        }
        local perspective_warning = {
          alert = {
            class = "alert-warning",
          },
        }
        if output_details["hostname"] ~= output_details["mac"] then
          html[#html + 1] = ui_helper.createAlertBlock(T"All information is given from the Client perspective", perspective_warning)
          html[#html + 1] = ui_helper.createLabel(T"Host Name", output_details["hostname"], host_style )
        else
          if isNewLayout == "1" then
            local hostname = output_details["hostname"]
            local macAddress = output_details["mac"]
            hostname = clients[macAddress]["hostname"] or ""
            html[#html + 1] = ui_helper.createLabel(T"Name", hostname, host_style )
          else
            html[#html + 1] = ui_helper.createLabel(T"Host Name", output_details["hostname"], host_style )
          end
        end
        local Freq_style = {
          span = {
            id = "freq",
            class = "span6"
          }
        }
        local freq = "2.4GHz"
        if output_details["radio"] == "radio_5G" then
          freq = "5GHz"
        end
        html[#html+1] = ui_helper.createLabel(T"Frequency", freq , Freq_style )
        local SSID_style = {
          span = {
            id = "ssid",
            class = "span6"
          }
        }
        html[#html+1] = ui_helper.createLabel(T"SSID", output_details["ssid"] , SSID_style )
         local MAC_style = {
           span = {
                id = "MACAddr",
                class = "span6"
            }
          }
         html[#html+1] = ui_helper.createLabel(T"MAC Address", output_details["mac"]:upper(), MAC_style )
         local capa_style = {
           span = {
                id = "capabilities",
                class = "span6"
            }
          }
         html[#html+1] = ui_helper.createLabel(T"Device Capabilities", output_details["capabilities"], capa_style )
         local Active_style = {
           span = {
                id = "Active",
                class = "span6"
            }
          }
         html[#html+1] = ui_helper.createLabel(T"Active", output_details["flags"], Active_style )
         html[#html+1] = "<label class=\"control-label\">RSSI</label><div id=\"chartcontainerwifi\"><div class=\"spacer\"/><div id=\"scale1wifi\" class=\"scalewifi\">-0dBm</div><div id=\"scale2wifi\" class=\"scalewifi\">-100dBm</div><div id=\"rssivalue\" class=\"scalewifi\">-50dBm</div></div>"
         local PHY_style = {
           span = {
                id = "PHY_Rate",
                class = "span6"
            }
          }
         html[#html+1] = ui_helper.createLabel(T"PHY Rate", format("%s %.0f Mbps %s %.0f Mbps",iconUp,output_details["rx_phy_rate"]/1000,iconDown,output_details["rx_phy_rate"]/1000), PHY_style )
         local Packets_Tx_style = {
           span = {
                id = "Packets_Sent",
                class = "span6"
            }
          }
         if post_helper.getVariantValue(variantHelper, "PacketsInfoAndCurrentTime") then
         html[#html+1] = ui_helper.createLabel(T"Packets Sent", output_details["Packets_Sent"], Packets_Tx_style )

         local Packets_Rx_style = {
           span = {
                id = "Packets_Received",
                class = "span6"
            }
          }
         html[#html+1] = ui_helper.createLabel(T"Packets Received", output_details["Packets_Received"], Packets_Rx_style )

         end
         local Time_style = {
           span = {
                id = "assoc_time",
                class = "span6"
            }
          }

         html[#html+1] = ui_helper.createLabel(T"Time Connected", secondsToTime(output_details["assoc_time"]) , Time_style )

         local Current_time_style = {
           span = {
             id = "Current_Time",
             class = "span6"
           },
         }
         if post_helper.getVariantValue(variantHelper, "PacketsInfoAndCurrentTime") then
         local Current_time = os.date("%F %T", os.time())
         html[#html+1] = ui_helper.createLabel(T"Current Time", Current_time , Current_time_style )
         end
         ngx.print(html)
        ngx.print('\
    </fieldset>\
    ');  end  ngx.print('\
  </form>\
</div>\
\
<div class="modal-footer">\
    <div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal">');  ngx.print( T"Close" ); ngx.print('</div>\
    ');  if isNewLayout == "0" then  ngx.print('\
      <div id="btn-return" class="btn btn-primary btn-large" >');  ngx.print( T"Return" ); ngx.print('</div>\
    ');  end  ngx.print('\
</div>\
\
<script>\
  var PacketsInfoAndCurrentTime = ');  ngx.print(PacketsInfoAndCurrentTime); ngx.print(';\
  var sentpctstart = ');  ngx.print(sentcountstart); ngx.print(';\
  var recvpctstart = ');  ngx.print(recvcountstart); ngx.print(';\
  var checktimer = ');  ngx.print(TIMERJS); ngx.print(';\
  var dyn_device =  "');  ngx.print(dyn_device); ngx.print('";\
  var mac = \'');  ngx.print(output_details["mac"]); ngx.print('\';\
  var ap = \'');  ngx.print(output_details["ap"]); ngx.print('\';\
  var path = \'');  ngx.print(path); ngx.print('\';\
  var type5G = \'');  ngx.print(type5G); ngx.print('\';\
</script>\
<script src="/js/wireless-client-modal.js"></script>\
'); 