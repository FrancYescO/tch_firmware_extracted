--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-qos')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local uimessage_helper = require("web.uimessage_helper")
local proxy = require("datamodel")
local table, ipairs = table, ipairs
local format, gmatch = string.format, string.gmatch
local uci_classgroup_content = {
    wan_queues = "uci.qos.classgroup.@TO_WAN.classes",
    lan_queues = "uci.qos.classgroup.@TO_LAN.classes",
}

content_helper.getExactContent(uci_classgroup_content)

local function get_queue_data(queues_string)
    local queues = format("%s", queues_string)
    local queue_table, queue_options = {}, {}
    for q in gmatch(queues, "([^%s]+)") do
        queue_table[q] = true
        queue_options[#queue_options+1] = { q, q }
    end
    return queue_table, queue_options
end

local wan_queue_table, wan_queue_options = get_queue_data(uci_classgroup_content.wan_queues)
local lan_queue_table, lan_queue_options = get_queue_data(uci_classgroup_content.lan_queues)

-- Shortcuts to validation helpers to make lines shorter
local vNES = post_helper.validateNonEmptyString
local vB = post_helper.validateBoolean
local gVIC = post_helper.getValidateInCheckboxgroup
local gVIES = post_helper.getValidateInEnumSelect
local vPN = post_helper.validatePositiveNum
local gVNIR = post_helper.getValidateNumberInRange

local policy_options = {
      {"sp", T"Strict Priority"},
      {"wrr", T"Weighted Round Robin"},
      {"sp_wrr", T"Strict Priority and Weighted Round Robin"},
}

local trafficid_options = {}
for id=0,15,1 do
    trafficid_options[#trafficid_options+1] = { tostring(id), tostring(id) }
end

local mapParams = {
    wan_queues_policy = "uci.qos.classgroup.@TO_WAN.policy",
    wan_queues_default = "uci.qos.classgroup.@TO_WAN.default",
    lan_queues_enabled = "uci.qos.interface.@lan.enable",
    lan_queues_policy = "uci.qos.classgroup.@TO_LAN.policy",
    lan_queues_default = "uci.qos.classgroup.@TO_LAN.default",
}

local function getValidatePolicy(interface)
    return function(value, object, key)
        local validate = gVIES(policy_options)
        local ok, msg = validate(value)
        if not ok then
            return ok,msg
        end

        local queues = (interface == "lan") and lan_queue_table or wan_queue_table
        if value == "sp" then
            for k,_ in pairs(queues) do
                local qid = string.match(k, "_Q(%d)")
                if object[k.."_priority"] ~= qid then
                    object[k.."_priority"] = qid
                end
                if object[k.."_weight"] ~= "" then
                    object[k.."_weight"] = ""
                end
            end
        elseif value == "wrr" then
            for k,_ in pairs(queues) do
                if object[k.."_priority"] ~= "0" then
                    object[k.."_priority"] = "0"
                end
                if object[k.."_weight"] == "" then
                    object[k.."_weight"] = "10"
                end
            end
        elseif value == "sp_wrr" then
            for k,_ in pairs(queues) do
                if object[k.."_priority"] == "0" and object[k.."_weight"] == "" then
                    object[k.."_weight"] = "10"
                end
            end
        end
        return true
    end
end

local function alwaysTrue(value)
    return true
end

local mapValid = {
    wan_queues_policy = getValidatePolicy("wan"),
    wan_queues_default = gVIES(wan_queue_options),
    lan_queues_enabled = vB,
    lan_queues_policy = getValidatePolicy("lan"),
    lan_queues_default = gVIES(lan_queue_options),
}

for k,_ in pairs(wan_queue_table) do
    mapParams[k.."_priority"] = "uci.qos.class.@" .. k .. ".priority"
    mapParams[k.."_weight"] = "uci.qos.class.@" .. k .. ".weight"
    mapValid[k.."_priority"] = alwaysTrue
    mapValid[k.."_weight"] = alwaysTrue
end

for k,v in pairs(lan_queue_table) do
    mapParams[k.."_priority"] = "uci.qos.class.@" .. k .. ".priority"
    mapParams[k.."_weight"] = "uci.qos.class.@" .. k .. ".weight"
    mapValid[k.."_priority"] = alwaysTrue
    mapValid[k.."_weight"] = alwaysTrue
end

local uci_interface, uci_device = "uci.qos.interface.", "uci.qos.device."
local content_wan_interface = content_helper.convertResultToObject(uci_interface .. "@.", proxy.get(uci_interface))
local content_wan_device = content_helper.convertResultToObject(uci_device .. "@.", proxy.get(uci_device))
local num_wan = 0
for _,v in ipairs(content_wan_interface) do
    if v.classgroup == "TO_WAN" then
        mapParams["wan_queues_enabled_" .. num_wan] = format("%s@%s.enable", uci_interface, v.paramindex)
        mapValid["wan_queues_enabled_" .. num_wan] = function(value)
            return true
        end
        num_wan = num_wan + 1
    end
end

for _,v in ipairs(content_wan_device) do
    if v.classgroup == "TO_WAN" then
        mapParams["wan_queues_enabled_" .. num_wan] = format("%s@%s.enable", uci_device, v.paramindex)
        mapValid["wan_queues_enabled_" .. num_wan] = function(value)
            return true
        end
        num_wan = num_wan + 1
    end
end

mapValid.wan_queues_enabled_0 = function(value, object, key)
    local ok,msg = vB(value)
    if not ok then
        return ok, msg
    end
    for i=1,num_wan-1 do
        object["wan_queues_enabled_" .. i] = value
    end
    return true
end

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

if content.wan_queues_enabled_0 == "" then
    content.wan_queues_enabled_0 = "1"
end
if content.lan_queues_enabled == "" then
    content.lan_queues_enabled = "1"
end

-- wan queue table
local wan_classes_columns = {
  { --1
    header = T"Name",
    name = "class_name",
    param = "paramindex",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  { --2
    header = T"Priority",
    name = "priority",
    param = "priority",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --3
    header = T"Weight",
    name = "weight",
    param = "weight",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --4
    header = T"Traffic ID",
    name = "trafficid",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --5
    header = "",
    legend = T"QoS Queue Table on Interface WAN",
    name = "wan_queues",
    type = "aggregate",
    synthesis = nil, --tod_aggregate,
    subcolumns = {
      {
        header = T"Priority",
        name = "priority",
        param = "priority",
        type = "text",
        attr = { input = { class="span2" } },
      },
      {
        header = T"Weight",
        name = "weight",
        param = "weight",
        type = "text",
        attr = { input = { class="span2" } },
      },
      {
        header = T"Traffic ID",
        name = "trafficid",
        param = "trafficid",
        type = "checkboxgroup",
        values = trafficid_options,
        attr = { checkbox = { class="inline" } },
      },
    },
  }, --[5]
  { --6
    header = T"Default",
    name = "default_queue",
    type = "text",
    readonly = true,
  },
}

local wan_classes_options = {
    tableid = "wan_classes",
    basepath = "uci.qos.class.@.",
    createMsg = T"Add new queue",
    canAdd = false,
    canDelete = false,
    sorted = "paramindex",
}

-- lan queue table
local lan_classes_columns = {
  { --1
    header = T"Name",
    name = "class_name",
    param = "paramindex",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  { --2
    header = T"Priority",
    name = "priority",
    param = "priority",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --3
    header = T"Weight",
    name = "weight",
    param = "weight",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --4
    header = T"Traffic ID",
    name = "trafficid",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --5
    header = "",
    legend = T"QoS Queue Table on Interface LAN",
    name = "wan_queues",
    type = "aggregate",
    synthesis = nil, --tod_aggregate,
    subcolumns = {
      {
        header = T"Priority",
        name = "priority",
        param = "priority",
        type = "text",
        attr = { input = { class="span2" } },
      },
      {
        header = T"Weight",
        name = "weight",
        param = "weight",
        type = "text",
        attr = { input = { class="span2" } },
      },
      {
        header = T"Traffic ID",
        name = "trafficid",
        param = "trafficid",
        type = "checkboxgroup",
        values = trafficid_options,
        attr = { checkbox = { class="inline" } },
      },
    },
  }, --[5]
  { --6
    header = T"Default",
    name = "default_queue",
    type = "text",
    readonly = true,
  },
}

local lan_classes_options = {
    tableid = "lan_classes",
    basepath = "uci.qos.class.@.",
    createMsg = T"Add new queue",
    canAdd = false,
    canDelete = false,
    sorted = "paramindex",
}

if content.wan_queues_policy == "sp" then
    table.remove(wan_classes_columns, 3)
    table.remove(wan_classes_columns[4]["subcolumns"], 2)
elseif content.wan_queues_policy == "wrr" then
    table.remove(wan_classes_columns, 2)
    table.remove(wan_classes_columns[4]["subcolumns"], 1)
end

if content.lan_queues_policy == "sp" then
    table.remove(lan_classes_columns, 3)
    table.remove(lan_classes_columns[4]["subcolumns"], 2)
elseif content.lan_queues_policy == "wrr" then
    table.remove(lan_classes_columns, 2)
    table.remove(lan_classes_columns[4]["subcolumns"], 1)
end

local function getExpectedPriority(policy, queues, qid)
    if policy == "wrr" then
        return '0'
    elseif policy == "sp" then
        return qid
    elseif policy == "sp_wrr" then
        local priorities = {}
        for k,v in ipairs(queues) do
            priorities[#priorities+1] = proxy.get("uci.qos.class.@" .. v[1] .. ".priority")[1].value
        end
        local qid_num = tonumber(qid)
        for k,v in ipairs(priorities) do
            if qid_num == 0 then
                return '0'
            elseif (k-1) < qid_num and v ~= "0" then
                return qid
            elseif k == (qid_num + 2) and v == "0" then
                return '0'
            elseif (k == (qid_num + 2) and v ~= "0") or (k == #priorities and qid_num == #priorities -1) then
                return "0 or qid"
            end
        end
    end
end

local content_params = {
    wan = { wan_classes_options, wan_queue_options },
    lan = { lan_classes_options, lan_queue_options },
}

local function getValidateWeight(interface, policy)
    return function(value, object, key)
        local weight = tonumber(value)
        if not weight or weight < 0 or weight > 63 then
            return nil, "Weight must be a integer between 0 and 63"
        end

        local classes_options = content_params[interface][1]
        local queues = content_params[interface][2]
        local qid = string.match(classes_options.changesessionindex, "_Q(%d)")
        local expected_priority = getExpectedPriority(policy, queues, qid)
        if expected_priority == "0" then
            if value == "0" then
                return nil, "Weight for queue " .. classes_options.changesessionindex .." must be a positive integer less than 64"
            end
        elseif expected_priority == qid then
            if value ~= "0" then
                return nil, "Weight for queue " .. classes_options.changesessionindex .. " must be 0"
            end
        elseif object.priority == "0" and value == "0" then
            return nil,"Weight for queue " .. classes_options.changesessionindex .." must be a positive integer less than 64"
        elseif object.priority == qid and value ~= "0" then
            return nil, "Weight for queue " .. classes_options.changesessionindex .. " must be 0"
        end
        object[key] = object[key] == "0" and "" or object[key]
        return true
    end
end


local function getValidatePriority(interface, policy)
    return function(value, object, key)
        local classes_options = content_params[interface][1]
        local queues = content_params[interface][2]

        local qid = string.match(classes_options.changesessionindex, "_Q(%d)")
        local expected_priority = getExpectedPriority(policy, queues, qid)
        if expected_priority == "0 or qid" and value ~= "0" and value ~= qid then
            return nil, "Priority for queue " .. classes_options.changesessionindex .. " .. must be 0 or queue id " .. qid
        elseif expected_priority ~= "0 or qid" and value ~= expected_priority then
            if expected_priority == "0" then
                return nil, "Priority for queue " .. classes_options.changesessionindex .." must be 0"
            else
                return nil, "Priority for queue " .. classes_options.changesessionindex .. " .. must be queue id " .. qid
            end
        end
        return true
    end
end

local classes_valid = {
    priority = getValidatePriority("wan", content.wan_queues_policy),
    weight = getValidateWeight("wan", content.wan_queues_policy),
    trafficid = gVIC(trafficid_options),
}

local function wan_classes_filter(data)
    return wan_queue_table[data["paramindex"]]
end

local wan_classes_data, wan_classes_helpmsg = post_helper.handleTableQuery(wan_classes_columns, wan_classes_options, wan_classes_filter, nil, classes_valid)

local function lan_classes_filter(data)
    return lan_queue_table[data["paramindex"]]
end

classes_valid.priority = getValidatePriority("lan", content.lan_queues_policy)
classes_valid.weight = getValidateWeight("lan", content.lan_queues_policy)

local lan_classes_data, lan_classes_helpmsg = post_helper.handleTableQuery(lan_classes_columns, lan_classes_options, lan_classes_filter, nil, classes_valid)

local function post_data_process(classes_data, queues_default, policy)
    local weight_col, weight_col2, traffic_id_col, traffic_id_col2 = 3, 2, 4, 3
    if policy == "sp" or policy == "wrr" then
        weight_col, weight_col2, traffic_id_col, traffic_id_col2 = 2, 1, 3, 2
    end
    for _,v in ipairs(classes_data) do
        for kk,vv in ipairs(v[traffic_id_col+1][traffic_id_col2]) do
            if kk == 1 then
                v[traffic_id_col] = vv
            else
                v[traffic_id_col] = v[traffic_id_col] .. ',' .. vv
            end
        end
        if v[1] == queues_default then
            v[traffic_id_col+2] = "Yes"
        else
            v[traffic_id_col+2] = "-"
        end
        if (policy == "wrr" or policy == "sp_wrr") then
            v[weight_col] = v[weight_col] == "" and "0" or v[weight_col]
            v[traffic_id_col+1][weight_col2] = v[traffic_id_col+1][weight_col2] == "" and "0" or v[traffic_id_col+1][weight_col2]
        end
    end
end

post_data_process(wan_classes_data, content.wan_queues_default, content.wan_queues_policy)
post_data_process(lan_classes_data, content.lan_queues_default, content.lan_queues_policy)

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
  uri = uri .. "?" .. ngx.var.args
end

  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"QoS", false, true) ); ngx.print('\
\
<div class="modal-body update">\
  ');  
    local tabs = {
        {
            desc = T"Queue",
            target = "modals/qos-queue-modal.lp",
            active = "active",
        },
        {
            desc = T"Classification",
            target = "modals/qos-classify-modal.lp",
        },
    }
    ngx.print(ui_helper.createModalTabs(tabs))
    ngx.print('\
  <form class="form-horizontal" method="post" action="');  ngx.print( uri ); ngx.print('">\
  ');  ngx.print(ui_helper.createMessages(uimessage_helper.popMessages())); ngx.print('\
    <fieldset>\
      <legend>');  ngx.print( T"QoS Queue Scheduling on Interface WAN" ); ngx.print('</legend>\
      ');  
        ngx.print(ui_helper.createSwitch(T"Enabled", "wan_queues_enabled_0", content["wan_queues_enabled_0"]),
            ui_helper.createInputSelect(T"Algorithm", "wan_queues_policy", policy_options, content["wan_queues_policy"]),
            ui_helper.createInputSelect(T"Default Queue", "wan_queues_default", wan_queue_options, content["wan_queues_default"])
        )
        ngx.print('\
      <legend>');  ngx.print( T"QoS Queue Table on Interface WAN" ); ngx.print('</legend>\
	  ');  ngx.print(ui_helper.createTable(wan_classes_columns, wan_classes_data, wan_classes_options, nil, wan_classes_helpmsg) ); ngx.print('\
    </fieldset>\
    <fieldset>\
      <legend>');  ngx.print( T"QoS Queue Scheduling on Interface LAN" ); ngx.print('</legend>\
      ');  
        ngx.print(ui_helper.createSwitch(T"Enabled", "lan_queues_enabled", content["lan_queues_enabled"]),
            ui_helper.createInputSelect(T"Algorithm", "lan_queues_policy", policy_options, content["lan_queues_policy"]),
            ui_helper.createInputSelect(T"Default Queue", "lan_queues_default", lan_queue_options, content["lan_queues_default"])
        )
        ngx.print('\
    </fieldset>\
    <fieldset>\
      <legend>');  ngx.print( T"QoS Queue Table on Interface LAN" ); ngx.print('</legend>\
      ');  
      --legend = T"QoS Queue Table on Interface WAN"
      --is hardcoded in 'classes_columns',but for LAN edit panel, should be "QoS Queue Table on Interface LAN", change here
        ngx.print('\
      ');  ngx.print(ui_helper.createTable(lan_classes_columns, lan_classes_data, lan_classes_options, nil, lan_classes_helpmsg)); ngx.print('\
    </fieldset>\
  </form>\
</div>\
\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 