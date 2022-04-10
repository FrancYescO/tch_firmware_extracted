--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')
local untaint, match, upper, gsub = string.untaint, string.match, string.upper, string.gsub
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local format = string.format
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local lp = require("web.lp")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "ExtenderPage", "extendertopology")
local navigationLink = post_helper.getVariantValue(variantHelper, "navigationLink")
local extenderName = post_helper.getVariantValue(variantHelper, "extenderName")
local gatewayName = post_helper.getVariantValue(variantHelper, "gatewayName")
local gatewayHwMac = post_helper.getVariantValue(variantHelper, "gatewayHwMac")
local extenderConnectionType = post_helper.getVariantValue(variantHelper, "extenderConnectionType")
local showEthDevices = post_helper.getVariantValue(variantHelper, "showEthDevices")
local customConnectionStatus = post_helper.getVariantValue(variantHelper, "customConnectionStatus")
local hideNoLinkRateText = post_helper.getVariantValue(variantHelper, "hideNoLinkRateText")

local devices = {
    type = "gateway",
    name = untaint(proxy.get("uci.system.system.@system[0].hostname")[1].value),
    controllerMac = untaint(proxy.get("uci.multiap.controller.macaddress")[1].value),
    -- bssid2g = string.upper(untaint(proxy.get("sys.class.net.@wl0.address")[1].value)),
    -- bssid5g = string.upper(untaint(proxy.get("sys.class.net.@wl1.address")[1].value)),
    hostNumber = 0,
    extenderNumber = 0
}

if gatewayName then
    devices.name = untaint(proxy.get("uci.env.var.serial")[1].value)
end
if gatewayHwMac then
    devices.controllerMac = untaint(proxy.get("uci.env.rip.eth_mac")[1].value)
end

local devices_columns = {
    {
        --[1]
        param = "FriendlyName",
        type = "text"
    },
    {
        --[2]
        param = "Speed",
        type = "text"
    },
    {
        --[3]
        param = "IPv4",
        type = "text"
    },
    {
        --[4]
        param = "State",
        type = "text"
    },
    {
        --[5]
        param = "InterfaceType",
        type = "text"
    },
    {
        --[6]
        param = "L2Interface",
        type = "text"
    },
    {
        --[7]
        param = "L3Interface",
        type = "text"
    },
    {
        --[8]
        param = "MACAddress",
        type = "text"
    }
}

local APPath = "rpc.wireless.ap."
local path = "rpc.multiap.device."
local APData = content_helper.convertResultToObject(APPath, proxy.get(APPath))
local hosts, indexes = content_helper.loadTableData("sys.hosts.host.", devices_columns)
local data = content_helper.convertResultToObject(path, proxy.get(path))
local staList = content_helper.convertResultToObject("rpc.multiap.sta.",proxy.get("rpc.multiap.sta."))
local ethList = content_helper.convertResultToObject("rpc.multiap.eth.",proxy.get("rpc.multiap.eth."))
local hosts_MAC = {}

for k, v in ipairs(hosts) do
    if v[8] and v[8] ~= "" then
        hosts_MAC[upper(untaint(v[8]))] = v
    end
end

for _, value in ipairs(APData) do
    local ap = string.gsub(value.paramindex, "@", "")
    local staPath = APPath .. "@" .. ap .. ".station."
    local stations = content_helper.convertResultToObject(staPath, proxy.get(staPath))
    for _, s in ipairs(stations) do
        if s.state and s.state ~= "" and s.state ~= "Disconnected" and s.state ~= "Authenticated" and s.paramindex and s.rssi and s.rssi ~= "" and s.rssi ~= "0" then
            local mac = gsub(s.paramindex, "@", "")
            mac = upper(mac)
            local host = hosts_MAC[mac]
            if host and host[4] == "1" then
                local linkRate = tonumber(s.tx_phy_rate) and s.tx_phy_rate / 1000
                devices[#devices + 1] = {
                    type = "host",
                    name = untaint(host[1]),
                    speed = linkRate,
                    ipAddress = untaint(host[3]),
                    hostMacAddr = untaint(host[8])
                }
                devices.hostNumber = devices.hostNumber + 1
                hosts_MAC[mac] = nil
            end
        end
    end
end

