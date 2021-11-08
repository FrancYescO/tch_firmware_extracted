--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local table = table
local tonumber = tonumber
local format = string.format
local ipairs, ngx = ipairs, ngx
local wirelessSSID_helper = require("wirelessSSID_helper")
local format = string.format
local tprint = require("tch.tableprint")


local wifi_options = {
  tableid = "modal-Table_Value_WifiNurse",
  canEdit = false,
  editing = false,
  minEntries = 5,
  maxEntries = 7,
  createMsg = "Create new",
  canAdd = false,
  canDelete = false,
  newList = true,
  errmsg = nil
}

local ssid_name_2G, ssid_radio_2G, ssid_name_5G, ssid_radio_5G
local ssid_list = wirelessSSID_helper.getSSID()
for _, ssidList in ipairs(ssid_list) do
  if ssidList.radio == "2.4GHz" then
    ssid_name_2G = ssidList.ssid
    ssid_radio_2G = ssidList.radio
  else
    if not ssid_name_5G and not ssid_radio_5G then
      ssid_name_5G = ssidList.ssid
      ssid_radio_5G = ssidList.radio
    end
  end
end

local band_steer_enabled = "0"
local curap = "ap0"

local content_band_steer = {
  band_steer_id = "uci.wireless.wifi-bandsteer.@bs0.state"
}
content_helper.getExactContent(content_band_steer)

if "1" == content_band_steer.band_steer_id then
  band_steer_enabled = "1"
end

--Funtion that gets information of a particular wireless station, the parameter received is the MAC address
local stationConf = {}
local getStationData = function(stationMAC)
  stationConf = {}
  local stationPath = format("rpc.wireless.ap.@ap0.station.@%s.", stationMAC)
  stationConf = {
    state = stationPath .. "state",
    flags = stationPath .. "flags",
    capabilities = stationPath .. "capabilities",
    last_rssi = stationPath .. "last_rssi",
    rssi = stationPath .. "rssi",
    av_rssi = stationPath .. "av_rssi",
    rx_bytes = stationPath .. "rx_bytes",
    tx_bytes = stationPath .. "tx_bytes",
    tx_phy_rate = stationPath .. "tx_phy_rate",
    rx_phy_rate = stationPath .. "rx_phy_rate"
  }

local m_status = content_helper.getExactContent(stationConf)
  stationConf.radio = "2.4Ghz"
  return m_status
end

local getStationData5G = function(stationMAC)
  stationConf = {}
  local stationPath = format("rpc.wireless.ap.@ap1.station.@%s.", stationMAC)
    stationConf = {
    state = stationPath .. "state",
    flags = stationPath .. "flags",
    capabilities = stationPath .. "capabilities",
    last_rssi = stationPath .. "last_rssi",
    rssi = stationPath .. "rssi",
    av_rssi = stationPath .. "av_rssi",
    rx_bytes = stationPath .. "rx_bytes",
    tx_bytes = stationPath .. "tx_bytes",
    tx_phy_rate = stationPath .. "tx_phy_rate",
    rx_phy_rate = stationPath .. "rx_phy_rate"
  }

local m_status = content_helper.getExactContent(stationConf)
  stationConf.radio = "5Ghz"
  return m_status
end

local hosts_data = proxy.get("sys.hosts.host.")
local hosts = content_helper.convertResultToObject("sys.hosts.host.", hosts_data)

local datarows ={}
local index = 1

