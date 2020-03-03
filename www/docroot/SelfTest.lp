<%
-- Enable localization
gettext.textdomain('webui-core')
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local format = string.format
local tonumber = tonumber
local find,sub,untaint = string.find, string.sub, string.untaint
local proxy = require("datamodel")

local ethLan_data = {
    actNumEthernet = "sys.hosts.ActiveEthernetNumberOfEntries",
    numEthernet = "uci.network.interface.@lan.ifname",
}

local barcode_data = {
    model_num = "uci.env.var.prod_friendly_name",
    pba_tocom = "uci.env.rip.pba_tocom",
    factory_date = "uci.env.rip.factory_date",
    factory_id = "uci.env.rip.factory_id",
    serial_num = "uci.env.rip.serial",
    firmware_version = "uci.version.version.@version[0].version",
    fwversion_prefix = "uci.versioncusto.override.fwversion_prefix",
    fwversion_suffix = "uci.versioncusto.override.fwversion_suffix",
    fwversion_override = "uci.versioncusto.override.fwversion_override",
}

local ethWan_data = {
    ethwan_status     = "sys.eth.port.@eth4.status",
}

local xdsl_data = {
    dsl_status = "sys.class.xdsl.@line0.Status",
}

local mobiled = {
    num_devices = "rpc.mobiled.DeviceNumberOfEntries"
}

local cs = {
    ipaddr = "rpc.network.interface.@wan.ipaddr",
    ipmask = "rpc.network.interface.@wan.ipmask",
    proto = "uci.network.interface.@wan.proto",
}

local wan_state = {
    auto = "uci.network.interface.@wan.auto",
}

local mmpbx_state = {
    state = "rpc.mmpbx.state",
}

local matchAUTOTable = {
    ["ethLan"] = {
        name = "ethLan",
        module = "ETHERNET",
        text = "ETHERNET LAN TEST",
    },
    ["ethWan"] = {
        name = "ethWan",
        module = "ETHERNETWAN",
        text = "ETHERNET WAN TEST",
    },
    ["dsl"] = {
        name = "dsl",
        module = "DSL",
        text = "DSL TEST",
    },
    ["usb1"] = {
        name = "usb1",
        module = "USB1",
        text = "USB1 TEST",
    },
    ["usb2"] = {
        name = "usb2",
        module = "USB2",
        text = "USB2 TEST",
    },
    ["wifi1"] = {
        name = "wifi1",
        module = "WIFI1",
        text = "WIFI 2.4GHz TEST",
    },
    ["wifi2"] = {
        name = "wifi2",
        module = "WIFI2",
        text = "WIFI 5GHz TEST",
    },
    ["lte"] = {
        name = "lte",
        module = "LTE",
        text = "LTE TEST",
    },
    ["dect"] = {
        name = "dect",
        module = "DECT",
        text = "DECT TEST",
    },
}
local matchMANULTable = {
    ["led"] = {
        name = "LED",
        text = "LED TEST",
        id = "led",
        func = "ledTest",
    },
    ["fxs"] = {
        name = "FXS",
        text = "FXS TEST",
        id = "fxs",
        func = "fxsTest",
    },
    ["fxo"] = {
        name = "FXO",
        text = "FXO TEST",
        id = "fxo",
        func = "fxoTest",
    },
    ["dt1"] = {
        name = "DialTone1",
        text = "Dial Tone 1 Test",
        id = "dt1",
        func = "dt1Test",
    },
    ["dt2"] = {
        name = "DialTone2",
        text = "Dial Tone 2 Test",
        id = "dt2",
        func = "dt2Test",
    },
    ["btn"] = {
        name = "BUTTON",
        text = "BUTTON TEST",
        id = "btn",
        func = "btnTest",
    },
    ["nfc"] = {
        name = "NFC",
        text = "NFC TEST",
        id = "nfc",
        func = "nfcTest",
    },
    ["wpsbtn"] = {
        name = "WPSBTN",
        text = "WPS BUTTON TEST",
        id = "wpsbtn",
        func = "wpsbtnTest",
    },
    ["dectbtn"] = {
        name = "DECTBTN",
        text = "DECT BUTTON TEST",
        id = "dectbtn",
        func = "dectbtnTest",
    },
    ["resetbtn"] = {
        name = "RESETBTN",
        text = "RESET BUTTON TEST",
        id = "resetbtn",
        func = "resetbtnTest",
    },
    ["wifibtn"] = {
        name = "WIFIBTN",
        text = "WIFI BUTTON TEST",
        id = "wifibtn",
        func = "wifibtnTest",
    },
    ["statusbtn"] = {
        name = "STATUSBTN",
        text = "STATUS BUTTON TEST",
        id = "statusbtn",
        func = "statusbtnTest",
    },

}

