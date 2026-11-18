<%
-- Enable localization

gettext.textdomain('webui-voice')

local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local uimessage_helper = require("web.uimessage_helper")
local role = ngx.ctx.session:getrole()
local validateNonEmptyString = post_helper.validateNonEmptyString
local attribute = { input = { class = "span2" } }


local mapParam = {
  posfxs1 = "Device.Services.VoiceService.1.PhyInterface.1.X_000E50_POSConfig",
  posfxs2 = "Device.Services.VoiceService.1.PhyInterface.2.X_000E50_POSConfig"
}

local mapValid = {
  posfxs1 = validateNonEmptyString,
  posfxs2 = validateNonEmptyString
}

local content = post_helper.handleQuery(mapParam, mapValid)

local getAllValues = proxy.get("Device.Services.VoiceService.1.PhyInterface.")
local pathPCMA = {}
for _, interfaceValue in ipairs(getAllValues) do
  if interfaceValue.value == "PCMA" then
    pathPCMA[#pathPCMA + 1] = interfaceValue.path
  end
end

if ngx.var.request_method == "POST" then
  local post_data = ngx.req.get_post_args()
  if post_data.action == "SAVE" and (content["posfxs1"] == 'true' or content["posfxs2"] == 'true') then
    for _, pathValue in ipairs(pathPCMA) do
      proxy.set(string.format("%sEnable", pathValue), "1")
    end
  end
end

local choice2 = {
  {"0", T"Disabled"},
  {"1", T"Enabled"}
}

local codec_columns = {
  { --[1]
    header = T"Name",
    name = "profile",
    param = "Codec",
    type = "text",
	readonly = true,
    attr = attribute
  },
  { --[2]
	header = T"State",
    name = "enable",
    param = "Enable",
    type = "select",
	values = choice2,
    attr = { select = { class = "span2" } }
  },
  { --[3]
    header = T"Priority",
    name = "priority",
    param = "Priority",
    type = "text",
    attr = attribute
  },
  { --[4]
    header = T"Packetization Period",
    name = "PacketizationPeriod",
    param = "PacketizationPeriod",
    type = "text",
    attr = attribute
  },
  { --[5]
    header = T"Bit Rate",
    name = "BitRate",
    param = "BitRate",
    type = "text",
    readonly = true,
    attr = attribute
  },
  { --[6]
    header = T"Silence Suppression",
    name = "supression",
    param = "SilenceSuppression",
    type = "select",
	values = choice2,
    attr = { select = { class = "span2" } }
  }
}

--maybe getValidateNumberInRange instead of validatePositiveNum.
local getValidateEnumSelect = post_helper.getValidateInEnumSelect(choice2)
local validatePositiveNumber = post_helper.validatePositiveNum
local codec_valid = {
  profile = validateNonEmptyString,
  enable = getValidateEnumSelect,
  priority = validatePositiveNumber,
  PacketizationPeriod = validatePositiveNumber,
  BitRate = validatePositiveNumber,
  supression = getValidateEnumSelect
}

local codec_options = {}
for codecOptionsValue = 1, 2, 1 do
  codec_options[#codec_options+1] = {
    canEdit = true,
    canAdd = false,
    canDelete = false,
    tableid = string.format("codecFXS%s", codecOptionsValue),
    basepath = string.format("Device.Services.VoiceService.1.PhyInterface.%s.X_000E50_Codec.List.", codecOptionsValue)
  }
  if content["posfxs1"] == "true" or content["posfxs2"] == "true" then
    codec_options[#codec_options].canEdit = false
  end
end

local codec_data_FXS1, codec_helpmsg_FXS1 = post_helper.handleTableQuery(codec_columns, codec_options[1], nil, nil, codec_valid)
local codec_data_FXS2, codec_helpmsg_FXS2 = post_helper.handleTableQuery(codec_columns, codec_options[2], nil, nil, codec_valid)

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
  uri = uri .. "?" .. ngx.var.args
end
%>
<%= ui_helper.createHeader( T"Telephony", false, true) %>

<div class = "modal-body update">
  <%
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-voice.lp")
  %>
  <form class = "form-horizontal" method = "post" action = "<%= uri %>">
    <%=ui_helper.createMessages(uimessage_helper.popMessages())%>
    <fieldset>
      <legend><%=  T"Enable Pos" %></legend>
      <%
        local Posswitch = {
	  values = {on = "true", off = "false"},
        }
        local html = {}
        html[#html+1] = ui_helper.createSwitch( T"Pos on FXS1", "posfxs1", content["posfxs1"], Posswitch)
        html[#html+1] = ui_helper.createSwitch(T"Pos on FXS2", "posfxs2", content["posfxs2"], Posswitch)
	ngx.print(html)
      %>
    </fieldset>
    <% if post_helper.isFeatureEnabled("telephonyCodecFXS", role) then %>
      <fieldset>
        <legend><%= T"Codec Assignment on FXS1" %></legend>
	<%= ui_helper.createTable(codec_columns, codec_data_FXS1, codec_options[1], nil, codec_helpmsg_FXS1) %>
      </fieldset>
      <fieldset>
        <legend><%= T"Codec Assignment on FXS2"%></legend>
	<%= ui_helper.createTable(codec_columns, codec_data_FXS2, codec_options[2], nil, codec_helpmsg_FXS2) %>
      </fieldset>
    <% end %>
  </form>
</div>

<%= ui_helper.createFooter() %>