--Only handle the devices that on "br-lan", others will be filtered out.
for x = 1, #hosts, 1 do
  if hosts[x].L3Interface == "br-lan" then
  local n_status
  --Here the WiFi Nurse info is populated
    if hosts[x].InterfaceType == "wireless" then
    n_status= getStationData(hosts[x].MACAddress)
      if tostring(n_status) == "true" and stationConf.state ~= "Disconnected" then
        datarows[index]={}
        datarows[index][1] = hosts[x].HostName
        datarows[index][2] = stationConf.capabilities
        datarows[index][3] = tostring(tonumber(stationConf.tx_phy_rate)/1000).." ".."Mbps"
        datarows[index][4] = "5"

        local lastRSSI = tonumber(stationConf.last_rssi)
        if stationConf.state ~= "Disconnected" then
          if lastRSSI > -41 then
	    datarows[index][5] = T"Exceptional"
	    datarows[index][4] = "1"
	  else
	    if lastRSSI > -55 then
	      datarows[index][5] = T"Very Good"
	      datarows[index][4] = "1"
	    else
	      if lastRSSI > - 71 then
	        datarows[index][5] = T"Good"
		datarows[index][4] = "1"
	      else
	        if lastRSSI > - 81 then
		  datarows[index][5] = T"Marginal"
		  datarows[index][4] = "3"
		else
		  datarows[index][5] = T"Intermittent to No Operation"
		  datarows[index][4] = "4"
		end
              end
	    end
	  end
        else
          datarows[index][5] = T"Disconnected"
          datarows[index][4] = "5"
        end

        datarows[index][6] = stationConf.last_rssi
        datarows[index][7] = stationConf.av_rssi
        datarows[index][8] = stationConf.rssi
        datarows[index][9] = format("%.1f KB",tostring(tonumber(stationConf.tx_bytes)/1000))
        datarows[index][10] = format("%.1f KB",tostring(tonumber(stationConf.rx_bytes)/1000))
        datarows[index][11] = stationConf.radio
        index = index + 1
      end

    n_status= getStationData5G(hosts[x].MACAddress)
      if tostring(n_status) == "true" and stationConf.state ~= "Disconnected" then
        datarows[index]={}
        datarows[index][1] = hosts[x].HostName
	datarows[index][2] = stationConf.capabilities
        datarows[index][3] = tostring(tonumber(stationConf.tx_phy_rate)/1000).." ".."Mbps"
        datarows[index][4] = "5"

        local lastRSSI = tonumber(stationConf.last_rssi)
        if stationConf.state ~= "Disconnected" then
          if lastRSSI > -41 then
	    datarows[index][5] = T"Exceptional"
	    datarows[index][4] = "1"
	  else
	    if lastRSSI > -55 then
	      datarows[index][5] = T"Very Good"
	      datarows[index][4] = "1"
	    else
	      if lastRSSI > - 71 then
	        datarows[index][5] = T"Good"
		datarows[index][4] = "1"
	      else
	        if lastRSSI > - 81 then
		  datarows[index][5] = T"Marginal"
		  datarows[index][4] = "3"
		else
		  datarows[index][5] = T"Intermittent to No Operation"
		  datarows[index][4] = "4"
		end
	      end
	    end
	  end
        else
          datarows[index][5] = T"Disconnected"
          datarows[index][4] = "5"
        end

        datarows[index][6] = stationConf.last_rssi
        datarows[index][7] = stationConf.av_rssi
        datarows[index][8] = stationConf.rssi
        datarows[index][9] = format("%.1f KB", tostring(tonumber(stationConf.tx_bytes)/1000))
        datarows[index][10] = format("%.1f KB", tostring(tonumber(stationConf.rx_bytes)/1000))
        datarows[index][11] = stationConf.radio
        index = index + 1
      end
    end
  end
end

local datarows_5g ={}
local index_5g = 1
for x = 1, #hosts, 1 do
  if hosts[x].L3Interface == "br-lan" then
  local n_status
  --Here the WiFi Nurse info is populated
    if hosts[x].InterfaceType == "wireless" then
    n_status= getStationData5G(hosts[x].MACAddress)
      if tostring(n_status) == "true" and stationConf.state ~= "Disconnected" then
        datarows_5g[index_5g]={}
	datarows_5g[index_5g][1] = hosts[x].HostName
	datarows_5g[index_5g][2] = stationConf.capabilities
	datarows_5g[index_5g][3] = tostring(tonumber(stationConf.tx_phy_rate)/1000).." ".."Mbps"
	datarows_5g[index_5g][4] = "5"

        local lastRSSI = tonumber(stationConf.last_rssi)
        if stationConf.state ~= "Disconnected" then
          if lastRSSI > -41 then
	    datarows_5g[index_5g][5] = T"Exceptional"
	    datarows_5g[index_5g][4] = "1"
	  else
	    if lastRSSI > -55 then
	      datarows_5g[index_5g][5] = T"Very Good"
	      datarows_5g[index_5g][4] = "1"
	    else
	      if lastRSSI > - 71 then
	        datarows_5g[index_5g][5] = T"Good"
		datarows_5g[index_5g][4] = "1"
	      else
	        if lastRSSI > - 81 then
		  datarows_5g[index_5g][5] = T"Marginal"
		  datarows_5g[index_5g][4] = "3"
		else
		  datarows_5g[index_5g][5] = T"Intermittent to No Operation"
		  datarows_5g[index_5g][4] = "4"
		end
	      end
	    end
	  end
        else
          datarows_5g[index_5g][5] = T"Disconnected"
          datarows_5g[index_5g][4] = "5"
        end

        datarows_5g[index_5g][6] = stationConf.last_rssi
        datarows_5g[index_5g][7] = stationConf.av_rssi
        datarows_5g[index_5g][8] = stationConf.rssi
        datarows_5g[index_5g][9] = format("%.1f KB", tostring(tonumber(stationConf.tx_bytes)/1000))
        datarows_5g[index_5g][10] = format("%.1f KB", tostring(tonumber(stationConf.rx_bytes)/1000))
        index_5g = index_5g + 1
      end
    end
  end