local activeAUTOModule = {"ethLan","ethWan","dsl","usb1","usb2","wifi1","wifi2","dect"}
--local activeAUTOModule = {"ethWan","dsl","usb1","usb2","wifi1","wifi2","dect"}
local activeMANULModule = {"dt1","led","nfc","dectbtn","wifibtn","dt2"}

--table.insert(activeAUTOModule,"ethLan")

function tmpSplit(str, delimiter)
    if str==nil or str=='' or delimiter==nil then
        return nil
    end

    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end

if ngx.req.get_method() == "POST" then
    local args = ngx.req.get_post_args()
    local action = args["action"]

    if action == "startTest" then
        ngx.header.content_type = "application/json"
        ngx.print('{ "result":"true" }')
    elseif action == "ethLan" then
        content_helper.getExactContent(ethLan_data)
        local allEth = {"eth0", "eth1", "eth2", "eth3"}
        local hosts_path = "sys.class.net.@"
        local errorCode = -1
        for a_k,a_v in ipairs(allEth) do
            local find = 0
            local state =  format("%s", proxy.get(hosts_path..a_v..".operstate")[1].value)
			if(state == "up") then
				find = 1
			end
            if (find == 1) then
            else
                errorCode = format("%d",a_k)
                break
            end
        end
        ngx.header.content_type = "application/json"
        if(errorCode == -1) then
            ngx.print('{ "result":"suc","act":"ethLan" }')
        else
            ngx.print('{ "result":"fail","act":"ethLan","extModuleName":'.. '"' .. matchAUTOTable["ethLan"].module .. errorCode ..'" }')
        end
    elseif action == "ethWan" then
        content_helper.getExactContent(ethWan_data)
        ngx.header.content_type = "application/json"
        if(ethWan_data["ethwan_status"] == "up") then
            ngx.print('{ "result":"suc","act":"ethWan" }')
        else
            ngx.print('{ "result":"fail","act":"ethWan" }')
        end
    elseif action == "dsl" then
        content_helper.getExactContent(xdsl_data)
        local state = args["state"]
        local ret = 0
        if(state == nil or state == "testing") then
            if xdsl_data["dsl_status"] == "Up" then
                ret = 1;
            else
                ret = -1;
            end
        elseif state == "final" then
            if xdsl_data["dsl_status"] == "Up" then
                ret = 1;
            else
                ret = 0;
            end
        end
        ngx.header.content_type = "application/json"
        if(ret == 1) then
            ngx.print('{ "result":"suc","act":"dsl" }')
        elseif(ret == -1) then
            ngx.print('{ "result":"testing","act":"dsl" }')
        else
            ngx.print('{ "result":"fail","act":"dsl" }')
        end
    elseif action == "usb1" then
        local usb_path = "sys.usb.device."
        local usb_path_value = content_helper.convertResultToObject(usb_path,proxy.get(usb_path))
        local ret = 0
        for k,v in ipairs(usb_path_value) do
            local port = format("%s",v.path)
			local partition = format("sys.usb.device.%s.partition.",v.paramindex)
            if port == "1-1" then
                        ret = 1
                        break;
            end
        end
        ngx.header.content_type = "application/json"
        if(ret == 1) then
            ngx.print('{ "result":"suc","act":"usb1" }')
        else
            ngx.print('{ "result":"fail","act":"usb1" }')
        end
    elseif action == "usb2" then
        local usb_path = "sys.usb.device."
        local usb_path_value = content_helper.convertResultToObject(usb_path,proxy.get(usb_path))
        local ret = 0
        for k,v in ipairs(usb_path_value) do
            local port = format("%s",v.path)
			local partition = format("sys.usb.device.%s.partition.",v.paramindex)
            if port == "1-2" then
                        ret = 1
                        break;
            end
        end
        ngx.header.content_type = "application/json"
        if(ret == 1) then
            ngx.print('{ "result":"suc","act":"usb2" }')
        else
            ngx.print('{ "result":"fail","act":"usb2" }')
        end
    elseif action == "wifi1" then
        local state = args["state"]
        local ret = 0
        if(state == nil or state == "testing") then
            if isWifiConnect("wl0") > 0 then
                ret = 1;
            else
                ret = -1;
            end
        elseif state == "final" then
            if isWifiConnect("wl0") > 0 then
                ret = 1;
            else
                ret = 0;
            end
        end

        ngx.header.content_type = "application/json"
        if(ret == 1) then
            ngx.print('{ "result":"suc","act":"wifi1" }')
        elseif(ret == -1) then
            ngx.print('{ "result":"testing","act":"wifi1" }')
        else
            ngx.print('{ "result":"fail","act":"wifi1" }')
        end
    elseif action == "wifi2" then

        local state = args["state"]
        local ret = 0
        if(state == nil or state == "testing") then
            if isWifiConnect("wl1") > 0 then
                ret = 1;
            else
                ret = -1;
            end
        elseif state == "final" then
            if isWifiConnect("wl1") > 0 then
                ret = 1;
            else
                ret = 0;
            end
        end

        ngx.header.content_type = "application/json"
        if(ret == 1) then
            ngx.print('{ "result":"suc","act":"wifi2" }')
        elseif(ret == -1) then
            ngx.print('{ "result":"testing","act":"wifi2" }')
        else
            ngx.print('{ "result":"fail","act":"wifi2" }')
        end
    elseif action == "lte" then
        content_helper.getExactContent(mobiled)
        local mobile_num = tonumber(mobiled["num_devices"]) or 0
        ngx.header.content_type = "application/json"
        if mobile_num > 0 then
            ngx.print('{ "result":"suc","act":"lte" }')
        else
           ngx.print('{ "result":"fail","act":"lte" }')
        end
    elseif action == "dect" then
        content_helper.getExactContent(mmpbx_state)
	local mState = 0
        local ret = 0
        local state = args["state"]
	if mmpbx_state["state"] == "RUNNING" then
        local host_path = "sys.dect.dev."
        local host_path_value = content_helper.convertResultToObject(host_path,proxy.get(host_path))
        
        for _,v in ipairs(host_path_value) do
            local locate = format("%s",v.LocationStatus)
            if locate == "Located" then
                mState = 1
                    break
            end
        end
	end
        if(state == nil or state == "testing") then
            if mState ==  1 then
                ret = 1;
            else
                ret = -1;
            end
        elseif state == "final" then
            if mState == 1 then
                ret = 1;
            else
                ret = 0;
            end
        end

        if(ret == 1) then
            ngx.print('{ "result":"suc","act":"dect" }')
	elseif(ret == -1) then
            ngx.print('{ "result":"testing","act":"dect" }')
        else
            ngx.print('{ "result":"fail","act":"dect" }')
        end
    elseif action == "generatorBarcode" then
        local state = args["state"]
        local id = args["id"]
        local type = args["type"]
        local ext = args["extmodule"]
        local barData = createBarcode(state,id,type,ext);
        ngx.header.content_type = "application/json"
        local resState  = format("%s",state)
        local json = '{"barData":' .. '"'.. barData ..'","state":"' .. resState ..'"}'
        ngx.print(json)
    elseif action == "system_reset" then
        proxy.set("rpc.mmpbx.phonebook.flush.keepDefault", "1")
        return resetreboot("rpc.system.reset", "1")
    elseif action == "check_leds" then
    local color = format("%s",args["color"])
	if(color == "red") then
            proxy.set("sys.led.ledtest","red")
	elseif(color == "blue") then
            proxy.set("sys.led.ledtest","blue")
	elseif(color == "green") then
            proxy.set("sys.led.ledtest","green")
	end
	proxy.apply()
    elseif action == "switchDT" then
	    proxy.set("uci.mmpbxbrcmfxsdev.device.@fxs_dev_0.relay_state" , "1")
	    proxy.set("uci.mmpbxbrcmfxsdev.device.@fxs_dev_1.relay_state" , "1")
	    proxy.apply()
    end
    ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "GET" then
    local mode_active = ""

    proxy.set("uci.mmpbxbrcmfxsdev.device.@fxs_dev_0.relay_state" , "0")
    proxy.set("uci.mmpbxbrcmfxsdev.device.@fxs_dev_1.relay_state" , "0")
    proxy.set("uci.mmpbxbrcmfxonet.profile.@fxo_profile.enabled" , "1")

    proxy.set("uci.wansensing.global.enable" ,"0")
    proxy.set("uci.network.interface.@wan.proto","dhcp")
    proxy.set("uci.network.interface.@wan.ifname","eth4")
    proxy.apply()
    os.execute("sleep " .. 10)
    content_helper.getExactContent(cs)
    content_helper.getExactContent(wan_state)
    mode_active = format("%s", proxy.get("uci.network.config.wan_mode")[1].value)
    if mode_active == "" then
        mode_active = format("%s",cs.proto)
    end
	ngx.log(ngx.ERR, format("mode_activeis %s ip is %s ,mask is %s",mode_active,cs.ipaddr,cs.ipmask))
    ipaddr = format("%s",cs.ipaddr)
    ipmask = format("%s",cs.ipmask)
    if mode_active == "" or mode_active ~= "dhcp" or ipaddr == "" or ipmask == "" or find(ipaddr,"192.168.151.") == nil or ipmask ~= "27" then
        ngx.redirect("/");
    else
		local _, ipaddr_lastdig = string.match(ipaddr, "^(%d+%.%d+%.%d+%.)(%d+)$")
        local endRange = tonumber(ipaddr_lastdig) or 0
        local ssid,psk,ssid1,psk1
        if endRange >= 1 and endRange < 33 then
            ssid = "station1";
            psk = "AAAA2222";
            ssid1 = "station1_5G";
            psk1 = "AAAA3333";
		elseif endRange >= 33 and endRange < 65 then
            ssid = "station2";
            psk = "AAAA2222";
            ssid1 = "station2_5G";
            psk1 = "AAAA3333";
		elseif endRange >= 65 and endRange < 97 then
            ssid = "station3";
            psk = "AAAA2222";
            ssid1 = "station3_5G";
            psk1 = "AAAA3333";
		elseif endRange >= 97 and endRange < 129 then
            ssid = "station4";
            psk = "AAAA2222";
            ssid1 = "station4_5G";
            psk1 = "AAAA3333";
		elseif endRange >= 129 and endRange < 161 then
            ssid = "station5";
            psk = "AAAA2222";
            ssid1 = "station5_5G";
            psk1 = "AAAA3333";
		elseif endRange >= 161 and endRange < 193 then
            ssid = "station6";
            psk = "AAAA2222";
            ssid1 = "station6_5G";
            psk1 = "AAAA3333";
		elseif endRange >= 193 and endRange < 225 then
            ssid = "station7";
            psk = "AAAA2222";
            ssid1 = "station7_5G";
            psk1 = "AAAA3333";
		elseif endRange >= 225 and endRange < 255 then
            ssid = "station8";
            psk = "AAAA2222";
            ssid1 = "station8_5G";
            psk1 = "AAAA3333";
		end
        proxy.set("rpc.wireless.ssid.@wl0.ssid", ssid)
        proxy.set("rpc.wireless.ap.@ap0.security.wpa_psk_passphrase", psk)
        proxy.set("rpc.wireless.ssid.@wl1.ssid", ssid1)
        proxy.set("rpc.wireless.ap.@ap2.security.wpa_psk_passphrase", psk1)
		proxy.apply()
        ngx.log(ngx.ERR, format("endRangeis %s  --- ",endRange))
    end
