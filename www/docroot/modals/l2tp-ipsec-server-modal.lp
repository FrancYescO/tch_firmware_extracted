<%
-- Enable localization
gettext.textdomain('webui-l2tp-ipsec-server')

local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local proxy = require("datamodel")
local ipv42num = post_helper.ipv42num
local format = string.format
local aIV = post_helper.advancedIPValidation
local ngx = ngx
local mask

local user_columns = {
    {
        header = T"Username",
        name = "name",
        param = "name",
        type = "text",
        default = "vpn_user",
        attr = { input = { class="span2" } },
    },
    {
        header = T"Password",
        name = "password",
        param = "password",
        type = "text",
        default = proxy.get("rpc.l2tpipsecserver.generateChapSecret")[1].value,
        attr = { input = { class="span2" } },
    },
}

local user_options = {
    tableid = "usermgr",
    basepath = "uci.vpn.l2tp_user.",
    createMsg = T"Add new user",
    minEntries = 1, -- Keep at least one default user
    maxEntries = 15, -- This is the max number of PPP connections from l2tp-ipsec-server package
    sorted = "name",
}

-- Check if usernames are valid:
--    usernames may not be emtpy
--    usernames must be unique
local function nameValid(value)
    local v, m = post_helper.validateNonEmptyString(value)
    if v then
        local users = proxy.get(user_options.basepath)
        if users then
            for _, v in ipairs(users) do
                if v.param == "name" then
                    local name = format("%s", v.value)
                    local path = format("%s", v.path)
                    local path_index = path:match("%S+%.(%d)")
                    if name == value and path_index ~= user_options.changesessionindex then
                        return nil, T"A user with this username already exists"
                    end
                end
            end
        end
        return true
    else
        return v, m
    end
end

local user_valid = {
    name = nameValid,
    password = post_helper.validateNonEmptyString,
}

local user_data, user_helpmsg = post_helper.handleTableQuery(user_columns, user_options, nil, nil, user_valid)

local ifnames = proxy.getPN("rpc.network.interface.", true)
local interfacePaths = {}
local interfaceIPList = {}
local function getLanMask()
  if not mask then
    mask =  proxy.get("uci.network.interface.@lan.netmask")[1].value
  end
  return mask
end

if #interfaceIPList == 0 then
  if ifnames and #ifnames > 0 then
    for _, basepath in ipairs(ifnames) do
      interfacePaths[#interfacePaths+1] = basepath.path.."ipaddr"
    end
    interfaceIPList = proxy.get(unpack(interfacePaths))
  end
end

local function LanWanIPValidation(ip)
  for _, interfaceIP in ipairs(interfaceIPList) do
    if interfaceIP.value == ip then
      return nil, T"IP already in use"
    end
  end
  return true
end

-- Validates Local IP Address for VPN.
-- @param [value] a valid IPv4 address
-- Checks if IPAddress is not in the range of Remote IP Address
-- @return true or nil + error message
local function validateLocalIP(value, object)
  object["localdevmask"] = getLanMask()
  local valid1, errmsg1 = aIV(value, object)
  local valid2, errmsg2 = LanWanIPValidation(value)
  if not valid1 then
    return nil, errmsg1
  end
  if not valid2 then
    return nil , errmsg2
  end
  local local_ip = ipv42num(value)
  local remote_ip_start = ipv42num(object["remote_ip_start"])
  local remote_ip_end = ipv42num(object["remote_ip_end"])
  if remote_ip_start and remote_ip_end and remote_ip_start <= local_ip and local_ip <= remote_ip_end then
    return nil, T"Local IP cannot be in the range of Remote IP"
  end
  return true
end

-- Validates Remote IP Address Start for VPN.
-- @param [value] a valid IPv4 address
-- Checks if Remote IP Address Start is not greater than Remote IP Address End
-- @return true or nil + error message
local function validateRemoteIPStart(value, object)
  object["localdevmask"] = getLanMask()
  local valid1, errmsg1 = aIV(value, object)
  local valid2, errmsg2 = LanWanIPValidation(value)
  if not valid1 then
    return nil, errmsg1
  end
  if not valid2 then
    return nil, errmsg2
  end
  local remote_ip_start = ipv42num(value)
  local remote_ip_end = ipv42num(object["remote_ip_end"])
  if remote_ip_start and remote_ip_end and remote_ip_start >= remote_ip_end then
    return nil, T"Remote IP Start cannot be greater than Remote IP End"
  end
  return true
end

-- Validates Remote IP Address End for VPN.
-- @param [value] a valid IPv4 address
-- Checks if Remote IP Address End is not lesser than Remote IP Address Start
-- @return true or nil + error message
local function validateRemoteIPEnd(value, object)
  object["localdevmask"] = getLanMask()
  local valid1, errmsg1 = aIV(value, object)
  local valid2, errmsg2 = LanWanIPValidation(value)
  if not valid1 then
    return nil, errmsg1
  end
  if not valid2 then
    return nil, errmsg2
  end
  local remote_ip_start = ipv42num(object["remote_ip_start"])
  local remote_ip_end = ipv42num(value)
  if remote_ip_start and remote_ip_end and remote_ip_end <= remote_ip_start then
    return nil, T"Remote IP End cannot be less than Remote IP Start"
  end
  return true
end

local mapParams = {
  vpnserver_enable = "rpc.l2tpipsecserver.enable",
  ipsec_psk = "uci.ipsec.remote.@l2tp.pre_shared_key",
  local_ip = "uci.vpn.l2tpipsecserver.local_ip",
  remote_ip_start = "rpc.l2tpipsecserver.remote_ip_start",
  remote_ip_end = "rpc.l2tpipsecserver.remote_ip_end",
  proxyarp = "uci.vpn.l2tpipsecserver.proxyarp",
}

local mapValid = {
  vpnserver_enable = post_helper.validateBoolean,
  ipsec_psk = post_helper.validateNonEmptyString,
  local_ip = validateLocalIP,
  remote_ip_start = validateRemoteIPStart,
  remote_ip_end = validateRemoteIPEnd,
  proxyarp = post_helper.validateBoolean,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
%>

<% ngx.print(ui_helper.createHeader(T"VPN Server")) %>

<div class="modal-body update">
  <form class="form-horizontal" method="post" action="modals/l2tp-ipsec-server-modal.lp">
  <% ngx.print(ui_helper.createMessages(message_helper.popMessages())) %>

  <fieldset>
  <legend><%= T"General" %></legend>
    <%
      ngx.print(
        ui_helper.createSwitch(T"VPN Server state", "vpnserver_enable", content["vpnserver_enable"]),
        ui_helper.createInputText(T"IPSec pre-shared key", "ipsec_psk", content["ipsec_psk"], nil, helpmsg["ipsec_psk"]),
        ui_helper.createInputText(T"Local IP", "local_ip", content["local_ip"], nil, helpmsg["local_ip"]),
        ui_helper.createInputText(T"Remote IP Start", "remote_ip_start", content["remote_ip_start"], nil, helpmsg["remote_ip_start"]),
        ui_helper.createInputText(T"Remote IP End", "remote_ip_end", content["remote_ip_end"], nil, helpmsg["remote_ip_end"]),
        ui_helper.createSwitch(T"Proxy Arp", "proxyarp", content["proxyarp"])
      )
    %>
  </fieldset>

  <fieldset>
  <legend><%= T"Users" %></legend>
    <%
      ngx.print(
        ui_helper.createTable(user_columns, user_data, user_options, nil, user_helpmsg)
      )
    %>
  </fieldset>
  </form>
</div>

<% ngx.print(ui_helper.createFooter()) %>
