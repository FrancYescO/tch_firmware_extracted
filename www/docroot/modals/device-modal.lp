<%
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local table, string = table, string
local tonumber = tonumber
local floor = math.floor
local format = string.format

local function secondsToTime(connectiontime)
  local days =  floor(connectiontime / 86400)
  local hours =  floor(connectiontime / 3600) % 24
  local minutes = floor(connectiontime / 60) % 60
  local seconds = connectiontime % 60
  if (days > 0) then
    return format(T"%ddays %dhours %dmin %dsec", days, hours, minutes, seconds)
  elseif (hours > 0) then
    return format(T"%dhours %dmin %dsec", hours, minutes, seconds)
  elseif (minutes > 0) then
    return format(T"%dmin %dsec", minutes, seconds)
  else
    return format(T"%dsec", seconds)
  end
end

-- devices forwarding rules
local devices_columns = {
  {--[1]
    header = T"Status",
    name = "state",
    param = "State",
    type = "light",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[2]
    header = T"Hostname",
    name = "hostname",
    param = "HostName",
    type = "text",
    readonly = true,
    attr = { input = { class="span3" } },
  },
  {--[3]
    header = T"IPv4",
    name = "ipv4",
    param = "IPv4",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[4]
    header = T"IPv6",
    name = "ipv6",
    param = "IPv6",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[5]
    header = T"MAC address",
    name = "macaddress",
    param = "MACAddress",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[6]
    header = T"InterfaceType",
    name = "interfacetype",
    param = "InterfaceType",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[7]
    header = T"Port",
    name = "port",
    param = "Port",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[8]
    header = T"Connection Time",
    name = "ConnectionTime",
    param = "ConnectedTime",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[9]
    header = T"Lease time",
    name = "dhcpLeaseTime",
    param = "DhcpLeaseTime",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  { --[[[10]
    we removed the "br-lan" filter in RPC, so get this value for filter below,
    this item in devices_columns will be removed before createTable.
    Be sure that this item is the last item in devices_columns table,
    and change the index below accordingly if you modify the code here
    --]]
    header = T"L3Interface",
    name = "L3Interface",
    param = "L3Interface",
    type = "text",
    readonly = true,
  },
}

local device_valid = {}
local devices_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "devices",
    basepath = "sys.hosts.host.",
}

--Funtion that gets information of a particular wireless station, the parameter received is the MAC address
local stationConf = {}
local getStationData = function(stationMAC)
		stationConf = {}
		local stationPath = string.format("rpc.wireless.ap.@ap0.station.@%s.", stationMAC)
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
				rx_phy_rate = stationPath .. "rx_phy_rate",
		}

		local m_status, m_error = content_helper.getExactContent(stationConf)

		stationConf["radio"] = "2.4Ghz"
		return m_status
end

local getStationData5G = function(stationMAC)
		stationConf = {}
		local stationPath = string.format("rpc.wireless.ap.@ap1.station.@%s.", stationMAC)
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
			rx_phy_rate = stationPath .. "rx_phy_rate",
		}

		local m_status, m_error = content_helper.getExactContent(stationConf)
		stationConf["radio"] = "5Ghz"
		return m_status
end

local tmp_devices_data, devices_helpmsg = post_helper.handleTableQuery(devices_columns, devices_options, nil, nil, device_valid)
local datarows ={}
local devices_data = {}
local index = 1

--Only show the devices that on "br-lan", others will be filtered out.
for k,v in pairs(tmp_devices_data) do
    if v[1] == "1" then
      if v[9] ~= "" and v[8] ~= "" then
        v[9] = secondsToTime(tonumber(v[9])- (os.time()- tonumber(v[8]))%tonumber(v[9]))
      else
        v[9]="-"
      end

      if v[8] ~= "" then
        v[8] = secondsToTime(os.time()- tonumber(v[8]))
      else
        v[8] = "-"
      end
    else
      v[8] = "-"
      v[9] = "-"
    end

    if v[10] == "br-lan" then
			local n_status
			--Here the WiFi Stats info is populated
			if v[6] == "wireless" then
				n_status= getStationData(v[5])
				if tostring(n_status) == "true" then
					datarows[index]={}
					datarows[index][1] = v[2]
					datarows[index][2] = stationConf["capabilities"]
					datarows[index][3] = tostring(tonumber(stationConf["tx_phy_rate"])/1000).." ".."Mbps"
					datarows[index][4] = "5"

					local lastRSSI = tonumber(stationConf["last_rssi"])
					if stationConf["state"] ~= "Disconnected" then
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

					datarows[index][6] = stationConf["last_rssi"]
					datarows[index][7] = stationConf["av_rssi"]
					datarows[index][8] = stationConf["rssi"]
					datarows[index][9] = string.format("%.1f KB",tostring(tonumber(stationConf["tx_bytes"])/1000))
					datarows[index][10] = string.format("%.1f KB",tostring(tonumber(stationConf["rx_bytes"])/1000))
					datarows[index][11] = stationConf["radio"]
					index = index + 1
				end

				n_status= getStationData5G(v[5])

				if tostring(n_status) == "true" then
					datarows[index]={}
					datarows[index][1] = v[2]
					datarows[index][2] = stationConf["capabilities"]
					datarows[index][3] = tostring(tonumber(stationConf["tx_phy_rate"])/1000).." ".."Mbps"
					datarows[index][4] = "5"

					local lastRSSI = tonumber(stationConf["last_rssi"])
					if stationConf["state"] ~= "Disconnected" then
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

					datarows[index][6] = stationConf["last_rssi"]
					datarows[index][7] = stationConf["av_rssi"]
					datarows[index][8] = stationConf["rssi"]
					datarows[index][9] = string.format("%.1f KB",tostring(tonumber(stationConf["tx_bytes"])/1000))
					datarows[index][10] = string.format("%.1f KB",tostring(tonumber(stationConf["rx_bytes"])/1000))
					datarows[index][11] = stationConf["radio"]
					index = index + 1
				end

			end
      --The l3interface is only used for filter, so remove it
      v[10] = nil
      table.insert(devices_data, v)
    end
end

--The l3interface is only used for filter, so remove it
devices_columns[10] = nil

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
columns[11]["header"] = T"Band"
%>

<%= ui_helper.createHeader(T"Devices", false, true) %>

<div class="modal-body update">
  <form class="form-horizontal" method="post" action="modals/device-modal.lp">
    <%
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    %>

    <fieldset>
      <legend><%= T"Devices" %></legend>
      <%= ui_helper.createTable(devices_columns, devices_data, devices_options, nil, devices_helpmsg) %>
    </fieldset>
		  <legend><b><%= T"WiFi Stats" %></b></legend>
	<fieldset>
	<%
		local html = {}
		ngx.print(html)
		local options = { tableid = "networkstats", canEdit = false, editing = false, minEntries = 5, maxEntries = 7, createMsg = "Create new", canAdd = false, canDelete = false, newList = true, errmsg = nil}
		table.insert(html, ui_helper.createTable(columns, datarows, options))
		ngx.print(html)
	%>
	  </fieldset>
  </form>
</div>
<%= ui_helper.createFooter() %>

