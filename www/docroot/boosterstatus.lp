--pretranslated: do not change this file
 ngx.print('\
');  
local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")

local untaint, match, upper, gsub = string.untaint, string.match, string.upper, string.gsub
local proxy = require("datamodel")
local content_helper = require("web.content_helper")

local devices = {
    type = "gateway",
    name = untaint(proxy.get("uci.system.system.@system[0].hostname")[1].value),
    -- bssid2g = string.upper(untaint(proxy.get("sys.class.net.@wl0.address")[1].value)),
    -- bssid5g = string.upper(untaint(proxy.get("sys.class.net.@wl1.address")[1].value)),
    hostNumber = 0,
    extenderNumber = 0,
}

local devices_columns = {
    {--[1]
        param = "HostName",
        type = "text",
    },
    {--[2]
        param = "Speed",
        type = "text",
    },
    {--[3]
        param = "IPAddress",
        type = "text",
    },
    {--[4]
        param = "State",
        type = "text",
    },
    {--[5]
        param = "InterfaceType",
        type = "text",
    },
    {--[6]
        param = "L2Interface",
        type = "text",
    },
    {--[7]
        param = "L3Interface",
        type = "text",
    },
    {--[8]
        param = "MACAddress",
        type = "text",
    },
}
local hosts, indexes = content_helper.loadTableData("sys.hosts.host.", devices_columns)
local hosts_MAC = {}
for k,v in ipairs(hosts) do
    if v[8] and v[8] ~= "" then
        hosts_MAC[upper(untaint(v[8]))] = v
    end
end

for _,ap in pairs({"ap0", "ap2"}) do
    local staPath = "rpc.wireless.ap.@" .. ap .. ".station."
    local stations = content_helper.convertResultToObject(staPath, proxy.get(staPath))
    for _,s in ipairs(stations) do
        if s.state ~= "Disconnected" and s.state ~= "Authenticated" and s.paramindex then
            local mac = gsub(s.paramindex,"@","")
            mac = upper(mac)
            local host = hosts_MAC[mac]
            if host and host[4] == "1" then
                local linkRate = tonumber(s.tx_phy_rate) and s.tx_phy_rate/1000
                devices[#devices+1] = {
                    type = "host",
                    name = untaint(host[1]),
                    speed = linkRate,
                    ipAddress = untaint(host[3]),
                }
                devices.hostNumber = devices.hostNumber + 1
                hosts_MAC[mac] = nil
            end
        end
    end
end

