--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local table = table
local format = string.format
local pairs, table, type, tostring = pairs, table, type, tostring
local post_content = {}

local mapValid = {
    NumberOfRepetitions = post_helper.getValidateNumberInRange(0, 10),
    DataBlockSize = post_helper.getValidateNumberInRange(0, 1000),
    ipAddress = post_helper.getOrValidation(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
}
local mapValidTrace = {
    MaxHopCount = post_helper.validatePositiveNum,
    DataBlockSizeT = post_helper.validatePositiveNum,
    Timeout = post_helper.validatePositiveNum,
    Tries = post_helper.validatePositiveNum,
    ipAddressTrace = post_helper.getOrValidation(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
}

local function restartTest(data)
    local success,msg = false, {}
    if type(data) == "table"  then
        success, msg = content_helper.validateObject(data, mapValid)
        if success then
            success = proxy.set({
                ["uci.ipping.@diagping.NumberOfRepetitions"] = data["NumberOfRepetitions"],
                ["uci.ipping.@diagping.Host"]= data["ipAddress"],
                ["uci.ipping.@diagping.DataBlockSize"]= data["DataBlockSize"],
                ["uci.ipping.@diagping.Interface"]= "",
                ["uci.ipping.@diagping.DiagnosticsState"]= "Requested",
            })
            if success then
                proxy.apply()
            end
        end
    end
    return success, msg
end

local function restartTestTrace(data)
    local success,msg = false, {}
    if type(data) == "table"  then
        success, msg = content_helper.validateObject(data, mapValidTrace)
        if success then
            success, _ = proxy.set({
                ["uci.traceroute.@diagping.Host"]= data["ipAddressTrace"],
                ["uci.traceroute.@diagping.MaxHopCount"]= data["MaxHopCount"],
                ["uci.traceroute.@diagping.Timeout"]= data["Timeout"],
                ["uci.traceroute.@diagping.DataBlockSize"]= data["DataBlockSizeT"],
                ["uci.traceroute.@diagping.NumberOfTries"]= data["Tries"],
                ["uci.traceroute.@diagping.DiagnosticsState"]= "Requested",
            })
            if success then
                proxy.apply()
            end
        end
    end
    return success, msg
end

if(not proxy.get("uci.ipping.@diagping.DiagnosticsState")) then
    proxy.add("uci.ipping.","diagping")
end

if(not proxy.get("uci.traceroute.@diagping.DiagnosticsState")) then
    proxy.add("uci.traceroute.","diagping")
end

local helpmsg = {}
local gsuccess = true
-- This code will be triggered by get and post of the button
if ngx.var.request_method == "POST" then
    local success
    gsuccess = true
    post_content = ngx.req.get_post_args()
    if post_content["action"] == "PING" then
        gsuccess, helpmsg = restartTest(post_content)
    elseif post_content["action"] == "PINGSTOP" then
        success = proxy.set("uci.ipping.@diagping.DiagnosticsState", "None")
        if success then
            proxy.apply();
        end
    elseif post_content["action"] == "TRACE" then
        gsuccess, helpmsg = restartTestTrace(post_content)
    elseif post_content["action"] == "TRACESTOP" then
        success = proxy.set("uci.traceroute.@diagping.DiagnosticsState", "None")
        if success then
            proxy.apply();
        end
    end
end

local cping = {
    ipping_state = "uci.ipping.@diagping.DiagnosticsState",
    ipping_minresptime = "uci.ipping.@diagping.MinimumResponseTime",
    ipping_maxresptime = "uci.ipping.@diagping.MaximumResponseTime",
    ipping_avgresptime = "uci.ipping.@diagping.AverageResponseTime",
    ipping_SuccessCount = "uci.ipping.@diagping.SuccessCount",
    ipping_Repetitions = "uci.ipping.@diagping.NumberOfRepetitions",
    ipping_ipAddress = "uci.ipping.@diagping.Host",
    ipping_Size = "uci.ipping.@diagping.DataBlockSize",
}

local ctracert = {
    tracert_state = "uci.traceroute.@diagping.DiagnosticsState",
    tracert_ipAddress = "uci.traceroute.@diagping.Host",
    tracert_dscp = "uci.traceroute.@diagping.DSCP",
    tracert_hopcount = "uci.traceroute.@diagping.MaxHopCount",
    tracert_size = "uci.traceroute.@diagping.DataBlockSize",
    tracert_timeout = "uci.traceroute.@diagping.Timeout",
    tracert_tries = "uci.traceroute.@diagping.NumberOfTries",
}


local rh_columns = {
    {
        header = T"Hostname",
        name = "hophost",
        param = "HopHost",
        type = "text",
        attr = { input = { class="span2" } },
    },
    {
        header = T"IP",
        name = "hophostaddress",
        param = "HopHostAddress",
        type = "text",
        attr = { input = { class="span2" } },
    },
    {
        header = T"Error code",
        name = "hoperrorcode",
        param = "HopErrorCode",
        type = "text",
        attr = { input = { class="span1"} },
    },
    {
        header = T"RTT (ms)",
        name = "hoprtttimes",
        param = "HopRTTimes",
        type = "text",
        attr = { input = { class="span1"} },
    },
}

local rh_attributes = {
}

local rh_valid = {
}

local rh_defaultObject = {
}

local rh_filter = nil

local rh_options = {
    tableid = "routehops",
    basepath = "uci.traceroute.@diagping.RouteHops.@.",
    canEdit = false,
    canAdd = false,
    canDelete = false,
}

local rh_data, rh_helpmsg = post_helper.handleTableQuery(rh_columns, rh_options, rh_filter, rh_defaultObject, rh_valid)

-- Get the content
content_helper.getExactContent(cping)
content_helper.getExactContent(ctracert)

cping.ipping_ipAddress = post_content["ipAddress"] or cping.ipping_ipAddress
cping.ipping_Repetitions = post_content["NumberOfRepetitions"] or cping.ipping_Repetitions
cping.ipping_Size = post_content["DataBlockSize"] or cping.ipping_Size

ctracert.tracert_ipAddress = post_content["ipAddressTrace"] or ctracert.tracert_ipAddress
ctracert.tracert_hopcount = post_content["MaxHopCount"] or ctracert.tracert_hopcount
ctracert.tracert_size = post_content["DataBlockSizeT"] or ctracert.tracert_size

local refresh = 2
---[[
--This code will stop the refresh when all results are available
if(cping.ipping_state ~= "Requested" and ctracert.tracert_state ~= "Requested") or not gsuccess then
    refresh = nil
end
--]]
local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
ngx.print(ui_helper.createHeader("Diagnostics Ping/Trace", true, false, refresh, help_link))   ngx.print('\
\
<div class="modal-body no-save update">\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-diagnostics.lp")
  ngx.print('\
\
<form class="form-horizontal" method="post" action="modals/diagnostics-ping-modal.lp">\
<fieldset id="diagnostics-ping-tab">\
    <legend>');  ngx.print( T"Ping Statistics" ); ngx.print('</legend>\
\
    <div class="control-group">\
        <label class="control-label"></label>\
        <div class="controls">\
        ');  if(cping.ipping_state ~= "Requested" and ctracert.tracert_state ~= "Requested") then   ngx.print('\
            <div id="send-config" class="btn" data-name="action" data-value="PING">');  ngx.print( T"Send Ping Request" ); ngx.print('</div>\
        ');  else  ngx.print('\
            <div id="send-config" class="btn"data-name="action" data-value="PINGSTOP">');  ngx.print( T"Stop Ping Request" ); ngx.print('</div>\
        ');  end  ngx.print('\
        </div>\
    </div>\
\
    ');  
    local html = {}
    local attributes = { span = { class = "span8" } }
    local advanced = { span = { class = "span8" }, group = { class = "advanced hide" } }
    local attrPing = {input = { ["data-for"] = "PING"}}
    local attrTrace = {input = { ["data-for"] = "TRACE"}}
    local explanationPing = ""
    local statusIconPing = ""
    local ippingSuccessCount = ""
    local explanationTrace = ""
    local statusIconTrace = ""

    local statusPingTest = proxy.get("uci.ipping.@diagping.DiagnosticsState")
    local statusTracertTest = proxy.get("uci.traceroute.@diagping.DiagnosticsState")

    if ngx.var.request_method == "POST" and gsuccess then
        ippingSuccessCount = cping.ipping_SuccessCount
        if statusPingTest then
            statusPingTest = statusPingTest[1].value
            if statusPingTest == "Complete" then
                if cping.ipping_Repetitions == cping.ipping_SuccessCount then
                    statusIconPing = "<i class=\"icon-ok icon-large green\"></i> "
                    explanationPing = T"Success"
                else
                    statusIconPing = "<i class=\"icon-ban-circle icon-large red\"></i>"
                    explanationPing = T"Not all ping request have been answered"
                end
            elseif statusPingTest == "Requested" then
                statusIconPing = "<i class=\"icon-asterisk icon-large blue\"></i> "
                explanationPing = T"Ongoing"
            elseif statusPingTest ~= "None" then
                statusIconPing = "<i class=\"icon-ban-circle icon-large red\"></i>"
                explanationPing = T"Failed"
            end
        else
            statusIconPing = "<i class=\"icon-ban-circle icon-large red\"></i>"
            explanationPing = T"Not Connected"
        end

        if statusTracertTest then
            statusTracertTest = statusTracertTest[1].value
            if statusTracertTest == "Complete" then
                statusIconTrace = "<i class=\"icon-ok icon-large green\"></i> "
                explanationTrace = T"Finished"
            elseif statusTracertTest == "Requested" then
                statusIconTrace = "<i class=\"icon-asterisk icon-large blue\"></i> "
                explanationTrace = T"Ongoing"
            elseif statusTracertTest ~= "None" then
                statusIconTrace = "<i class=\"icon-ban-circle icon-large red\"></i>"
                explanationTrace = T"Failed"
            end
        else
            statusIconTrace = "<i class=\"icon-ban-circle icon-large red\"></i>"
            explanationTrace = T"Not Connected"
        end
    end

    html[#html+1] = ui_helper.createLabel(T"Status:", format("%s %s", statusIconPing, explanationPing), attributes)
    html[#html+1] = ui_helper.createLabel(T"Success Count:", ippingSuccessCount)
    html[#html+1] = ui_helper.createInputText(T"IP address:","ipAddress", cping.ipping_ipAddress, attrPing, helpmsg["ipAddress"])
    html[#html+1] = ui_helper.createInputText(T"Number of pings:","NumberOfRepetitions", cping.ipping_Repetitions, attrPing, helpmsg["NumberOfRepetitions"])
    html[#html+1] = ui_helper.createInputText(T"Size (bytes):","DataBlockSize", cping.ipping_Size, attrPing, helpmsg["DataBlockSize"])
    html[#html+1] = ui_helper.createLabel(T"Min Resp Time:", format("%s ms", cping.ipping_minresptime),advanced)
    html[#html+1] = ui_helper.createLabel(T"Max Resp Time:", format("%s ms", cping.ipping_maxresptime),advanced)
    html[#html+1] = ui_helper.createLabel(T"Avg Resp Time:", format("%s ms", cping.ipping_avgresptime),advanced)
    ngx.print(html)
      ngx.print('\
</fieldset>\
<fieldset id="diagnostics-tracert-tab">\
        <legend>');  ngx.print( T"Trace Route" ); ngx.print('</legend>\
\
        <div class="control-group">\
        <label class="control-label"></label>\
        <div class="controls">\
        ');  if(cping.ipping_state ~= "Requested" and ctracert.tracert_state ~= "Requested" ) then   ngx.print('\
            <div id="send-config" class="btn" data-name="action" data-value="TRACE">');  ngx.print( T"Trace Route" ); ngx.print('</div>\
        ');  else  ngx.print('\
            <div id="send-config" class="btn" data-name="action" data-value="TRACESTOP">');  ngx.print( T"Stop Trace Route" ); ngx.print('</div>\
        ');  end  ngx.print('\
        </div>\
    </div>\
\
    <div style="max-width:880px;overflow-x:auto;">\
    ');  
    local html = {}
    html[#html+1] = ui_helper.createLabel(T"Status:", format("%s %s", statusIconTrace, explanationTrace), attributes)
    html[#html+1] = ui_helper.createInputText(T"IP address:","ipAddressTrace", ctracert.tracert_ipAddress, attrTrace, helpmsg["ipAddressTrace"])
    --	html[#html+1] = ui_helper.createInputText(T"Timeout:","Timeout", ctracert.tracert_timeout, attrTrace, helpmsg["Timeout"])
    html[#html+1] = ui_helper.createInputText(T"Max Hop Count:","MaxHopCount", ctracert.tracert_hopcount, attrTrace, helpmsg["MaxHopCount"])
    html[#html+1] = ui_helper.createInputText(T"Size (bytes):","DataBlockSizeT", ctracert.tracert_size, attrTrace, helpmsg["DataBlockSizeT"])
    --	html[#html+1] = ui_helper.createInputText(T"Tries:","Tries", ctracert.tracert_tries, attrTrace, helpmsg["Tries"])
    html[#html+1] = ui_helper.createTable(rh_columns, rh_data, rh_options, rh_attributes, rh_helpmsg)
    ngx.print(html)
      ngx.print('\
    </div>\
</fieldset>\
</form>\
</div>\
<div class="modal-footer">\
    <div id="modal-no-change">\
        <div class="btn btn-primary btn-large" data-dismiss="modal">Close</div>\
    </div>\
</div>\
\
'); 