end

function resetreboot(path, value)
    proxy.set(path, value)
    ngx.header.content_type = "application/json"
    ngx.print('{ "success":"true" }')
    ngx.timer.at(0, function()
        proxy.apply()
    end)
    ngx.exit(ngx.HTTP_OK)
end

function isWifiConnect(val)
    local ret = 0
    local host_path = "sys.hosts.host."
    local host_path_value = content_helper.convertResultToObject(host_path,proxy.get(host_path))
    local ret = 0
    for _,v in ipairs(host_path_value) do
        local type = format("%s",v.InterfaceType)
        if type == "wireless" then
            local interface = format("%s",v.L2Interface)
            local state = format("%s",v.State)
                if interface == val and state == "1" then
                    ret = 1
                end
        end
    end
    return ret
end
function createBarcode(state,id,type,ext)
    local barData = "";
    content_helper.getExactContent(barcode_data)
    --ngx.log(ngx.ERR, format("createBarcode state %s -- id is %s -- type is %s --- ",state,id,type))
    if barcode_data["firmware_version"] then
        local version = barcode_data["firmware_version"]
        barcode_data["firmware_version"] = barcode_data.fwversion_prefix .. sub(version, 1, find(version, "%-[^%-]*$") - 1) .. barcode_data.fwversion_suffix
        if barcode_data.fwversion_override then
            if barcode_data.fwversion_override == "override1" then
                barcode_data["firmware_version"] = barcode_data.fwversion_prefix .. sub(version, 1, find(version, "%-") -1) .. barcode_data.fwversion_suffix
            end
        end
    end
    barcode_data["model_num"] = tmpSplit(barcode_data["model_num"]," ")[2]
    if state == "pass" then
        barData = format("%s;%s;%s;%s%s;%s;%s",barcode_data["model_num"],barcode_data["pba_tocom"],barcode_data["factory_date"],barcode_data["factory_id"],barcode_data["serial_num"],barcode_data["firmware_version"],"PASS");
    elseif state == "fail" then
        local module = ""
        if type == "auto" then
            module = matchAUTOTable[format("%s",id)].module
        elseif type == "manual" then
            module = matchMANULTable[format("%s",id)].name
        end
        if ext == nil then
        else
            module = ext
        end
        barData = format("%s;%s;%s;%s%s;%s;%s",barcode_data["model_num"],barcode_data["pba_tocom"],barcode_data["factory_date"],barcode_data["factory_id"],barcode_data["serial_num"],barcode_data["firmware_version"],module);
    elseif state == "manualStop" then
        barData = format("%s;%s;%s;%s%s;%s;%s",barcode_data["model_num"],barcode_data["pba_tocom"],barcode_data["factory_date"],barcode_data["factory_id"],barcode_data["serial_num"],barcode_data["firmware_version"],"MANUALSTOP");
    end
    ngx.log(ngx.ERR, format("barData is %s",barData))
    return barData;