-- Display Ethernet Connected devices
if showEthDevices then
  local ethPath = "rpc.multiap.eth."
  local ethMac = content_helper.convertResultToObject(ethPath, proxy.get(ethPath))
  local extDev = false

  for _, e in pairs(ethMac) do
    local mac = upper(untaint(e.MacAddress))
    local host = hosts_MAC[mac]
    if host and host[5] == "ethernet" then

      for k, v in pairs(data) do
        for param, value in pairs(v) do
          if param == "eth_clients" then
            for eth in string.gmatch(value, '([^%s,]+)') do
               if mac == upper(eth) then
                 extDev = true
               end
            end
          end
        end
      end

      if not extDev and host and untaint(host[4]) == "1" then
        local linkRate = tonumber(host[2])
        devices[#devices + 1] = {
            type = "ethClients",
            name = untaint(host[1]),
            speed = linkRate,
            ipAddress = untaint(host[3]),
            hostMacAddr = untaint(host[8])
        }
        devices.hostNumber = devices.hostNumber + 1
        hosts_MAC[mac] = nil
      end
    end
  end
end

local agents = {}
local agent_count = proxy.get("rpc.multiap.ExtenderNumberOfEntries")[1].value
local thresholdData = proxy.get("uci.web.signalstrength.")
local level

if customConnectionStatus then
  level = { ["threshold_nosig"]=-127, ["threshold_weak"]=-68, ["threshold_excel"]=-61 }
else
  level = { ["threshold_nosig"]=-127, ["threshold_weak"]=-85, ["threshold_excel"]=-75 }
end

for _, data in ipairs(thresholdData or {}) do
  level[data["param"]] = tonumber(data["value"]) or level[data["param"]]
end

local function getUsrFriendlyName(mac_list)
  for _, dev in ipairs(hosts) do
    for mac in string.gmatch(mac_list, '([^,]+)') do
      if dev[8] and dev[8] == mac then
        name = dev[1] and dev[1] or T"UnknownName"
      end
    end
  end
  return untaint(name)
end