local agents = {}
local path = "Device.Services.X_TELSTRA_MultiAP.Agent."
local data = content_helper.convertResultToObject(path, proxy.get(path))
for k,v in ipairs(data) do
    if v.MACAddress ~= "" and v.MACAddress ~= "00:00:00:00:00:00" then
        local agent = {
            type = "extender",
            name = untaint(v.Alias),
            bssid2g = untaint(v.BSSID2GHZ_Backhaul),
            bssid5g = untaint(v.BSSID5GHZ_Backhaul),
            parentAccessPoint = untaint(v.ParentAccessPoint),
            connectionType = untaint(v.ConnectionType),
            LEDColor = untaint(v.LEDColor),
            hostNumber = 0,
            extenderNumber = 0,
        }
        if v.ConnectionType == "Ethernet" then
            agent.connectionStatus = "Excellent"
        elseif v.SignalStrength ~= "" and tonumber(v.SignalStrength) then
            local signal_strengh = tonumber(v.SignalStrength)
            if signal_strengh <= -127 then
                agent.connectionStatus = "No"
            elseif signal_strengh < -85 then
                agent.connectionStatus = "Weak"
            elseif signal_strengh > -75 then
                agent.connectionStatus = "Excellent"
            else
                agent.connectionStatus = "Good"
            end
        end
        if tonumber(v.AssociatedDeviceNumberOfEntries) > 0 then
            for param,value in pairs(v) do
                if match(param,"STA.%d+.MACAddress") and value ~= "" then
                    local host = hosts_MAC[upper(untaint(value))]
                    if host and host[4] == "1" then
                        local key = gsub(param, "MACAddress","LastDataDownlinkRate")
                        local linkRate = tonumber(v[key]) and v[key]/1000
                        agent[#agent+1] = {
                            type = "host",
                            name = untaint(host[1]),
                            speed = linkRate,
                            ipAddress = untaint(host[3]),
                        }
                        agent.hostNumber = agent.hostNumber + 1
                    end
                end
            end
        end
        agents[#agents+1] = agent
    end
end

local function listToTree(t)
    local tree = {}
    while(next(t))
    do
        local parent = {}
        local key = {}
        for k,v in pairs(t) do
            if v.parentAccessPoint and v.parentAccessPoint ~= "" then parent[v.parentAccessPoint] = true end
            if v.bssid2g and v.bssid2g ~= "" then key[v.bssid2g] = k end
            if v.bssid5g and v.bssid5g ~= "" then key[v.bssid5g] = k end
        end
        for k,v in pairs(t) do
            if not ((v.bssid2g and parent[v.bssid2g]) or (v.bssid5g and parent[v.bssid5g])) then
                -- v is leaf node
                local k_p = v.parentAccessPoint and key[v.parentAccessPoint]
                if k_p then
                    -- v 's parent is in table
                    t[k_p][#t[k_p]+1] = v
                    t[k_p].extenderNumber = t[k_p].extenderNumber + 1
                else
                    -- v 's parent is root node
                    tree[#tree+1] = v
                end
                t[k] = nil
            end
        end
    end
    return tree
end

local agentsTree = listToTree(agents)

for k,v in ipairs(agentsTree) do
    devices[#devices+1] = v
    devices.extenderNumber = devices.extenderNumber + 1
end

local html = {}

local icons = {
    gateway = "ap_gw.png",
    host = "wireless.png",
    extenderRed = "ap_booster_red.png",
    extenderOrange = "ap_booster_orange.png",
    extenderBlue = "ap_booster_blue.png",
}

local type_convert = {
    WiFi5G = "5GHz",
    WiFi2G = "2.4GHz",
}

  ngx.print('\
\
\
<style type="text/css">\
    .table3 td {border-top:none;border-color:#004D9D;padding-top:0px;padding-bottom:0px;width:35px;}\
    .table3 td .info {font-size:0.938em;text-align:left;}\
</style>\
\
<div class="container">\
    ');  lp.include("tabs-home.lp")   ngx.print('\
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
                        else
                            icon = icons[n.type]
                        end
                        local node = [=[
                        <td rowspan="2" colspan="2">
                            <div class="device">
                                <img class="devicepicture" src="img/]=] .. (icon or "") .. [=["/>
                            </div>
                        </td>
                        ]=]
                        return node or ""
                    end
                    local function printNodeInfo(n)
                        local info
                        if n.type == "gateway" then
                            info = [=[
                        <td colspan="8">
                            <div class="info">]=] .. (n.name or "unknown name") .. [=[</div>
                        </td>
                            ]=]
                        elseif n.type == "host" then
                            info = [=[
                        <td rowspan="2" colspan="8">
                            <div class="info">]=] .. (n.name or "unknown name") .. "(" .. (n.speed and (n.speed .. "Mbps") or "no link rate") .. ")" .. [=[
                                <br />]=] .. (n.ipAddress and n.ipAddress or "no ip address") .. [=[
                            </div>
                        </td>
                        <td>&nbsp;</td>
                            ]=]
                        elseif n.type == "extender" then
                            info = [=[
                        <td colspan="8">
                            <div class="info">
                                <br />]=] .. (n.name or "unknown name") .. [=[
                                <br />]=] .. (n.connectionType and (type_convert[n.connectionType] or n.connectionType) or "unknown connection type") .. [=[
                                <br />]=] .. (n.connectionStatus and (n.connectionStatus .. " Connection") or "unknown connection status") .. [=[
                            </div>
                        </td>
                            ]=]
                        end
                        return info or ""
                    end
                    local nextNode = [=[
                        <td style="border-right-style:solid">&nbsp;</td>
                        <td>&nbsp;</td>
                    ]=]
                    local bottomNode = [=[
                        <td>&nbsp;</td>
                        <td>&nbsp;</td>
                    ]=]
                    local prefixNode = [=[
                        <td style="border-right-style:solid">&nbsp;</td>
                        <td style="border-bottom-style:solid">&nbsp;</td>
                    ]=]
                    local function topologicalGraph(t, space)
                        space = space or ""
                        if type(t) == "table" then
                            html[#html + 1] = printNode(t)
                            table.sort(t, function(a,b) return tostring(a.name) < tostring(b.name) end)
                            local host = 0
                            for k,v in ipairs(t) do
                                if type(v) == "table" then
                                    if v.type == "host" then
                                        host = host + 1
                                        local str_h
                                        if host < t.hostNumber then
                                            -- str_h = "...|..."
                                            str_h = nextNode
                                        else
                                            -- str_h = "......."
                                            str_h = bottomNode
                                        end
                                        if host == 1 then
                                            -- html = html .. "___.___" .. v.name .. "\n"
                                            -- html = html .. space .. "xxxxxxx" .. str_h .. "\n"
                                            html[#html + 1] = [=[
                        <td style="border-bottom-style:solid" align="center" valign="bottom">]=] .. t.hostNumber .. [=[</td>
                        <td style="border-bottom-style:solid">&nbsp;</td>
                                            ]=] .. printNode(v) .. printNodeInfo(v) .. [=[
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
                                if type(v) == "table" then
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
\
');  
lp.include("footer.lp")
  ngx.print('\
'); 