end

local function tabletostring(tbl)
    local tblvalue = ""
    if "table" == type(tbl) then
        for k,v in pairs(tbl) do
            if v ~= nil and v ~= "" then
                if tblvalue == "" then
                    tblvalue = format("\"%s\"",v)
                else
                    tblvalue = tblvalue .. format(",\"%s\"",v)
                end
            end
        end
    end
    return tblvalue
end
local autoTest_class = {
    button = {
        id = "btn-auto",
        class = "custom-handler"
        }
}
local tinsert = table.insert
local function createFunctionButton(content, action, param, text)
        if param ~= nil then
                tinsert(content, '<div data-bind="click: function(){ ' .. action .. '(\'' .. param .. '\'); }" class="btn float-left">'.. text .. '</div>')
        else
                tinsert(content, '<div data-bind="click: function(){ ' .. action .. '(); }" class="btn float-left">'.. text .. '</div>')
        end
end
%>
<!DOCTYPE HTML>
<%= string.format('<html lang="%s">', gettext.language()) %>
<head>
    <meta charset="UTF-8">
    <meta name="CSRFtoken" content="<%= ngx.ctx.session:getCSRFtoken() %>">
    <link href="/css/gw.css" rel="stylesheet">
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->
    <script src="/js/main-min.js" ></script>
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->
    <script src="/js/srp-min.js" ></script>
    <script language="javascript" type="text/javascript" src="/js/selftest.js"></script>
    <title><%= T"After sales tool" %></title>
