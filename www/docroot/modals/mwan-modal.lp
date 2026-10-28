<%
-- Localization
gettext.textdomain('webui-core')

-- Process POST query
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local match, format  = string.match, string.format
local find, untaint = string.find, string.untaint
local gOV = post_helper.getOptionalValidation
local vSII = post_helper.validateStringIsIP
local vSIPR = post_helper.validateStringIsPortRange
local vNES = post_helper.validateNonEmptyString
--local tprint = require("tch.tableprint")

local network_rpc_path = "rpc.network.interface."
local network_rpc_content = content_helper.getMatchedContent (network_rpc_path)
local mwan_uci_policy_path = "uci.mwan.policy."
local mwan_uci_policy_content = content_helper.getMatchedContent (mwan_uci_policy_path)
local network_uci_path = "uci.network.interface."
local network_uci_content = content_helper.getMatchedContent (network_uci_path)

local select_wan_intfs = {}
local select_src_intfs = {
  { "", "" },
}
local select_tables = {}
local select_policy = {}
local select_path = {
  { "/usr/bin/mmpbxd",    "/usr/bin/mmpbxd" },
  { "/usr/bin/cwmpd",     "/usr/bin/cwmpd" },
  { "/usr/sbin/odhcpc",   "/usr/sbin/odhcpc" },
  { "/usr/sbin/dropbear", "/usr/sbin/dropbear" },
}
local policy_intfs = {}

-----------------------------------------------------------
-- select_tables {} 
-- get valid route table from /etc/iproute2/rt_tables
-- Route table id > 0 && id < 100
-----------------------------------------------------------
local f = io.popen ("sed 's/\t/ /g' /etc/iproute2/rt_tables | grep -v \"#\"")
for line in f:lines() do
  local num = 0
  for k in string.gmatch(line, "[^%s]+") do
    if num == 0 and tonumber(k) >= 100 or tonumber(k) == 0 then
      break
    elseif num == 1 then
      select_tables[#select_tables+1] = { k, T(k) }
      for _, v in pairs (network_uci_content) do
         if v["ip4table"] == k then
           select_tables[#select_tables] = nil
           break
         end
      end
    end
    num = num + 1
  end
end
f:close()

function split(x,sep)
  x = tostring(x)
  local sep, fields = sep or ":", {}
  local pattern = string.format("([^%s]+)", sep)
  x:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

-----------------------------------------------------------
-- select_policy {}
-- valid policy
--
-- select_wan_intfs {} 
-- available & wan & not used interfaces
--
-- select_src_intfs {}
-- not loopback interfaces
-----------------------------------------------------------
for _, v in pairs (mwan_uci_policy_content) do
  if v["interface"] ~= "" then
    local path = split(split(format("%s",v["path"]),"@")[2],".")
    policy_intfs[untaint(v["interface"])] = v["interface"]
    select_policy[#select_policy+1] = { path[1], path[1] }
  end
end

for _, v in pairs (network_rpc_content) do
  local path = split(split(format("%s",v["path"]),"@")[2],".")
  if v["available"] == "1" then
    if v["type"] == "wan" and policy_intfs[path[1]] == nil then
      select_wan_intfs[#select_wan_intfs+1] = { path[1], path[1] }
    end
--    if v["type"] == "lan" or v["type"] == "" and path[1] ~= "loopback" then
    if path[1] ~= "loopback" then
      select_src_intfs[#select_src_intfs+1] = { path[1], path[1] }
    end
  end
end

local policy_columns = {
  {
    header = T"Policy Name",
    name = "paramindex",
    param = "paramindex",
    type = "text",
    attr = { input = { class="span2", maxlength="63" } },
    unique = true,
  },
  {
    header = T"Interface",
    name = "interface",
    param = "interface",
    type = "select",
    values = select_wan_intfs,
    attr = { select = { class="span2" } },
  },
  {
    header = T"Routing table",
    name = "rttable",
    param = "rttable",
    type = "select",
    values = select_tables,
    attr = { select = { class="span2" } },
  },
}

-----------------------------------------------------------
-- add policy will also set ip4table in network
-----------------------------------------------------------
local function policyOnAdd(success, content)
  if success then
    local pathvalues = {}
    pathvalues[format("%s@%s.interface", mwan_uci_policy_path, untaint(content["paramindex"]))] = untaint(content["interface"])
    pathvalues[format("uci.network.interface.@%s.ip4table", content["interface"])] = untaint(content["rttable"])
    success = proxy.set(pathvalues)
  end
end

-----------------------------------------------------------
-- del policy will also unset ip4table in network
-----------------------------------------------------------
local function policyOnDel(index)
  for _, v in pairs (mwan_uci_policy_content) do
    local path = split(split(format("%s",v["path"]),"@")[2],".")
    if path[1] == index then
      local pathvalues = {}
      pathvalues[format("uci.network.interface.@%s.ip4table", v["interface"])] = ""
      proxy.set(pathvalues)
    end
  end
end

local policy_options = {
    canEdit = false,
    addNamedObject = true,
    tableid = "mwan_policy",
    basepath = "uci.mwan.policy.@.",
    createMsg = T"Add new policy",
    onAdd = policyOnAdd,
    onDelete = policyOnDel,
}

local policy_valid = {
    paramindex = vNES,
}

local policy_data, policy_helpmsg = post_helper.handleTableQuery(policy_columns, policy_options, nil, nil, policy_valid)

-----------------------------------------------------------
-- to show routing table name
-----------------------------------------------------------
for k, v in pairs (policy_data) do
  if v[2] ~= "" then
  local result = proxy.get("uci.network.interface.@" .. v[2] .. ".ip4table")[1].value
  v[3] = result
  end
end

local host_columns = {
  {
    header = T"Policy Name",
    name = "policy",
    param = "policy",
    type = "select",
    values = select_policy,
    attr = { select = { class="span2" } },
  },
  {
    header = T"Host Application",
    name = "path",
    param = "path",
    type = "select",
    values = select_path,
    attr = { select = { class="span2" } },
  },
}

local host_options = {
    tableid = "mwan_host",
    basepath = "uci.mwan.host.",
    createMsg = T"Add new host rule",
}

local host_data, host_helpmsg = post_helper.handleTableQuery(host_columns, host_options, nil, nil, nil)

local rules_protocols = {
    { "tcp",     T"TCP"},
    { "udp",     T"UDP"},
    { "",        T"TCP/UDP"},
    { "udplite", T"UDPLite"},
    { "icmp",    T"ICMP"},
    { "esp",     T"ESP"},
    { "ah",      T"AH"},
    { "sctp",    T"SCTP"},
}

local rule_columns = {
  {
    header = T"Policy Name",
    name = "policy",
    param = "policy",
    type = "select",
    values = select_policy,
    attr = { select = { class="span2" } },
  },
  {
    header = T"Src Interface",
    name = "src",
    param = "src",
    type = "select",
    values = select_src_intfs,
    default = "",
    attr = { select = { class="span2" } },
  },
  {
    header = T"Src IP",
    name = "src_ip",
    param = "src_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15"} },
  },
  {
    header = T"Src port",
    name = "src_port",
    param = "src_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" } },
  },
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto",
    default = "",
    type = "select",
    values = rules_protocols,
    attr = { select = { class="span1" } },
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
    attr = { input = { class="span1", maxlength="5" } },
  },
}

