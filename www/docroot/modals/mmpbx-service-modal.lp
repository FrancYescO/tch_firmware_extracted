<%

-- Enable localization
gettext.textdomain('webui-voice')

local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require ("web.content_helper")

local services_with_dest = {
  ["WARMLINE"] = true,
  ["CFU"] = true,
  ["CFNR"] = true,
  ["CFBS"] = true,
}

local configfiles = {
    ["fxs"] = "mmpbxbrcmfxsdev",
    ["dect"] = "mmpbxbrcmdectdev",
    ["sipdev"] = "mmpbxrvsipdev",
}

local service_status_map = {
    ["0"] = T"Disabled",
    ["1"] = T"Enabled",
}

local device_types = {"fxs", "dect", "sipdev",}
local device_friendlynames = {}
local content_services = {}
local content_warmline_service = {}

local function sorting(x,y)
    local cx = x:sub(1,1)
    local cy = y:sub(1,1)

    if cx == cy then
        return x < y
    end
    if cx == "f" then
        return true
    end
    if cx == "s" then
        if cy == "f" then
            return false
        else
            return true
        end
    end
    if cx == "i" then
        return false
    end
end

local function pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0      -- iterator variable
    local iterator = function()   -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iterator
end

local function getService()
    local type, index, path = nil, 0, ""
    local content = {}
    local results = proxy.get("uci.mmpbx.service.")
    if results then
        for _,v in ipairs(results) do
            if path == "" or not v.path:match(path) then
                if type then
                    for kk,vv in pairs(content) do
                        content_services[type][kk] = content[kk]
                    end
                end
                type = nil
                content = {}
                path = v.path
            end

            v.value = string.format("%s", v.value)
            if v.param == "type" then
                type = v.value
                if not content_services[type] then
                    content_services[type] = {}
                end
                content_services[type]["path"] = v.path
                if type == "WARMLINE" then
                    content_warmline_service[#content_warmline_service + 1] = {}
		    content_warmline_service[#content_warmline_service] ["path"]  = v.path
		end
            else
                local t = nil
                if v.path:match(path .. "profile") then
                    t = "profile"
                elseif v.path:match(path .. "device") then
                    t = "device"
                end
                if t then
                    if not content_services[type][t] then
                        content_services[type][t] = {}
                    end
                    index = #content_services[type][t]
                    content_services[type][t][index + 1] = v.value
                else
                    content[v.param] = v.value
                end
            end
        end
        if type then
            for kk,vv in pairs(content) do
                content_services[type][kk] = content[kk]
            end
        end
    end
end

local function sorting_warmline(x,y)
    -- The devices types in voice are FXS, DECT & SIPDEV.
    -- We need to display the devices in FXS, SIPDEV, DECT order.
    -- For sorting we will take the first letter in the device names i.e. “f”, ”d” & “s” and sort them.

    local cx = x["device"]:sub(1,1)
    local cy = y["device"]:sub(1,1)

    if cx == cy then
        return x["device"] < y["device"]
    end
    if cx == "f" then
        return true
    end
    if cx == "s" then
        if cy == "f" then
            return false
        else
            return true
        end
    end
    if cx == "d" then
        return false
    end

    return true
end

local function getWarmlineServiceinfo()
    for i,w in ipairs(content_warmline_service) do
	local results = proxy.get(w.path)
	if results then
	    for _,v in ipairs(results) do
               local t = nil
                if v.path:match(w.path .. "profile") then
                    t = "profile"
                elseif v.path:match(w.path .. "device") then
                    t = "device"
                end
                if t then
		    content_warmline_service[i][t] = string.format("%s", v.value)
               else
                    content_warmline_service[i][v.param] = v.value
                end
             end
	end
    end
    table.sort(content_warmline_service, sorting_warmline)
end

local function getSccEntry()
    local pattern, type, action = nil, nil, nil
    local index, path = 0, ""
    local results = proxy.get("uci.mmpbx.scc_entry.")
    if results then
        for _,v in ipairs(results) do
            if path == "" then
                path = v.path
            end

            if not v.path:match(path) then
                if type and action and pattern then
                    if not content_services[type] then
                        content_services[type] = {}
                    end
                    content_services[type][action] = pattern
                end
                pattern, type, action  = nil, nil, nil
                path = v.path
            end
            v.value = string.format("%s", v.value)
            if v.param == "pattern" then
                pattern = v.value
            elseif v.param == "service_type" then
                type = v.value
            elseif v.param == "action" then
                action = v.value
            end
        end
        if type and action and pattern then
            if not content_services[type] then
                content_services[type] = {}
            end
            content_services[type][action] = pattern
        end
    end
end

local function getDeviceFriendlyNames()
    local devpattern = "([^%._@]+_dev_%d+)"
    local results, dev = nil, ""
    for _,t in ipairs(device_types) do
        results = proxy.get("uci." .. configfiles[t] .. ".device.")
        if results then
            for _,v in ipairs(results) do
                if v.param == "user_friendly_name" then
                    dev = v.path:match(devpattern)
                    device_friendlynames[dev] = string.format("%s", v.value)
                end
            end
        end
    end
end

getService()
getWarmlineServiceinfo()
getSccEntry()
getDeviceFriendlyNames()

local helpmsg = {}
local service_name = {}
local select_name = nil

if ngx.req.get_method() == "POST" then
    local success = false
    local post_args = ngx.req.get_post_args()
    local mapValid = {}

    select_name = string.format("%s", post_args["service_name"])
    if (post_args["service_name"] == "WARMLINE") then
        local gVCS = post_helper.getValidateCheckboxSwitch()

	for i in ipairs(content_warmline_service) do
	    mapValid["activatedWARMLINE_"..i] = gVCS
	    mapValid["timeoutWARMLINE_"..i] = post_helper.validatePositiveNum
	    mapValid["destinationWARMLINE_"..i] = post_helper.validatePositiveNum
	end
    else
	mapValid["timeout"..select_name] = post_helper.validatePositiveNum
        mapValid["destination"..select_name] = post_helper.validatePositiveNum
    end
    success, helpmsg = content_helper.validateObject(post_args, mapValid)
    -- For security, check for service type if HOLD skip POST processing
    if (success and post_args["service_name"] ~= "HOLD") then
        local content_set = {}
	local content = {}
	local path = ""
        if (post_args["service_name"] == "WARMLINE") then
	    for i in ipairs(content_warmline_service) do
		path = content_warmline_service[i]["path"]
	        if post_args["activatedWARMLINE_"..i] then
		    local value = string.format("%s", post_args["activatedWARMLINE_"..i])
                    content_set[path .. "activated"] = value
                    content["activatedWARMLINE_"..i] = value
		end
	        if post_args["timeoutWARMLINE_"..i] then
		    local value = string.format("%s", post_args["timeoutWARMLINE_"..i])
                    content_set[path .. "timeout"] = value
                    content["timeoutWARMLINE_"..i] = value
		end
	        if post_args["destinationWARMLINE_"..i] then
		    local value = string.format("%s", post_args["destinationWARMLINE_"..i])
                    content_set[path .. "destination"] = value
                    content["destinationWARMLINE_"..i] = value
		end
	    end
	else
            path = content_services[select_name]["path"]
            for _,v in ipairs({"activated", "cw_reject_persistency", "destination", "timeout"}) do
                if post_args[v .. select_name] then
                    local value = string.format("%s", post_args[v .. select_name])
                    content_set[path .. v] = value
                    content[v] = value
                end
            end
        end
        if proxy.set(content_set) then
            proxy.apply()
	    if(post_args["service_name"] == "WARMLINE") then
		for i in ipairs(content_warmline_service) do
		    content_warmline_service[i]["activated"] = content["activatedWARMLINE_"..i]
		    content_warmline_service[i]["timeout"] = content["timeoutWARMLINE_"..i]
		    content_warmline_service[i]["destination"] = content["destinationWARMLINE_"..i]
		end
	    else
                for k,v in pairs(content) do
                    content_services[select_name][k] = v
                end
	    end
        end
    end
end

local scc_columns = {
    { header = T"Services", },
    { header = T"Register", },
    { header = T"Register & Activate", },
    { header = T"Activate", },
    { header = T"Deactivate", },
    { header = T"Deactivate & Erase", },
    { header = T"Interrogate", },
}

local scc_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "scc",
}

-- SCC column number
local scns = {
    ["service"] = 1,
    ["register"] = 2,
    ["register_activate"] = 3,
    ["activate"] = 4,
    ["deactivate"] = 5,
    ["deactivate_erase"] = 6,
    ["interrogate"] = 7,
}
-- for Service Code Command table
local scc_data = {}
local l = 1

-- for Service configuration
local html = {
    [1] = ""
}
local baseclass = "monitor-service_name"
local attribute = {}
local strdisplay = ""

for k,v in pairsByKeys(content_services) do
    if v["provisioned"] == "1" then
        scc_data[l] = {}
        scc_data[l][scns["service"]] = k
        scc_data[l][scns["register"]] = v["register"] or ""
        scc_data[l][scns["register_activate"]] = v["register_activate"] or ""
        scc_data[l][scns["activate"]] = v["activate"] or ""
        scc_data[l][scns["deactivate"]] = v["deactivate"] or ""
        scc_data[l][scns["deactivate_erase"]] = v["deactivate_erase"] or ""
        scc_data[l][scns["interrogate"]] = v["interrogate"] or ""
        l = l + 1
        service_name[#service_name + 1] = {k, k}

        attribute = {
           group={
                 class = baseclass .. " monitor-".. k
           }
        }
        if k == "WARMLINE" then
	    --For warmline need to create table
	    local attrSwitch = {
		switch = {
		    class = "switch"
		},
	    }
	    --Creating Table Header
	    html[#html + 1] =  "<div class=\"control-group monitor-service_name monitor-WARMLINE\">"
	    html[#html + 1] =  "<table class=\"table table-striped\"> <thead><tr>"
	    html[#html + 1] = "<th>Device</th> <th>Activate</th> <th>Destination No.</th> <th>TimeOut</th>"
	    html[#html + 1] =  "</tr></thead>"

	    html[#html + 1] = "<tbody>"

            for i,v in ipairs(content_warmline_service) do
                html[#html + 1] = "<tr>"

                html[#html + 1] = "<td>"
		html[#html + 1] =  device_friendlynames[v["device"]]
		html[#html + 1] = "</td>"

		html[#html + 1] = "<td>"
		html[#html + 1] =  ui_helper.createSimpleCheckboxSwitch("activatedWARMLINE_" ..i , v["activated"], attrSwitch)
		html[#html + 1] = "</td>"

		html[#html + 1] = "<td>"
		html[#html + 1] =  ui_helper.createSimpleInputText("destinationWARMLINE_"..i, v["destination"], nil, helpmsg["destinationWARMLINE_" .. i])
		html[#html + 1] = "</td>"

		html[#html + 1] = "<td>"
		html[#html + 1] =  ui_helper.createSimpleInputText("timeoutWARMLINE_"..i, v["timeout"], nil, helpmsg["timeoutWARMLINE_"..i])
		html[#html + 1] = "</td>"

		html[#html + 1] = "</tr>"
	    end

	    html[#html + 1] =  "</tbody></table>"
	    html[#html + 1] =  "</div>"
	else
            if v["profile"] then
                table.sort(v["profile"], sorting)
		strdisplay = ""
                strdisplay = table.concat(v["profile"], "<br> ")
                html[#html + 1] = ui_helper.createLabel(T"Profile", strdisplay, attribute)
	    end

            if v["device"] then
                table.sort(v["device"], sorting)
		strdisplay = ""
		for _,name in ipairs(v["device"]) do
		    strdisplay = strdisplay .. device_friendlynames[name] .. "<br> "
                end
		strdisplay = strdisplay:sub(1, -6)
		html[#html + 1] = ui_helper.createLabel(T"Device", strdisplay, attribute)
            end
            if tonumber(v["activated"]) then
                -- In case of service HOLD we do not allow it to changed from GUI, display only
                if k == "HOLD" then
                    html[#html + 1] = ui_helper.createLabel(T"Activate", service_status_map[v["activated"]], attribute)
                else
                    html[#html + 1] = ui_helper.createSwitch(T"Activate", "activated" .. k, v["activated"], attribute)
                end
            end

            if tonumber(v["cw_reject_persistency"]) then
                html[#html + 1] = ui_helper.createSwitch(T"CW Reject Persistency", "cw_reject_persistency" .. k, v["cw_reject_persistency"], attribute)
            end

            if tonumber(v["destination"]) then
                html[#html + 1] = ui_helper.createInputText(T"Destination", "destination" .. k, v["destination"], attribute, helpmsg["destination" .. k])
            elseif services_with_dest[k] then
                html[#html + 1] = ui_helper.createInputText(T"Destination", "destination" .. k, "", attribute, helpmsg["destination" .. k])
	    end

            if tonumber(v["timeout"]) then
                html[#html + 1] = ui_helper.createInputText(T"TimeOut", "timeout" .. k, v["timeout"], attribute, helpmsg["timeout" .. k])
            end
        end
    end
end

attribute = {
    select = {
        class ="monitor-changes no-save",
    },
}

select_name = select_name or service_name[1]
html[1] = ui_helper.createInputSelect(T"Service Name", "service_name", service_name, select_name, attribute)

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

%>

<%= ui_helper.createHeader(T"Telephony", false, true) %>

<div class="modal-body update">
  <%
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-voice.lp")
  %>
  <form class="form-horizontal" method="post" action="<%= uri %>">
    <fieldset>
      <legend><%= T"Config VOIP Services" %></legend>
      <%
        ngx.print(html)
      %>
    </fieldset>
  </form>

  <fieldset>
    <legend><%= T"Service Code Command" %></legend>
    <%= ui_helper.createTable(scc_columns, scc_data, scc_options, nil, nil) %>
  </fieldset>
</div>

<%= ui_helper.createFooter() %>

<script>
$(document).ready(function() {
    $('input[type="checkbox"]').click(function(){
        $('#modal-no-change').fadeOut(300);
        $('#modal-changes').delay(350).fadeIn(300);
	$(document).off("change")
    });
    $('input[type="text"]').click(function(){
        $('#modal-no-change').fadeOut(300);
        $('#modal-changes').delay(350).fadeIn(300);
    });
});
</script>
