<%
-- Enable localization
-- NG-49075 Version 001 160429
-- NG-73564; 
-- TCOMITAGW-2219

gettext.textdomain('webui-voice')

local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require ("web.content_helper")
local role = ngx.ctx.session:getrole()
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString

local mapParam = {
					posfxs1 = "Device.Services.VoiceService.1.PhyInterface.1.X_000E50_POSConfig",
					posfxs2 = "Device.Services.VoiceService.1.PhyInterface.2.X_000E50_POSConfig",
					}

local mapValid = {
					posfxs1 = vNES,
					posfxs2 = vNES,
					}
					
local content, helpmsg = post_helper.handleQuery(mapParam, mapValid)

local getAllValues = proxy.get("Device.Services.VoiceService.1.PhyInterface.")
local pathPCMA = {}
for i,v in ipairs(getAllValues) do
	if v.value == "PCMA" then
		pathPCMA[#pathPCMA + 1] = v.path
	end
end

if ngx.var.request_method == "POST" then
	local post_data = ngx.req.get_post_args()
	if post_data.action == "SAVE" and (content["posfxs1"] == 'true' or content["posfxs2"] == 'true') then
		for i,v in ipairs(pathPCMA) do
			proxy.set(string.format("%sEnable",v),"1")
		end
		proxy.apply()
	end
end

local choice2 = {
					{"0",T"Disabled"},
					{"1",T"Enabled"},
				
				}

local codec_columns = {
    { --[1]
        header = T"Name",
        name = "profile",
        param = "Codec",
        type = "text",
		readonly = true,
        attr = { input = { class="span2" } },
    },
    { --[2]
		header = T"State",
        name = "enable",
        param = "Enable",
        type = "select",
		values = choice2,
        attr = { select = { class="span2" } },
    },
    { --[3]
        header = T"Priority",
        name = "priority",
        param = "Priority",
        type = "text",
        attr = { input = { class="span2" } },
    },
	{ --[4]
        header = T"Packetization Period",
        name = "PacketizationPeriod",
        param = "PacketizationPeriod",
        type = "text",
        attr = { input = { class="span2" } },
    },
	{ --[5]
        header = T"Bit Rate",
        name = "BitRate",
        param = "BitRate",
        type = "text",
		readonly = true,
        attr = { input = { class="span2" } },
    },
    { --[6]
        header = T"Silence Suppression",
        name = "supression",
        param = "SilenceSuppression",
        type = "select",
		values = choice2,
        attr = { select = { class="span2" } },
    },
}

--maybe getValidateNumberInRange instead of validatePositiveNum (vPN)
local gVIESc2 = post_helper.getValidateInEnumSelect(choice2)
local vPN = post_helper.validatePositiveNum
local codec_valid = {
						profile = vNES,
						enable = gVIESc2,
						priority = vPN,
						PacketizationPeriod = vPN,
						BitRate = vPN,
						supression = gVIESc2,
						}
						
local codec_options = {}
for i=1,2,1 do
codec_options[#codec_options+1]={
	canEdit = true,
    canAdd = false,
    canDelete = false,
    tableid = string.format("codecFXS%s",i),
    basepath = string.format("Device.Services.VoiceService.1.PhyInterface.%s.X_000E50_Codec.List.",i),
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
<%= ui_helper.createHeader(T"Telephony", false, true) %>

<div class="modal-body update">
  <%
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-voice.lp")
  %>
  <form class="form-horizontal" method="post" action="<%= uri %>">
    <fieldset>
      <legend><%= T"Enable Pos" %></legend>
		<%
			local Posswitch = {
									values = {on = "true", off = "false"},
									}
			local html = {}
			html[#html+1] = ui_helper.createSwitch(T"Pos on FXS1", "posfxs1", content["posfxs1"],Posswitch)
			html[#html+1] = ui_helper.createSwitch(T"Pos on FXS2", "posfxs2", content["posfxs2"],Posswitch)
			
			ngx.print(html)
		%>
    </fieldset>
  <% if role == "engineer" or role == "unlocked" then --[[ TCOMITAGW-2219]]%>
    <fieldset>
      <legend><%= T"Codec Assignment on FXS1" %></legend>
		<%= ui_helper.createTable(codec_columns, codec_data_FXS1, codec_options[1], nil, codec_helpmsg_FXS1) %>
    </fieldset>
	<fieldset>
      <legend><%= T"Codec Assignment on FXS2" %></legend>
	  	<%= ui_helper.createTable(codec_columns, codec_data_FXS2, codec_options[2], nil, codec_helpmsg_FXS2) %>
    </fieldset>
	<% end %>
  </form>
 </div>

<%= ui_helper.createFooter() %>