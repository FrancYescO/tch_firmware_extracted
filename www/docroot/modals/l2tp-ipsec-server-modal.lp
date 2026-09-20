<%
-- Enable localization
gettext.textdomain('webui-l2tp-ipsec-server')

local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local proxy = require("datamodel")

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
        name = "secret",
        param = "secret",
        type = "text",
        default = proxy.get("rpc.l2tpipsecserver.generateChapSecret")[1].value,
        attr = { input = { class="span2" } },
    },
}

local user_options = {
    tableid = "usermgr",
    basepath = "uci.l2tpipsecserver.l2tp_user.",
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
                    local name = string.format("%s", v.value)
                    if name == value then
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
    secret = post_helper.validateNonEmptyString,
}

local user_data, user_helpmsg = post_helper.handleTableQuery(user_columns, user_options, nil, nil, user_valid)

local mapParams = {
  vpnserver_enabled = "uci.l2tpipsecserver.global.enabled",
  ipsec_psk = "uci.l2tpipsecserver.ipsec_global.PSK",
}
local mapValid = {
  ipsec_psk = post_helper.validateNonEmptyString,
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
        ui_helper.createSwitch(T"VPN Server state", "vpnserver_enabled", content["vpnserver_enabled"]),
        ui_helper.createInputText(T"IPSec pre-shared key", "ipsec_psk", content["ipsec_psk"], nil, helpmsg["ipsec_psk"])
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
