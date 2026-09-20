<%
-- Enable localization
gettext.textdomain('webui-voice')

local tinsert = table.insert

local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local format = string.format

local devices = {}
local dev_config = { "mmpbxbrcmfxsdev", "mmpbxbrcmdectdev"}

local function getDeviceFriendlyNames()
    local devpattern = "([^%._@]+_dev_%d+)"
    for _,v in pairs(dev_config) do
        local results = proxy.get("uci." .. v .. ".device.")
        if results then
            for _,vv in ipairs(results) do
                if vv.param == "user_friendly_name" then
                    local dev = vv.path:match(devpattern)
                    devices[#devices + 1] = {dev, vv.value}
                end
            end
        end
    end
end
getDeviceFriendlyNames()

local order = {
    d = 1,
    f = 2,
}

table.sort(devices, function(a,b)
    local order_a = order[a[1]:sub(1,1)]
    local order_b = order[b[1]:sub(1,1)]
    if order_a < order_b or (order_a == order_b and a[1] < b[1]) then
        return true
    else
        return false
    end
end)

--Devices list incoming/outgoing
local incoming_outgoing_map_columns = {
    {
        header = T"Phone Number",
        name = "PhoneNumber",
        param = "PhoneNumber",
        type = "label",
        readonly = true,
        attr = { input = { class="span2" } },
    },
}

for _, dev in ipairs(devices) do
  incoming_outgoing_map_columns[#incoming_outgoing_map_columns + 1] = {
    header = dev[2],
    name = dev[1],
    param = dev[1],
    type = "checkboxswitch",
  }
end

local profilepattern = "sip_profile_(%d+)"
local a_num
local b_num
local function sort_func(a, b)
    a_num = a.paramindex:match(profilepattern)
    b_num = b.paramindex:match(profilepattern)
    return tonumber(a_num) < tonumber(b_num)
end

--Getting the current available incoming maps
local incoming_map_basepath = "rpc.mmpbx.sip_incomingmap.@."
local incoming_map_data, incoming_map_allowed_indexes = content_helper.loadTableData(incoming_map_basepath, incoming_outgoing_map_columns, nil, sort_func)

--Getting the current available outgoing maps
local outgoing_map_basepath = "rpc.mmpbx.sip_outgoingmap.@."
local outgoing_map_data, outgoing_map_allowed_indexes = content_helper.loadTableData(outgoing_map_basepath, incoming_outgoing_map_columns, nil, sort_func)

--POST for incoming & outgoing maps
if ngx.req.get_method() == "POST" then
    local success = false
    local post_args = ngx.req.get_post_args()

    local gVCS = post_helper.getValidateCheckboxSwitch()
    local incoming_outgoing_map_valid = {}

    for i in ipairs(incoming_map_allowed_indexes) do
        for _,w in ipairs(incoming_outgoing_map_columns) do
	    if w.type == "checkboxswitch" then
	        incoming_outgoing_map_valid["inc_"..w.name.."."..i] = gVCS
	    end
	end
    end

    for i in ipairs(outgoing_map_allowed_indexes) do
        for _,w in ipairs(incoming_outgoing_map_columns) do
	    if w.type == "checkboxswitch" then
	        incoming_outgoing_map_valid["outg_"..w.name.."."..i] = gVCS
	    end
	end
    end
    success = content_helper.validateObject(post_args, incoming_outgoing_map_valid)

    if success then
        local rpcpath = "rpc.mmpbx.sip_incomingmap.@"
	local path = ""
	local content_set = {}
        for i,v in ipairs(incoming_map_allowed_indexes) do
	    path = rpcpath..v.paramindex
            for j,w in ipairs(incoming_outgoing_map_columns) do
		if w.type == "checkboxswitch" then
		    if post_args["inc_"..w.name.."."..i] and  post_args["inc_"..w.name.."."..i] ~= incoming_map_data[i][j] then
		        content_set[path.."."..w.param] = post_args["inc_"..w.name.."."..i]
		    end
		end
	    end
        end

	rpcpath = "rpc.mmpbx.sip_outgoingmap.@"

	for i,v in ipairs(outgoing_map_allowed_indexes) do
	    path = rpcpath..v.paramindex
            for j,w in ipairs(incoming_outgoing_map_columns) do
		if w.type == "checkboxswitch" then
		    if post_args["outg_"..w.name.."."..i] and  post_args["outg_"..w.name.."."..i] ~= outgoing_map_data[i][j] then
		        content_set[path.."."..w.param] = post_args["outg_"..w.name.."."..i]
		    end
		end
	    end
        end

	if proxy.set(content_set) then
            proxy.apply()
	    incoming_map_data, incoming_map_allowed_indexes = content_helper.loadTableData(incoming_map_basepath, incoming_outgoing_map_columns, nil, sort_func)		--Getting updated incoming maps
	    outgoing_map_data, outgoing_map_allowed_indexes = content_helper.loadTableData(outgoing_map_basepath, incoming_outgoing_map_columns, nil, sort_func)	--Getting updated outgoing maps
	end
    end
end

local attrSwitch = {
        switch = {
            class = "switch"
        },
}

--Creating Table Header for incoming maps
local incoming_map_table = { "<div class=\"control-group\"> <table class=\"table table-striped\">",
			    "<thead><tr>"
			  }
for _,v in ipairs(incoming_outgoing_map_columns) do
    incoming_map_table[#incoming_map_table + 1] = format("<th>%s</th>", v.header)
end
incoming_map_table[#incoming_map_table + 1] = "</tr></thead>"

--Creating the table rows
incoming_map_table[#incoming_map_table + 1] = "<tbody>"
for i,v in ipairs(incoming_map_data) do
    incoming_map_table[#incoming_map_table + 1] = "<tr>"
    for j,w in ipairs(v) do
        incoming_map_table[#incoming_map_table + 1] = "<td>"
	if incoming_outgoing_map_columns[j].type == "checkboxswitch" then
	    incoming_map_table[#incoming_map_table + 1] = ui_helper.createSimpleCheckboxSwitch("inc_"..incoming_outgoing_map_columns[j].name.."."..i, w, attrSwitch)
	else
	    incoming_map_table[#incoming_map_table + 1] = w
	end
	incoming_map_table[#incoming_map_table + 1] = "</td>"
    end
    incoming_map_table[#incoming_map_table + 1] = "</tr>"
end
incoming_map_table[#incoming_map_table + 1] = "</tr></thead>"
incoming_map_table[#incoming_map_table + 1] = "</tbody></table>"
incoming_map_table[#incoming_map_table + 1] = "</div>"

--Creating Table Header for outgoing maps
local outgoing_map_table = { "<div class=\"control-group\"> <table class=\"table table-striped\">",
			    "<thead><tr>"
			  }
for _,v in ipairs(incoming_outgoing_map_columns) do
    outgoing_map_table[#outgoing_map_table + 1] = format("<th>%s</th>", v.header)
end
outgoing_map_table[#outgoing_map_table + 1] = "</tr></thead>"

--Creating the table rows
outgoing_map_table[#outgoing_map_table + 1] = "<tbody>"
for i,v in ipairs(outgoing_map_data) do
    outgoing_map_table[#outgoing_map_table + 1] = "<tr>"
    for j,w in ipairs(v) do
        outgoing_map_table[#outgoing_map_table + 1] = "<td>"
	if incoming_outgoing_map_columns[j].type == "checkboxswitch" then
	    outgoing_map_table[#outgoing_map_table + 1] = ui_helper.createSimpleCheckboxSwitch("outg_"..incoming_outgoing_map_columns[j].name.."."..i, w, attrSwitch)
	else
	    outgoing_map_table[#outgoing_map_table + 1] = w
	end
	outgoing_map_table[#outgoing_map_table + 1] = "</td>"
    end
    outgoing_map_table[#outgoing_map_table + 1] = "</tr>"
end
outgoing_map_table[#outgoing_map_table + 1] = "</tr></thead>"
outgoing_map_table[#outgoing_map_table + 1] = "</tbody></table>"
outgoing_map_table[#outgoing_map_table + 1] = "</div>"

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

	<fieldset id ="mmpbx-incomingmap-tab">
      <legend><%= T"Incoming Maps" %></legend>
      <%
	ngx.print(incoming_map_table)
      %>

    </fieldset>

	<fieldset id ="mmpbx-outgoingmap-tab">
      <legend><%= T"Outgoing Maps" %></legend>
      <%
	ngx.print(outgoing_map_table)
      %>

    </fieldset>
  </form>
</div>

<%= ui_helper.createFooter() %>
<script>
$(document).ready(function() {
    $('input[type="checkbox"]').click(function(){
        var checkboxname = $(this).attr("name");
	var check = checkboxname.search("out")
	if(check != -1)
	{
	var numprofiles = <%=#outgoing_map_data %>;
	var devname = checkboxname.split(".")
	var tmpname = ""
	for(var i=1; i <= numprofiles; i++)
	{
	    tmpname = devname[0]+"."+i
	    $('input[type="checkbox"]').each(function(){
	        if($(this).attr("name") == tmpname)
		{
		    if(tmpname == checkboxname)
		    {
		       $(this).prop('checked', true);
		    }else
	            {
		       $(this).prop('checked', false);
		    }
		}
	    });
	}}
	$('#modal-no-change').fadeOut(300);
        $('#modal-changes').delay(350).fadeIn(300);
    });
    $(document).off("change");
});
</script>