local rule_options = {
  tableid = "mwan_rule",
  basepath = "uci.mwan.rule.",
  createMsg = T"Add new rule",
}

local fwrule_valid = {
  src_ip = gOV(vSII),
  src_port = gOV(vSIPR),
  dest_ip = gOV(vSII),
  dest_port = gOV(vSIPR),
}

local rule_data, rule_helpmsg = post_helper.handleTableQuery(rule_columns, rule_options, nil, nil, fwrule_valid)

%>

<% ngx.print(ui_helper.createHeader(T"Policy Routing", false, false)) %>
<div class="modal-body update">
<%
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-internet.lp")
%>
<form class="form-horizontal" method="post" action="modals/mwan-modal.lp">
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<fieldset>
<legend><%= T"Policy Routing" %></legend>
<%
  ngx.print(ui_helper.createTable(policy_columns, policy_data, policy_options, nil, policy_helpmsg))
%>
</fieldset>
<fieldset>
<legend><%= T"Host Rules" %></legend>
<%
  ngx.print(format(T'<strong>You must reboot modem to apply host rules!</strong>'))
  ngx.print(ui_helper.createTable(host_columns, host_data, host_options, nil, host_helpmsg))
%>
</fieldset>
<fieldset>
<legend><%= T"Routing Rules" %></legend>
<%
  ngx.print(ui_helper.createTable(rule_columns, rule_data, rule_options, nil, rule_helpmsg))
%>
</fieldset>
</form>
</div>
<% ngx.print(ui_helper.createFooter()) %>