end

local datarows_2g ={}
local index_2g = 1
for x = 1, #hosts, 1 do
  if hosts[x].L3Interface == "br-lan" then
  local n_status
  --Here the WiFi Nurse info is populated
    if hosts[x].InterfaceType == "wireless" then
    n_status= getStationData(hosts[x].MACAddress)
      if tostring(n_status) == "true" and stationConf.state ~= "Disconnected" then
        datarows_2g[index_2g]={}
	datarows_2g[index_2g][1] = hosts[x].HostName
	datarows_2g[index_2g][2] = stationConf.capabilities
	datarows_2g[index_2g][3] = tostring(tonumber(stationConf.tx_phy_rate)/1000).." ".."Mbps"
	datarows_2g[index_2g][4] = "5"

        local lastRSSI = tonumber(stationConf.last_rssi)
        if stationConf.state ~= "Disconnected" then
          if lastRSSI > -41 then
	    datarows_2g[index_2g][5] = T"Exceptional"
	    datarows_2g[index_2g][4] = "1"
	  else
	    if lastRSSI > -55 then
	      datarows_2g[index_2g][5] = T"Very Good"
	      datarows_2g[index_2g][4] = "1"
	    else
	      if lastRSSI > - 71 then
	        datarows_2g[index_2g][5] = T"Good"
		datarows_2g[index_2g][4] = "1"
	      else
	        if lastRSSI > - 81 then
		  datarows_2g[index_2g][5] = T"Marginal"
		  datarows_2g[index_2g][4] = "3"
		else
		  datarows_2g[index_2g][5] = T"Intermittent to No Operation"
		  datarows_2g[index_2g][4] = "4"
		end
	      end
	    end
	  end
        else
          datarows_2g[index_2g][5] = T"Disconnected"
          datarows_2g[index_2g][4] = "5"
        end

      datarows_2g[index_2g][6] = stationConf.last_rssi
      datarows_2g[index_2g][7] = stationConf.av_rssi
      datarows_2g[index_2g][8] = stationConf.rssi
      datarows_2g[index_2g][9] = format("%.1f KB", tostring(tonumber(stationConf.tx_bytes)/1000))
      datarows_2g[index_2g][10] = format("%.1f KB", tostring(tonumber(stationConf.rx_bytes)/1000))
      index_2g = index_2g + 1
      end
    end
  end
end

--Column Names
local columns ={}
for i=1, 11 do
  columns[i]={}
end

columns[1]["header"] = T"Name"
columns[2]["header"] = T"Capabilities"
columns[3]["header"] = T"Max Speed"
columns[4]["header"] = T""
columns[4]["type"] = "light"
columns[4]["readonly"] = "true"

columns[5]["header"] = T"Signal Quality"
columns[6]["header"] = T"Last RSSI"
columns[7]["header"] = T"Av RSSI"
columns[8]["header"] = T"RSSI"
columns[9]["header"] = T"Tx Bytes"
columns[10]["header"] = T"Rx Bytes"
columns[11]["header"] =  band_steer_enabled == "0" and T"" or T"Band"
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Wireless", false, true) ); ngx.print('\
<div class="modal-body update">');  
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-wireless.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/wifi-nurse-modal.lp">\
    ');  
      ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
      ');  if band_steer_enabled == "0" then   ngx.print('\
        ');  
          local heading, data = {}
          local html = {}
          for  i = 1 , 2 ,1 do
            heading = i == 1 and ssid_name_2G or ssid_name_5G
	    heading_radio = i == 1 and ssid_radio_2G or ssid_radio_5G
            data =  i == 1 and  datarows_2g or datarows_5g
            html[#html + 1] = format("<legend><b>%s(%s)</b></legend><fieldset>", heading, heading_radio)
            html[#html+1] = ui_helper.createTable(columns, data, wifi_options)
            html[#html+1] = "</fieldset>"
            ngx.print(html)
            html = {}
          end
          ngx.print('\
      ');  else   ngx.print('\
        <legend><b>');  ngx.print( ssid_name_2G ); ngx.print('</b></legend>\
	<fieldset>\
	');  
	  local html = {}
	  table.insert(html, ui_helper.createTable(columns, datarows, wifi_options))
	  ngx.print(html)
	  ngx.print('\
	</fieldset>\
      ');  end   ngx.print('\
    </% end %>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 