</head>
<body>
<div class="container">
    <br />
    <br />
    <br />
    <br />
    <div class="row" style="text-align: center; font-size: 50px;">
        AFTER SALES TOOL
    <br />
    <br />
        <hr />
    <br />
    </div>
    <div class="row" style="text-align: center; ">
        AUTHORISED USE ONLY
    </div>
    <br />
    <div class="row" style="text-align: center; ">
        <span style= "color: #ff0000;">Note : Modem should be reset at the end of the test</span>
    </div>
</div>
<div class="container">
<div>
<br/>
<br/>
<center><div id="barcode" style="display:none"></div></center>
<br/>
<br/>
</div>
    <div class="row">
        <fieldset>
            <legend id="manualText"><%= T"Manual Test" %></legend>
                <div class="control-group">
<%
local html = {}
html[#html+1] = "<table class=\"table table-striped\" id=\"manualTable\"><thead><tr>"

html[#html + 1] = "<th style=\"width: 33%;\">MODULE</th>"
html[#html + 1] = "<th style=\"width: 33%;\">RESULT</th>"
html[#html + 1] = "<th style=\"width: 33%;\">STATUS</th>"
html[#html + 1] =  "</tr></thead><tbody>"
for key,value in ipairs(activeMANULModule) do
    html[#html + 1] =  "<tr><td>" .. matchMANULTable[value].text .."</td><td>"
    createFunctionButton(html, matchMANULTable[value].func , "pass", T"PASS")
    createFunctionButton(html, matchMANULTable[value].func, "fail", T"FAIL")
    if(matchMANULTable[value].id == "led" ) then
    html[#html + 1] =  "|"
    createFunctionButton(html, "greenBtn" , "green", T"green")
    createFunctionButton(html, "redBtn" , "red", T"red")
    createFunctionButton(html, "blueBtn" , "blue", T"blue")
    end
    html[#html + 1] =  "</td><td id=\"".. matchMANULTable[value].id .."\">UNTESTED</td></tr>"
end

html[#html + 1] =  "</tbody></table>"
ngx.print (html)
%>
            </div>
        </fieldset>
</div>

<div class="row"></div>
<div class="row"></div>
    <div class="row">
        <fieldset>
            <legend id="autoText"><%= T"Automation Test" %></legend>
                <div class="control-group">
<% 
local html = {}
html[#html+1] = "<table class=\"table table-striped\" id=\"autoTable\"><thead><tr>"

html[#html + 1] = "<th style=\"width: 50%;\">MODULE</th>"
html[#html + 1] = "<th style=\"width: 50%;\">STATUS</th>"
html[#html + 1] =  "</tr></thead>"

html[#html + 1] = "<tbody>"
for key,value in ipairs(activeAUTOModule) do
    html[#html + 1] = "<tr><td>" .. matchAUTOTable[value].text .. "</td>" .. "<td id=\"" .. matchAUTOTable[value].name .. "\"></td></tr>"
end

html[#html + 1] =  "</tbody></table>"
ngx.print (html)
%>
                </div>
<!--<div>
<div class="row"><%=ui_helper.createSimpleButton(T"Start Auto Test", "icon-ok-sign", autoTest_class)%></div>
<br/>
<br/>
<center><div id="barcode" style="display:none"></div></center>
</div>-->
            <center><div>
                <div id="stopTest" class="btn btn-primary btn-large"><%= T"STOP TEST" %></div>
                &nbsp;
                <!--<a href="/SelfTest.lp" class="btn btn-primary btn-large"><%= T"RESET" %></a>-->
                <div id="startReset" class="btn btn-primary btn-large"><%= T"RESET" %></div>
                <!--&nbsp;
                <a href="/" class="btn btn-primary btn-large"><%= T"CANCEL" %></a>-->
            </div></center>

        </fieldset>
</div>


<div class="row"><div class="copyright span12"><p>&copy; Technicolor 2014</p></div></div>
<script>
(function() {
var target = "/SelfTest.lp";
var activeArr = new Array(<%=tabletostring(activeAUTOModule)%>);
var activeMArr = new Array(<%=tabletostring(activeMANULModule)%>);

var restTestCase = activeArr.length + activeMArr.length;
var currentTest = "";
var lastTest = "";
var testComplete = 0;
var count = 0;
var refreshTimeOut = 5000;
var refreshDelay = 3000;

window.setTimeout(startAutoTest, 1500);
window.setTimeout(reset, 1800*1000);

function autoTestAllModule()
{
    if(currentTest == "")
    {
        if(activeArr.length == 0)
        return;
        currentTest = activeArr[0];
        document.getElementById(currentTest).innerHTML = "TESTING";
        $.post(
            target,
            { action: currentTest, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
            postResult,
            "json"
         );
    }
    else if(currentTest == lastTest)
    {
        var next = $.inArray(currentTest,activeArr)+1;
        if(next == activeArr.length)
        {
            return;
        }
        else
        {
            currentTest = activeArr[next];
            document.getElementById(currentTest).innerHTML = "TESTING";
            $.post(
            target,
            { action: currentTest, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
            postResult,
            "json"
            );
        }
    }
    else if(currentTest == "dsl")
    {
        var st = "";
        count++;
        if(count == 4)
        {
            count = 0;
            st = "final";
        }
        else
        {
            st = "testing";
        }
        $.post(
            target,
            { action: currentTest, state:st,CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
            postResult,
            "json"
            );
    }    
    else if(currentTest == "wifi1")
    {
        var st = "";
        count++;
        if(count == 30)
        {
            count = 0;
            st = "final";
        }
        else
        {
            st = "testing";
        }
        $.post(
            target,
            { action: currentTest, state:st,CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
            postResult,
            "json"
            );
    }
    else if(currentTest == "wifi2")
    {
        var st = "";
        count++;
        if(count == 30)
        {
            count = 0;
            st = "final";
        }
        else
        {
            st = "testing";
        }
        $.post(
            target,
            { action: currentTest, state:st,CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
            postResult,
            "json"
            );
    }
    else if(currentTest == "dect")
    {
        var st = "";
        count++;
        if(count == 28)
        {
            count = 0;
            st = "final";
        }
        else
        {
            st = "testing";
        }
        $.post(
            target,
            { action: currentTest, state:st,CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
            postResult,
            "json"
            );
    }
}


function startAutoTest(data,status)
{
    currentTest = "";
    lastTest = "";

    autoTestAllModule();

}

function setTestComplete(status,typeId,testType,exData)
{
    testComplete = 1;
    if(exData == null)
    {
        $.post(
            target,
            { action: "generatorBarcode", state:status,id:typeId,type:testType,CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
            generatorBarCode,
            "json"
        );
    }
    else
    {
        $.post(
            target,
            { action: "generatorBarcode", state:status,id:typeId,type:testType,extmodule:exData,CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
            generatorBarCode,
            "json"
        );
    }
}

function postResult(data,status)
{
    if(testComplete == 1)
        return;
    if(data.result == "suc")
        document.getElementById(data.act).innerHTML = "PASS";
    else if(data.result == "fail")
    {
        document.getElementById(data.act).innerHTML = "FAIL";
        setTestComplete("fail",data.act,"auto",data.extModuleName);
        return;
    }else if(data.result == "testing")
    {
        document.getElementById(data.act).innerHTML = "TESTING";
        window.setTimeout(autoTestAllModule, 1500);
        return;
    }

    testCaseDone();
    lastTest = data.act;
    if(testComplete == 0)
    window.setTimeout(autoTestAllModule, 1500);
}
$("#stopTest").click(function() {
    if(testComplete == 1)
        return;
    setTestComplete("manualStop","0","0",null);
    return false;
});
$("#startReset").click(function() {
    reset();
});

function wait_for_webserver_running() {
    $.ajax({ url: "/", timeout: refreshTimeOut })
    .done(function(data) {
      document.open("text/html");
      document.write(data);
      document.close();
    })
    .fail(function() {
      window.setTimeout(wait_for_webserver_running, refreshDelay);
    });
}

function wait_for_webserver_down() {
    $.ajax({ url: target, timeout: refreshTimeOut })
    .done(function() {
      window.setTimeout(wait_for_webserver_down, refreshDelay);
    })
    .fail(function() {
      window.setTimeout(wait_for_webserver_running, refreshDelay);
    });
}

function reset()
{
    $.post(
      target,
      { action: "system_reset", CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
      wait_for_webserver_down,
      "json"
    );
    return false;
}
function generatorBarCode(data,status)
{
    var code = data.barData;
    var state = data.state;
    var bg ="";
    if(state == "fail" || state == "manualStop")
    {
        bg  = "#ff0000";
    }
    else
    {
        bg  = "#000000";
    }
    var barcodeElement = document.getElementById('barcode');
    barcodeElement.style.display="";
    genbarcode({
                renderToID : 'barcode',
                string : code,
                barWidth : 1,
                height : '100',
                showText : true,
                fontColor : bg
            });
$('html, body').animate({scrollTop:0}, 'slow');
}

function processMTestResult(id,state)
{
    if(testComplete == 1 || document.getElementById(id).innerHTML != "UNTESTED")
    {
        return;
    }
    if(state == "pass")
    {
        document.getElementById(id).innerHTML = "PASS";

            if(id == "dt1")
	    {
		    $.post(
		      target,
		      { action: "switchDT", CSRFtoken: $("meta[name=CSRFtoken]").attr("content")},
		      null,
		      "json"
		    );
	    }
    }
    else
    {
        document.getElementById(id).innerHTML = "FAIL";
        setTestComplete("fail",id,"manual",null);
        return;
    }
    testCaseDone();
}

function checkLed(data)
{
    $.post(
      target,
      { action: "check_leds", CSRFtoken: $("meta[name=CSRFtoken]").attr("content"),color:data},
      null,
      "json"
    );
    return false;
}

function testCaseDone()
{
    restTestCase--;

    if(restTestCase == 0)
    {
        setTestComplete("pass","0","0",null);
    }
}

var asView = function(){
    this.ledTest = function(state) {
processMTestResult("led",state);
    };
    this.fxsTest = function(state) {
processMTestResult("fxs",state);
    };
    this.fxoTest = function(state) {
processMTestResult("fxo",state);
    };
    this.dt1Test = function(state) {
processMTestResult("dt1",state);
    };
    this.dt2Test = function(state) {
processMTestResult("dt2",state);
    };
    this.btnTest = function(state) {
processMTestResult("btn",state);
    };
    this.nfcTest = function(state) {
processMTestResult("nfc",state);
    };
    this.wpsbtnTest = function(state) {
processMTestResult("wpsbtn",state);
    };
    this.resetbtnTest = function(state) {
processMTestResult("resetbtn",state);
    };
    this.wifibtnTest = function(state) {
processMTestResult("wifibtn",state);
    };
    this.statusbtnTest = function(state) {
processMTestResult("statusbtn",state);
    };
    this.dectbtnTest = function(state) {
processMTestResult("dectbtn",state);
    };

this.redBtn = function(state) {
checkLed("red");
    };
this.greenBtn = function(state) {
checkLed("green");
    };
this.blueBtn = function(state) {
checkLed("blue");
    };


};

ko.applyBindings(asView);

}())
</script>
</div>
</body>
</html>
