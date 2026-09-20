--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')
-- Process POST query

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local portslist = require("portslist_helper")
local hosts_ac, hosts_ac_v6 = require("web.uinetwork_helper").getAutocompleteHostsList()
local pairs, table = pairs, table
local remove = table.remove
local format = string.format

local outgoingpolicy = {
    {"ACCEPT", T"ACCEPT"},
    {"DROP", T"DROP"},
    {"REJECT", T"REJECT"},
}

local incomingpolicy = {
    {"DROP", T"DROP"},
    {"REJECT", T"REJECT"},
}

local fw_levels = {
    {"lax", T"<strong>Low</strong>"},
    {"normal", T"<strong>Normal</strong>"},
    {"high", T"<strong>High</strong>"},
    {"user", T"<strong>User defined</strong>"}
}

local fw_params = {
    fw_ping = "rpc.network.firewall.internetping",
    fw_level = "rpc.network.firewall.mode",
    fw_outgoing_policy = "rpc.network.firewall.useroutgoingdefault",
    fw_incoming_policy = "rpc.network.firewall.userincomingdefault",
}

-- Retrieve GW IP + netmask for use by validation function
local ipdetails = {
    gw = "uci.network.interface.@lan.ipaddr",
    netmask = "uci.network.interface.@lan.netmask"
}
content_helper.getExactContent(ipdetails)

-- Shortcuts to validation helpers to make lines shorter
local gVIES = post_helper.getValidateInEnumSelect
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP
local vSIP = post_helper.validateStringIsPort
local vSIPR = post_helper.validateStringIsPortRange
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local gVP = post_helper.getValidationPassword
local gVSIDIP = post_helper.getValidateStringIsDeviceIPv4
local gOV = post_helper.getOptionalValidation
local vSIDIP = gVSIDIP(ipdetails.gw, ipdetails.netmask)
local vSIIv6 = post_helper.validateStringIsIPv6

local fw_valid = {
    fw_ping = post_helper.getValidateCheckboxSwitch(),
    fw_level = gVIES(fw_levels),
    fw_outgoing_policy = gVIES(outgoingpolicy),
    fw_incoming_policy = gVIES(incomingpolicy),
}

local content = post_helper.handleQuery(fw_params, fw_valid)

-- Firewall rules
local function fwrule_sort(rule1, rule2)
  return tonumber(rule1.paramindex) < tonumber(rule2.paramindex)
end

local fwrules_targets = {
    { "ACCEPT", "ACCEPT"},
    { "DROP", "DROP"},
    { "REJECT", "REJECT"},
}

local fwrules_protocols = {
    { "tcp", T"TCP"},
    { "udp", T"UDP"},
    { "tcpudp", T"TCP/UDP"},
    { "udplite", T"UDPLite"},
    { "icmp", T"ICMP"},
    { "esp", T"ESP"},
    { "ah", T"AH"},
    { "sctp", T"SCTP"},
    { "all", T"all"},
}

local fwrule_columns = {
  {
    header = "",
    name = "enabled",
    param = "enabled",
    type = "checkboxswitch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Action",
    name = "target",
    param = "target",
    default = "DROP",
    type = "select",
    values = fwrules_targets,
    attr = { select = { class="span1" } },
  },
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto",
    default = "tcp",
    type = "select",
    values = fwrules_protocols,
    attr = { select = { class="span1" } },
  },
  {
    header = T"Src IP",
    name = "src_ip",
    param = "src_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15"}, autocomplete = hosts_ac },
  },
  {
    header = T"Src port",
    name = "src_port",
    param = "src_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" }, autocomplete = portslist },
  },
  {
    header = T"Dst IP",
    name = "dest_ip",
    param = "dest_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15"} },
  },
  {
    header = T"Dst port",
    name = "dest_port",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" }, autocomplete = portslist },
  },
}

local fwrule_options = {
    tableid = "fwrules",
    basepath = "rpc.network.firewall.userrule.@.",
    createMsg = T"Add new firewall rule",
    sorted = fwrule_sort
}