for k, v in ipairs(data) do
  if v.MACAddress ~= "" and v.backhaul_interface_type ~= "Unknown" then
    local agent = {
      type = "extender",
      name = untaint(v.serial_number),
      parentAccessPoint = untaint(v.parent),
      LEDColor = "",
      hostNumber = 0,
      extenderNumber = 0,
      macAddr = untaint(v.al_mac),
      connectionStatus = "",
      ipaddress = untaint(v.ip_address),
      macList = v.local_interfaces and untaint(v.local_interfaces) or ""
    }

    if extenderName then
      agent.name = untaint(v.device_name .. " - " .. v.serial_number)
    else
      agent.name = getUsrFriendlyName(agent.macList)
    end
    agent.connectionType = untaint(v.backhaul_interface_type)
    if v.backhaul_interface_type == "Ethernet" then
      agent.connectionStatus = customConnectionStatus and "Great" or "Excellent"
    elseif v.rssi ~= "" and tonumber(v.rssi) then
      local signal_strength = tonumber(v.rssi)
      if signal_strength <= level["threshold_nosig"] then
        agent.connectionStatus = "No"
      elseif signal_strength < level["threshold_weak"] then
        agent.connectionStatus = "Weak"
      elseif signal_strength > level["threshold_excel"] then
        agent.connectionStatus = customConnectionStatus and "Great" or "Excellent"
      else
        agent.connectionStatus = "Good"
      end
    end
    if agent_count and tonumber(agent_count) > 0 then
      for param, value in pairs(v) do
        if match(param, "^%S+.sta_list$") then
          if value ~= "" then
            for sta_i in string.gmatch(value, '([^%s]+)') do
              local host = hosts_MAC[tostring(untaint(upper(sta_i)))]
              local linkRate = 0
              local rssiValue = ""
              for _, val in pairs(staList) do
                if val.mac == sta_i then
                  linkRate = tostring(untaint(val.dl_mac_rate))
                  rssiValue = val.rssi and val.rssi ~= "" and tonumber(val.rssi) or ""
                end
              end
              if host and untaint(host[4]) == "1" and rssiValue and rssiValue ~= "" and rssiValue ~= 0 then
                agent[#agent + 1] = {
                  type = "host",
                  name = host and untaint(host[1]) or "UnknownName",
                  speed = linkRate,
                  ipAddress = host and untaint(host[3]) or "NA",
                  hostMacAddr = host and untaint(host[8]) or "NA"
                }
                agent.hostNumber = agent.hostNumber + 1
              end
            end
          end
        end

        if showEthDevices and param == "eth_clients" then
          if value ~= "" then
            for eth in string.gmatch(value, '([^%s,]+)') do
              local host = hosts_MAC[tostring(untaint(upper(eth)))]
              if host then
                local linkRate = tonumber(host[2])
                agent[#agent + 1] = {
                    type = "ethClients",
                    name = host and untaint(host[1]) or "UnknownName",
                    speed = linkRate,
                    ipAddress = host and untaint(host[3]) or "NA",
                    hostMacAddr = host and untaint(host[8]) or "NA",
                }
                agent.hostNumber = agent.hostNumber + 1
              end
            end
          end
        end
      end
    end
    agents[#agents + 1] = agent
  end
end

local function listToTree(t)
    local tree = {}
    while (next(t)) do
        local parent = {}
        local key = {}
        for k, v in pairs(t) do
            if v.parentAccessPoint and v.parentAccessPoint ~= "" then
                parent[v.parentAccessPoint] = true
            end
            if v.macAddr and v.macAddr ~= "" then
             key[v.macAddr] = k
            end
        end
        for k, v in pairs(t) do
            if not (v.macAddr and parent[v.macAddr]) then
                -- v is leaf node
                local k_p = v.parentAccessPoint and key[v.parentAccessPoint]
                if k_p then
                    -- v 's parent is in table
                    t[k_p][#t[k_p] + 1] = v
                    t[k_p].extenderNumber = t[k_p].extenderNumber + 1
                else
                    -- v 's parent is root node
                    tree[#tree + 1] = v
                end
                t[k] = nil
            end
        end
    end
    return tree
end

local agentsTree = listToTree(agents)

for k, v in ipairs(agentsTree) do
    devices[#devices + 1] = v
    devices.extenderNumber = devices.extenderNumber + 1
end

local html = {}

local icons = {
    gateway = "gateway.png",
    host = "wifi_all.png",
    extenderRed = "ap_booster_red.png",
    extenderOrange = "ap_booster_orange.png",
    extenderBlue = "extender.png",
    ethClients = "network.png"
}

local link = {
    gateway = "modals/easy-mesh-configuration.lp",
    host = "modals/wifi-devices-info.lp",
}

local type_convert = {
    WiFi5G = "5GHz",
    WiFi2G = "2.4GHz"
}

lp.setpath("/www/snippets/")
ngx.print(ui_helper.createHeader(T"EasyMesh Info", false, true))
  ngx.print('\
<form class="form-horizontal" method="post" action="/modals/wifi-extender-status.lp">\
    <div class="modal-body update">\
        ');  lp.include("tabs-easyMesh.lp")  ngx.print('\
        <style type="text/css">\
            .table3 td {\
                border-top: none;\
                border-color: #004D9D;\
                padding-top: 0px;\
                padding-bottom: 0px;\
                width: 35px;\
            }\
\
            .table3 td .info {\
                font-size: 0.938em;\
                text-align: left;\
            }\
        </style>\
\
        <div class="container">\
            <div class="row">\
                <br />\
                <div id="boosterstatus" class="networkmap span12">\
                    <table align="center" class="table3">\
                        <tbody>\
                            ');  
                            local function printNode(n)
                                local icon
                                if n.type == "extender" then
                                    icon = n.LEDColor and icons[n.type .. n.LEDColor] or icons["extenderBlue"]
                                    link["extender"] = "modals/agent-list.lp?iface=" .. string.lower(n.macAddr)
                                else
                                    icon = icons[n.type]
                                end
                                local hrefLink = "#"
                                if n.type == "host" or showEthDevices and n.type == "ethClients" then
                                    hrefLink = hrefLink .. n.hostMacAddr
                                end
                                local node = [=[ <td class="nav" rowspan="2" colspan="2">
                                                   <div class="device">
                                             ]=]
                                local nodeLink = [=[ <img class="devicepicture" src="img/]=] .. (icon or "") .. [=["/> ]=]
                                local nodeGen = [=[ <a href=]=] .. hrefLink .. [=[ data-remote=]=] .. (link[n.type] or "") .. [=[>
                                                     <img class="devicepicture" src="img/]=] .. (icon or "") .. [=["/>
                                                    </a>
                                                 ]=]
                                local nodeEnd = [=[ </div>
                                          </td>
                                          ]=]
                                if navigationLink and n.type ~= "extender" then
                                  node = node..nodeGen..nodeEnd
                                else
                                  node = node..nodeLink..nodeEnd
                                end
                                return node or ""
                            end
                            local function printNodeInfo(n)
                                local info
                                if n.type == "gateway" then
                                    if gatewayName then
                                        n.controllerMac = n.name .. [=[ <br />]=] .. n.controllerMac
                                    end
                                    info = [=[
                                        <td colspan="8">
                                            <div class="info">]=] .. n.controllerMac .. [=[</div>
                                        </td>
                                    ]=]
                                elseif n.type == "host" or showEthDevices and n.type == "ethClients" then
                                    if n.name == "" then
                                        n.name = "unknown host"
                                    end
                                    info = [=[
                                        <td rowspan="2" colspan="8">
                                            <div class="info">]=] .. (n.name) .. (n.speed and "(" .. n.speed .. "Mbps)" or hideNoLinkRateText and "" or "(no link rate)") .. [=[
                                                <br />]=] .. (n.ipAddress and n.ipAddress or "no ip address") .. [=[
                                            </div>
                                        </td>
                                        <td>&nbsp;</td>
                                    ]=]
                                elseif n.type == "extender" then
                                    info = [=[
                                        <td colspan="8">
                                            <div class="info"> ]=]
                                               local infoName = [=[ <br />]=] .. (n.name or "unknown name") .. [=[ ]=]
                                               local infoIp = [=[ <br />]=] .. (n.ipaddress or "") .. [=[ ]=]
                                               local infoType = [=[ <br />]=] .. (n.connectionType and (type_convert[n.connectionType] or n.connectionType) or "unknown connection type") .. [=[ ]=]
                                               local infoStatus = [=[ <br />]=] .. (n.connectionStatus and (n.connectionStatus .. " Connection") or "unknown connection status") .. [=[ ]=]
                                           local infoEnd = [=[ </div>
                                        </td> ]=]
                                     if navigationLink then
                                       info = info..infoName..infoType..infoStatus..infoEnd
                                     else
                                       info = info..infoName..infoIp..infoStatus..infoEnd
                                     end
                                end
                                return info or ""
                            end
                            local prefixNode, nextNode, nextNodeLine, nextNodeDashed, prefixNodeLine, prefixNodeDashed
                            nextNodeLine = [=[
                                <td style="border-right-style:solid">&nbsp;</td>
                                <td>&nbsp;</td>
                            ]=]
                            nextNodeDashed = [=[
                                <td style="border-right:2px dashed;">&nbsp;</td>
                                <td>&nbsp;</td>
                            ]=]
                            local bottomNode = [=[
                                <td>&nbsp;</td>
                                <td>&nbsp;</td>
                            ]=]
                            prefixNodeLine = [=[
                                <td style="border-right-style:solid">&nbsp;</td>
                                <td style="border-bottom-style:solid">&nbsp;</td>
                            ]=]
                            prefixNodeDashed = [=[
                                <td style="border-right-style:solid">&nbsp;</td>
                                <td style="border-bottom:2px dashed">&nbsp;</td>
                            ]=]

                            local function topologicalGraph(t, space)
                                prefixNode = prefixNodeLine
                                nextNode = nextNodeLine
                                space = space or ""
                                if type(t) == "table" then
                                    html[#html + 1] = printNode(t)
                                    table.sort(t, function(a,b) return tostring(a.name) < tostring(b.name) end)
                                    local host = 0
                                    for k,v in ipairs(t) do
                                        if v.connectionType ~= "Ethernet" and extenderConnectionType then
                                            prefixNode = prefixNodeDashed
                                           -- nextNode = nextNodeDashed
                                        end
					if showEthDevices and v.type == "ethClients" then
                                            prefixNode = prefixNodeLine
                                          --  nextNode = nextNodeLine
                                        end
                                        if type(v) == "table" then
                                            if v.type == "host" or showEthDevices and v.type == "ethClients" then
                                                host = host + 1
                                                local str_h, wifiview
                                                if host < t.hostNumber then
                                                    -- str_h = "...|..."
                                                    str_h = nextNode
                                                else
                                                    -- str_h = "......."
                                                    str_h = bottomNode
                                                end
                                                if extenderConnectionType then
                                                    if v.type == "host" then
                                                        wifiview = [=[
                                                                <td style="border-bottom-style:solid" align="center" valign="bottom">]=] .. t.hostNumber.. [=[</td>
                                                                <td style="border-bottom:dashed 2px">&nbsp;</td> ]=]
                                                    else
                                                        wifiview = [=[
                                                            <td style="border-bottom-style:solid" align="center" valign="bottom">]=] .. t.hostNumber.. [=[</td>
                                                            <td style="border-bottom-style:solid">&nbsp;</td> ]=]
                                                    end
                                                else
                                                    wifiview = [=[
                                                        <td style="border-bottom-style:solid" align="center" valign="bottom">]=] .. t.hostNumber.. [=[</td>
                                                        <td style="border-bottom-style:solid">&nbsp;</td> ]=]

                                                end
                                                if host == 1 then
                                                    -- html = html .. "___.___" .. v.name .. "\n"
                                                    -- html = html .. space .. "xxxxxxx" .. str_h .. "\n"
                                                    html[#html + 1] = wifiview .. printNode(v) .. printNodeInfo(v) .. [=[
                                                        </tr>
                                                        <tr>
                                                    ]=] .. space .. str_h .. [=[
                                                        </tr>
                                                    ]=]
                                                else
                                                    local str_e
                                                    if t.extenderNumber > 0 then
                                                        -- str_e = "...|..."
                                                        str_e = nextNode
                                                    else
                                                        -- str_e = "......."
                                                        str_e = bottomNode
                                                    end
                                                    -- html = html .. space .. str_e .. "...|___" .. v.name .. "\n"
                                                    -- html = html .. space .. str_e .. str_h .. "\n"
                                                    html[#html + 1] = [=[
                                                        <tr>
                                                    ]=] .. space .. str_e .. prefixNode .. printNode(v) .. printNodeInfo(v) .. [=[
                                                        </tr>
                                                        <tr>
                                                    ]=] .. space .. str_e .. str_h .. [=[
                                                        </tr>
                                                    ]=]
                                                end
                                            end
                                        end
                                    end
                                    if host == 0 then
                                        -- html = html .. "\n"
                                        -- html = html .. space .. "xxxxxxx" .."\n"
                                        html[#html + 1] = [=[
                                            </tr>
                                            <tr>
                                        ]=] .. space .. [=[
                                            <td>&nbsp;</td>
                                            </tr>
                                        ]=]
                                    end
                                    local extender = 0
                                    for k,v in ipairs(t) do
                                        prefixNode = prefixNodeLine
                                        nextNode = nextNodeLine
                                        if type(v) == "table" then
                                            if v.connectionType ~= "Ethernet" and extenderConnectionType then
                                                prefixNode = prefixNodeDashed
                                               -- nextNode = nextNodeDashed
                                            end
                                            if v.type == "extender" then
                                                extender = extender + 1
                                                local str
                                                if extender < t.extenderNumber then
                                                    -- str = "...|..."
                                                    str = nextNode
                                                else
                                                    -- str = "......."
                                                    str = bottomNode
                                                end
                                                -- html = html .. space .. "...|___"
                                                html[#html + 1] = [=[
                                                    <tr>
                                                ]=] .. space .. nextNode .. printNodeInfo(v) .. [=[
                                                    </tr>
                                                    <tr>
                                                ]=] .. space .. prefixNode
                                                topologicalGraph(v, space .. str)
                                            end
                                        end
                                    end
                                end
                            end
                            html[#html + 1] = [=[
                                <tr>
                            ]=] .. printNodeInfo(devices) .. [=[
                                </tr>
                                <tr>
                            ]=]
                            topologicalGraph(devices)
                            html[#html + 1] = [=[
                                <tr>
                                    <td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td>
                                    <td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td>
                                </tr>
                                <tr>
                                    <td>&nbsp;</td>
                                </tr>
                            ]=]
                            ngx.print(html)
                              ngx.print('\
                        </tbody>\
                    </table>\
                </div>\
            </div>\
        </div>\
    </div>\
</form>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 