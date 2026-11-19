--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local untaint_mt = require("web.taint").untaint_mt
local proxy = require("datamodel")
local inet = require("tch.inet")

local string = string
local match, format, gsub, lower, untaint = string.match, string.format, string.gsub, string.lower, string.untaint
local remove = table.remove
local vB = post_helper.validateBoolean
local gVIES = post_helper.getValidateInEnumSelect
local vSIP = post_helper.advancedIPValidation
local vIPM = post_helper.validateIPv4Netmask
local vNES = post_helper.validateNonEmptyString
local gVSIIN = post_helper.getValidateStringIsIPv4InNetwork

-- Get all the LAN interfaces
local net_intfs_path = "rpc.network.interface_lan."
local all_intfs = content_helper.convertResultToObject(net_intfs_path .. "@.", proxy.get(net_intfs_path))
local lan_intfs, all_lan_ips, all_lan_netmasks = {}, {}, {}
local options_bridge, all_alias = {}, {}
for _,v in ipairs(all_intfs) do
    if not match(v.paramindex, "^VLAN%d$") then
        lan_intfs[#lan_intfs + 1] = v.paramindex
    end
    all_lan_ips[v.paramindex] = untaint(v.ipaddr)
    all_lan_netmasks[v.paramindex] = untaint(v.netmask)
    if v.type == 'bridge' then
        options_bridge[#options_bridge +1] = { v.paramindex, v.alias }
        all_alias[v.paramindex] = v.alias
    end
end

local default_lan = 'lan'
table.sort(lan_intfs, function(a,b)
    if a == default_lan then
        return true
    elseif b == default_lan then
        return false
    elseif a < b then
        return true
    end
    return false
end)

all_alias = setmetatable(all_alias, untaint_mt)

local bscns = {
    ports = 2,
}

local bridge_columns = {
  { --[1]
    header = "Name",
    name = "alias",
    param = "alias",
    type = "text",
    readonly = true,
    attr = { input = { class="span2", maxlength="15"} },
  },
  { -- [2]
    header = T"Ports",
    name = "ports",
    param = "ports",
    type = "label",
    readonly = true,
  },
  { --[3]
    header = T"IP Address",
    name = "ipaddr",
    param = "ipaddr",
    type = "text",
    readonly = true,
    attr = { input = { class="span2", maxlength="15"} },
  },
  { --[4]
    header = T"Subnet Mask",
    name = "netmask",
    param = "netmask",
    type = "text",
    readonly = true,
    attr = { input = { class="span2", maxlength="15"} },
  },
  { --[5]
    header = "",
    legend = T"VLAN Settings",
    name = "vlan",
    type = "aggregate",
    synthesis = nil,
    subcolumns = {
      {
        header = "Name",
        name = "alias",
        param = "alias",
        type = "text",
        attr = { input = { class="span2", maxlength="15"} },
      },
      {
        header = T"IP Address",
        name = "ipaddr",
        param = "ipaddr",
        type = "text",
        attr = { input = { class="span2", maxlength="15"} },
      },
      {
        header = T"Subnet Mask",
        name = "netmask",
        param = "netmask",
        type = "text",
        attr = { input = { class="span2", maxlength="15"} },
      },
      {
        header = T"NAT",
        name = "nat_enable",
        param = "nat_enable",
        type = "switch",
        default = "0",
        attr = { switch = { ["data-placement"] = "right" } },
      },
      {
        header = T"IGMP Snooping",
        name = "igmp_snooping",
        param = "igmp_snooping",
        type = "switch",
        default = "1",
        attr = { switch = { ["data-placement"] = "right" } },
      },
    },
  },
}

local bridge_options = {
    tableid = "bridges",
    basepath = "rpc.network.interface_lan.@.",
    createMsg = T"Add new VLAN",
    sorted = function(a, b)
       if lower(a.paramindex) < lower(b.paramindex) then
            return true
       else
            return false
       end
    end,
    maxEntries = 4,
}

local function validatedevIP(value, object, key)
    local valid, msg = vSIP(value, object, key)
    if valid then
        local paramindex = bridge_options.changesessionindex
        local netmask = untaint(object.netmask)
        local result, nm1 = inet.validateIPv4Netmask(netmask)
        if result then
            for k,v in pairs(all_lan_ips) do
                if paramindex ~= k then
                    local _, nm2 = inet.validateIPv4Netmask(all_lan_netmasks[k])
                    local ip, gw, nm
                    if nm1 > nm2 then
                        ip, gw, nm = v, untaint(value), netmask
                    else
                        ip, gw, nm = value, v, all_lan_netmasks[k]
                    end
                    local validate = gVSIIN(gw, nm)
                    result = validate(ip)
                    if result then
                        return nil, 'IP address ' .. value .. '/' .. (32-nm1) .. ' should not be overlapped with LAN IP interface ' .. k ..'(' .. v .. '/' .. (32-nm2) ..')'
                    end
                end
            end
        end
    end
    return valid, msg
end

local function validateAlias(value, object, key)
    local valid, msg = vNES(value, object, key)
    if valid then
        local paramindex = bridge_options.changesessionindex
        for k,v in pairs(all_alias) do
            if value == v and paramindex ~= k then
                return nil, 'Name ' .. value .. ' has already been used by another LAN IP interface'
            end
        end
    end
    return valid, msg
end

local bridge_valid = {
    nat_enable = vB,
    igmp_snooping = vB,
    ipaddr = validatedevIP,
    netmask = vIPM,
    alias = validateAlias,
}

local bridge_filter = function(data)
    if data.type == 'bridge' then
        return true
    else
        return false
    end
end

local bridge_data, bridge_helpmsg = post_helper.handleTableQuery(bridge_columns, bridge_options, bridge_filter, nil, bridge_valid)

local pscns = {
    port = 1
}

local port_columns = {
  {
    header = "Port",
    name = "port",
    param = "paramindex",
    type = "label",
    readonly = true,
  },
  {
    header = T"VLAN",
    name = "bridge",
    param = "bridge",
    type = "select",
    values = options_bridge,
  },
}

local port_options = {
    tableid = "ports",
    basepath = "rpc.network.bridge_port.@.",
    canAdd = false,
    canDelete = false,
    sorted = "paramindex",
}

local port_valid = {
    bridge = gVIES(options_bridge),
}

local port_data, port_helpmsg = post_helper.handleTableQuery(port_columns, port_options, nil, nil, port_valid)

local forwarding_columns = {
  {
    header = "Source",
    name = "src",
    param = "src",
    type = "select",
    values = options_bridge,
  },
  {
    header = T"Destination",
    name = "dest",
    param = "dest",
    type = "select",
    values = options_bridge,
  },
}

local forwarding_path = "uci.firewall.forwarding."
local forwarding_options = {
    tableid = "forwarding",
    basepath    = forwarding_path .. "@.",
    sorted = "src",
    maxEntries = (#bridge_data)*(#bridge_data - 1),
    createMsg = T"Add new rule",
    objectName  = "forwarding" .. post_helper.getRandomKey(),
    addNamedObject = true,
}

local function validate_src_dest(value, object, key)
    if object.src == object.dest then
        return nil, "Source and Destination can not have the same value"
    else
        local paramindex = forwarding_options.changesessionindex
        local src_dest_pattern = "%s|%s"
        local bridge_forwarding = {}
        local all_forwarding = content_helper.convertResultToObject(forwarding_path .. "@.", proxy.get(forwarding_path))
        for _,v in ipairs(all_forwarding) do
            if paramindex ~= v.paramindex and all_alias[v.src] and all_alias[v.dest] then
                 bridge_forwarding[format(src_dest_pattern, v.src, v.dest)] = true
            end
        end

        if bridge_forwarding[format(src_dest_pattern, object.src, object.dest)] then
            return nil, "Same forwarding rule already exists"
        else
            local validate = gVIES(options_bridge)
            return validate(value, object, key)
        end
    end
end

local forwarding_valid = {
    src = validate_src_dest,
    dest = validate_src_dest,
}

local function forwarding_filter(data)
    if all_alias[data.src] and all_alias[data.dest] then
        return true
    end
    return false
end

local forwarding_data, forwarding_helpmsg = post_helper.handleTableQuery(forwarding_columns, forwarding_options, forwarding_filter, nil, forwarding_valid)

if ngx.var.request_method == "POST" then
    local post_args = ngx.req.get_post_args()
    local action, tableid = post_args.action, post_args.tableid
    if (action == "TABLE-MODIFY" and tableid == "ports" and not port_helpmsg)
      or (action == "TABLE-DELETE" and tableid == "bridges" and not bridge_helpmsg) then
        -- wait for network to reload and then update bridge port info
        ngx.sleep(10)
        bridge_data = content_helper.loadTableData(bridge_options.basepath, bridge_columns, bridge_filter, bridge_options.sorted)
        port_data = content_helper.loadTableData(port_options.basepath, port_columns, nil, port_options.sorted)
    end
end

local port_map = {
    eth0 = "Port-1",
    eth1 = "Port-2",
    eth2 = "Port-3",
    eth3 = "Port-4",
    eth4 = "Port-5",
}

local wl_pattern = "uci%.wireless%.wifi%-iface%.@([^%.]*)%."
local results = proxy.get("uci.wireless.wifi-iface.")
if results then
    for _,v in ipairs(results) do
        if v.param == "ssid" then
            local wl = v.path:match(wl_pattern)
            port_map[wl] = format("SSID-%s",v.value)
        end
    end
end

for k,v in ipairs(bridge_data) do
    v[bscns["ports"]] = gsub(v[bscns["ports"]], "([^%,]*)", port_map)
    v[bscns["ports"]] = gsub(v[bscns["ports"]], "(%,)", ", ")
end

for _,v in ipairs(port_data) do
    v[pscns["port"]] = port_map[v[pscns["port"]]]
end
  ngx.print('\
\
<div class="loading-wrapper hide"><img src="/img/spinner.gif" /></div>\
');  ngx.print(ui_helper.createHeader(T"VLAN") ); ngx.print('\
\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/bridge-modal.lp">\
');  
  -- Do not display the navlist on the list if only 1 lan interface
  if #lan_intfs> 1 then
  ngx.print('\
  <div class="span2">\
    <ul class="nav nav-list">\
     ');  
      html = {}
      html[#html+1] = format('<li class="nav-header">%s</li>', T"LAN Interfaces")
      for k,v in ipairs(lan_intfs) do
        local url = "modals/ethernet-modal.lp?intf=" .. v
        html[#html+1] = format('<li><a href="#" data-remote="%s">%s</a></li>', url, v)
      end
      html[#html+1] = format('<li class="nav-header">%s</li>', T"VLAN Interfaces")
      html[#html+1] = format('<li class="active"><a href="#" data-remote="modals/bridge-modal.lp">%s</a></li>', T"VLAN")
      ngx.print(html)
        ngx.print('\
      </ul>\
   </div>\
<div class="span8">\
');  end   ngx.print('\
\
');  ngx.print(ui_helper.createMessages(message_helper.popMessages()) ); ngx.print('\
<fieldset>\
<legend>');  ngx.print( T"VLAN Table" ); ngx.print('</legend>\
');  ngx.print(ui_helper.createTable(bridge_columns, bridge_data, bridge_options, nil, bridge_helpmsg)); ngx.print('\
</fieldset>\
<fieldset>\
<legend>');  ngx.print( T"Port Table" ); ngx.print('</legend>\
');  ngx.print(ui_helper.createTable(port_columns, port_data, port_options, nil, port_helpmsg)); ngx.print('\
</fieldset>\
');  if #bridge_data > 1 then   ngx.print('\
<fieldset>\
<legend>');  ngx.print( T"Forwarding Table" ); ngx.print('</legend>\
');  ngx.print(ui_helper.createTable(forwarding_columns, forwarding_data, forwarding_options, nil, forwarding_helpmsg)); ngx.print('\
</fieldset>\
');  end
  -- Do not display the navlist on the list if only 1 lan interface
  if #lan_intfs > 1 then
  ngx.print('\
</div>\
');  
   end
  ngx.print('\
\
</form>\
</div>\
\
');  ngx.print(ui_helper.createFooter() ); ngx.print('\
\
<script type="text/javascript">\
var default_lanValue ="');  ngx.print( default_lan ); ngx.print('";\
var port_mapValue ="');  ngx.print( port_map.eth0 ); ngx.print('";\
</script>\
<script src="/js/bridge.js"></script>\
'); 