local duplicatedErrMsg = nil
local session = ngx.ctx.session
--[[
   The following function used to validate the duplicate entries while adding or editing on firewall table.
   We will throw the duplicate error if any row contains all the 4 values are duplicatd
   Sample:- Src IP        Src port      Dst IP           Dst port
            192.168.1.1   1000          192.168.1.4      2000
            192.168.1.1   1000          192.168.1.5      2000
            192.168.1.1   1000          192.168.1.5      2001
            192.168.1.1   1000          192.168.1.5      2000
   In above example the 4th and 2nd rows are exactly duplicated. In this case we throw the error message as duplicated.
   If anyone of the value of row is different then we dont consider as duplicated row.
]]
local function rulesDuplicateCheck(basepath,tableid,columns)
  return function(value, postdata, key)
  local sucess,msg
    if value and value ~= "" then
      sucess,msg = vSIPR(value, postdata, key)
    else
      sucess = true
    end
    if sucess then
      local startIndex, endIndex= 3,7
      local fullpath = nil
      if postdata.action =="TABLE-MODIFY" then
        local index = tonumber(postdata.index)
        local tablesessionindexes = tableid..".allowedindexes"
        local allowedIndexes = session:retrieve(tablesessionindexes) or {}
        if allowedIndexes[index] then
          index = allowedIndexes[index].paramindex
        end
        -- fullpath => The UCI path which is going to be modifed, Ex: rpc.network.firewall.userrule.@4.
        fullpath = basepath .. "@"..index.."."
      end
      local paths=nil
      for i=startIndex, endIndex do
        local value = string.untaint(postdata[columns[i].name])
        local cmatch = content_helper.getMatchedContent(basepath, {[columns[i].param] = value })
        if fullpath then
          for u,v in ipairs(cmatch) do
            if v.path == fullpath then
            --The rpc.network.firewall.userrule.@4. will be removed
            --because we no need to validate with the path which we need to modify
              remove(cmatch, u)
              break
            end
          end
        end
        -- If cmatch is empty then there will be no duplicated rows in UCI.
        if #cmatch > 0 then
        -- The below condition will be true at first iteration.
          if i == startIndex then
            -- At the first iteration the duplicate paths will be stored in a temp table
            -- which can be used to validate with duplicate path of subsequest columns
            paths={}
            for _,v in ipairs(cmatch) do
              paths[v.path]=true
            end
          -- If path is empty then no duplicates in previous columns. So we can break the loop and can say no duplicates
          elseif paths then
            local duplicate = {}
            local flag = false
            for _,v in ipairs(cmatch) do
              if paths[v.path] then
                duplicate[v.path] = true
                flag = true
              end
            end
            -- if current duplicated path is not matching with previouse duplicatd paths.
            -- Then there is no exact duplicated rows.
            if flag then
              paths = duplicate
            else
               paths = nil
               break
            end
          else
            paths = nil
            break
          end
        else
          paths=nil
          break
        end
      end
      --Finally if you get one or more paths which contain all
      --the 4 values are duplicated (sr ip,port and dest ip, port) are duplicated
      if paths then
          sucess = nil
          msg = T"duplicate value"
          duplicatedErrMsg = msg
      end
    end
    return sucess, msg
  end
end

local fwrule_valid = {
    enabled = post_helper.getValidateCheckboxSwitch(),
    target = gVIES(fwrules_targets),
    protocol = gVIES(fwrules_protocols),
    src_ip = gOV(vSIDIP),
    src_port = gOV(vSIPR),
    dest_ip = gOV(vSII),
    dest_port = rulesDuplicateCheck("rpc.network.firewall.userrule.", "fwrules",fwrule_columns),
}

local fwrule_defaultObject = {
    src = "lan",
    dest = "wan"
}

local fwrule_data, fwrule_helpmsg = post_helper.handleTableQuery(fwrule_columns, fwrule_options, nil, fwrule_defaultObject, fwrule_valid)

if duplicatedErrMsg then
  fwrule_helpmsg.src_ip = duplicatedErrMsg
  fwrule_helpmsg.src_port = duplicatedErrMsg
  fwrule_helpmsg.dest_ip = duplicatedErrMsg
  fwrule_helpmsg.dest_port = duplicatedErrMsg
  duplicatedErrMsg = nil
end

local fwrules_protocols_v6 = {
    { "tcp", T"TCP"},
    { "udp", T"UDP"},
    { "tcpudp", T"TCP/UDP"},
    { "udplite", T"UDPLite"},
    { "icmpv6", T"ICMPv6"},
    { "esp", T"ESP"},
    { "ah", T"AH"},
    { "sctp", T"SCTP"},
    { "all", T"all"},
}

local fwrule_v6_columns = {
  {
    header = "",
    name = "enabled_v6",
    param = "enabled",
    type = "checkboxswitch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Action",
    name = "target_v6",
    param = "target",
    default = "DROP",
    type = "select",
    values = fwrules_targets,
    attr = { select = { class="span1" } },
  },
  {
    header = T"Protocol",
    name = "protocol_v6",
    param = "proto",
    default = "tcp",
    type = "select",
    values = fwrules_protocols_v6,
    attr = { select = { class="span1" } },
  },
  {
    header = T"Src IP",
    name = "src_ip_v6",
    param = "src_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="39"} },
  },
  {
    header = T"Src port",
    name = "src_port_v6",
    param = "src_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" }, autocomplete = portslist },
  },
  {
    header = T"Dst IP",
    name = "dest_ip_v6",
    param = "dest_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="39"}, autocomplete = hosts_ac_v6 },
  },
  {
    header = T"Dst port",
    name = "dest_port_v6",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" }, autocomplete = portslist },
  },
}

local fwrule_v6_options = {
    tableid = "fwrules_v6",
    basepath = "rpc.network.firewall.userrule_v6.@.",
    createMsg = T"Add new IPv6 firewall rule",
    sorted = fwrule_sort
}

