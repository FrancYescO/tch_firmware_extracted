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
    f = 1,
    d = 2,
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

--Devices list
local outgoingmap_columms = {
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
    outgoingmap_columms[#outgoingmap_columms + 1] = {
        header = dev[2],
        name = dev[1],
        param = dev[1],
        type = "checkboxswitch",
    }
end

local profilepattern = "sip_profile_(%d+)"
local function sort_func(a, b)
    local a_num = a.paramindex:match(profilepattern)
    local b_num = b.paramindex:match(profilepattern)
    return tonumber(a_num) < tonumber(b_num)
end

--Getting the currently available maps
local basepath = "rpc.mmpbx.sip_outgoingmap.@."
local outgoingmap_data, allowedIndexes = content_helper.loadTableData(basepath, outgoingmap_columms, nil, sort_func)

if ngx.req.get_method() == "POST" then
    local success = false
    local post_args = ngx.req.get_post_args()

    local gVCS = post_helper.getValidateCheckboxSwitch()
    local outgoingmap_valid = {}

    for i in ipairs(allowedIndexes) do
        for _,w in ipairs(outgoingmap_columms) do
	    if w.type == "checkboxswitch" then
	        outgoingmap_valid[w.name.."."..i] = gVCS
	    end
	end
    end

    success = content_helper.validateObject(post_args, outgoingmap_valid)
    if success then
        local rpcpath = "rpc.mmpbx.sip_outgoingmap.@"
	local path = ""
	local content_set = {}
        for i,v in ipairs(allowedIndexes) do
	    path = rpcpath..v.paramindex
            for _,w in ipairs(outgoingmap_columms) do
		if w.type == "checkboxswitch" then
		    if post_args[w.name.."."..i] then
		        content_set[path.."."..w.name] = post_args[w.name.."."..i]
		    end
		end
	    end
        end

	if proxy.set(content_set) then
            proxy.apply()

	    outgoingmap_data, allowedIndexes = content_helper.loadTableData(basepath, outgoingmap_columms, nil, sort_func)		--Getting updated maps
	end
    end
end

--Creating Table Header
local outgoingmap_table = { "<div class=\"control-group\"> <table class=\"table table-striped\">",
			    "<thead><tr>"
			  }
for _,v in ipairs(outgoingmap_columms) do
    outgoingmap_table[#outgoingmap_table + 1] = format("<th>%s</th>", v.header)
end
outgoingmap_table[#outgoingmap_table + 1] = "</tr></thead>"

--Creating the table rows
local attrSwitch = {
        switch = {
            type = "switch",
        },
}

outgoingmap_table[#outgoingmap_table + 1] = "<tbody>"
for i,v in ipairs(outgoingmap_data) do
    outgoingmap_table[#outgoingmap_table + 1] = "<tr>"
    for j,w in ipairs(v) do
        outgoingmap_table[#outgoingmap_table + 1] = "<td>"
	if outgoingmap_columms[j].type == "checkboxswitch" then
	    outgoingmap_table[#outgoingmap_table + 1] = ui_helper.createSimpleCheckboxSwitch(outgoingmap_columms[j].name.."."..i, w, attrSwitch)
	else
	    outgoingmap_table[#outgoingmap_table + 1] = w
	end
	outgoingmap_table[#outgoingmap_table + 1] = "</td>"
    end
    outgoingmap_table[#outgoingmap_table + 1] = "</tr>"
end
outgoingmap_table[#outgoingmap_table + 1] = "</tr></thead>"
outgoingmap_table[#outgoingmap_table + 1] = "</tbody></table>"
outgoingmap_table[#outgoingmap_table + 1] = "</div>"

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
    <fieldset id ="mmpbx-outgoingmap-tab">
      <legend><%= T"Outgoing Maps" %></legend>
      <%
	ngx.print(outgoingmap_table)
      %>

    </fieldset>
  </form>
</dev>

<%= ui_helper.createFooter() %>
<script>
$(document).ready(function() {
    $('input[type="checkbox"]').click(function(){
        var checkboxname = $(this).attr("name");
	var numprofiles = <%=#outgoingmap_data %>;
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
	}
	$('#modal-no-change').fadeOut(300);
        $('#modal-changes').delay(350).fadeIn(300);
    });
    $(document).off("change");
});
</script>