local fwrule_v6_valid = {
    enabled_v6 = post_helper.getValidateCheckboxSwitch(),
    target_v6 = gVIES(fwrules_targets),
    protocol_v6 = gVIES(fwrules_protocols_v6),
    src_ip_v6 = gOV(vSIIv6),
    src_port_v6 = gOV(vSIPR),
    dest_ip_v6 = gOV(vSIIv6),
    dest_port_v6 = rulesDuplicateCheck("rpc.network.firewall.userrule_v6.", "fwrules_v6",fwrule_v6_columns),
}

local fwrule_v6_data, fwrule_v6_helpmsg = post_helper.handleTableQuery(fwrule_v6_columns, fwrule_v6_options, nil, fwrule_defaultObject, fwrule_v6_valid)

if duplicatedErrMsg then
  fwrule_v6_helpmsg.src_ip_v6 = duplicatedErrMsg
  fwrule_v6_helpmsg.src_port_v6 = duplicatedErrMsg
  fwrule_v6_helpmsg.dest_ip_v6 = duplicatedErrMsg
  fwrule_v6_helpmsg.dest_port_v6 = duplicatedErrMsg
end

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Firewall", true, false, nil, help_link) ); ngx.print('\
\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/firewall-modal.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<fieldset>\
<legend>');  ngx.print( T"Firewall level" ); ngx.print('</legend>\
\
');  
    local html = {}

    local fwlevel_attr = {
        group = {
            class = ""
        },
        select = {
            class = "monitor-changes"
        }
    }
    html[#html+1] = ui_helper.createInputSelect(T"Level", "fw_level", fw_levels, content["fw_level"], fwlevel_attr)

    local lax_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-lax"
        },
    }
    html[#html+1] = ui_helper.createAlertBlock(T"In <strong>low mode</strong>, the firewall will allow all outgoing connections. It will reject unknown incoming connections but acknowledge the presence of the gateway.", lax_attr)

    local normal_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-normal"
        },
    }
    html[#html+1] = ui_helper.createAlertBlock(T"In <strong>normal mode</strong>, the firewall will allow all outgoing connections. It will silently drop unknown incoming connections.", normal_attr)

    local high_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-high"
        },
    }
    html[#html+1] = ui_helper.createAlertBlock(T"In <strong>high mode</strong>, the firewall will allow outgoing connections to the following services: HTTP, HTTPS, SMTP, POP3, IMAP, SSH. It will silently drop unknown incoming connections.", high_attr)

    local user_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-user"
        },
    }
    html[#html+1] = ui_helper.createAlertBlock(T"In <strong>user defined mode</strong>, you can configure each individual rule of the firewall as well as the default behavior.", user_attr)

    ngx.print(html)
  ngx.print('\
</fieldset>\
\
<fieldset>\
<legend>');  ngx.print( T"Firewall default behavior" ); ngx.print('</legend>\
\
');  
    local html = {}
    html[#html+1] = ui_helper.createCheckboxSwitch(T"Answer Internet ping", "fw_ping", content["fw_ping"])

    local outgoing_attr = {
        group = {
            class = "monitor-fw_level monitor-user"
        }
    }

    local info_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-user"
        },
    }

    html[#html+1] = ui_helper.createInputSelect(T"Outgoing default policy", "fw_outgoing_policy", outgoingpolicy, content["fw_outgoing_policy"], outgoing_attr)
    html[#html+1] = ui_helper.createAlertBlock(T"The <strong>outgoing policy</strong> defines what is done with packets coming from the LAN devices toward the internet. Setting it to REJECT or DROP will forbid any internet traffic from the LAN unless explicitely allowed by a firewall rule.", info_attr)

    html[#html+1] = ui_helper.createInputSelect(T"Incoming default policy", "fw_incoming_policy", incomingpolicy, content["fw_incoming_policy"], outgoing_attr)
    html[#html+1] = ui_helper.createAlertBlock(T"The <strong>incoming policy</strong> defines what is done with packets destined to the gateway. They can be either REJECTED (the gateway will notify the sender they were rejected) or DROPPED (the gateway will silently discard those packets).", info_attr)

    ngx.print(html)
  ngx.print('\
\
\
</fieldset>\
\
<fieldset class="monitor-fw_level monitor-user">\
<legend>');  ngx.print( T"Firewall rules" ); ngx.print('</legend>\
');  ngx.print(ui_helper.createTable(fwrule_columns, fwrule_data, fwrule_options, nil, fwrule_helpmsg)); ngx.print('\
\
<legend>');  ngx.print( T"Firewall rules for IPv6" ); ngx.print('</legend>\
');  ngx.print(ui_helper.createTable(fwrule_v6_columns, fwrule_v6_data, fwrule_v6_options, nil, fwrule_v6_helpmsg)); ngx.print('\
\
</fieldset>\
</form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
<script>\
(function() {\
    //by disabling the add new rule button, we prevent that the user start adding a rule, before the adapted firewall level user is saved.\
    //as this is a special case, we implement this here and not in actions.js\
    $(document).on("change", \'.modal select:not(.no-save):not(.disabled)\', function() {\
        $(".btn-table-new").addClass("disabled");\
    });\
}());\
</script>\
'); 