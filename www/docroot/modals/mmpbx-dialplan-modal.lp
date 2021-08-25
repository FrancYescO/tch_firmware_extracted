<%
-- Enable localization
gettext.textdomain("webui-voice")

local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local ipairs = ipairs
local match, find  = string.match, string.find
local attributes = { input = { class="span1" } }

-- Dialplan columns
local dialplan_columns = {
  { --[1]
    header = "",
    name = "enable",
    param = "enabled",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" } }
  },
  { --[2]
    header = T"Pattern",
    name = "pattern",
    param = "pattern",
    unique = true,
    type = "text",
    attr = attributes
  },
  { --[3]
    header = T"Min Length",
    name = "min_length",
    param = "min_length",
    type = "text",
    attr = attributes
  },
  { --[4]
    header = T"Max Length",
    name = "max_length",
    param = "max_length",
    type = "text",
    attr = attributes
  },
  { --[5]
    header = "EON",
    name = "include_eon",
    param = "include_eon",
    type = "switch",
    default = "0",
    attr = { switch = { ["data-placement"] = "right" } }
  }
}

local function globalValid(data)
  if data then
    for _, dataValue in ipairs(data) do
      if tonumber(dataValue[3]) > tonumber(dataValue[4]) then
        return nil, { min_length = T"Min length should not be larger than max length"}
      end
    end
  end
  return true
end

-- function to validate the pattern
-- return nil when the value does not match with the given pattern
local function validatePattern(value, object, key)
  local valid, msg = post_helper.validateNonEmptyString(value)
  if valid then
    if not match(value, "^(%^.+)") then
      return nil, T"The pattern MUST start with the caret character '^'"
    elseif find(value, "%$") then
      return nil, T"The pattern MUST NOT contain a '$' character"
    end
  end
  return valid, msg
end

local dialplan_options = {
  tableid = "dialplan_entry",
  basepath = "rpc.mmpbx.dial_plan_entry.@.",
  createMsg = T"Create new",
  valid = globalValid
}

local dialplan_valid = {
  pattern = validatePattern,
  min_length = post_helper.getValidateNumberInRange(1,40),
  max_length = post_helper.getValidateNumberInRange(1,40)
}

local dialplan_data, dialplan_helpmsg = post_helper.handleTableQuery(dialplan_columns, dialplan_options, nil, nil, dialplan_valid)

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
  uri = uri .. "?" .. ngx.var.args
end %>
<%= ui_helper.createHeader(T"Dial Plan Entries", false, true) %>
<div class="modal-body update">
  <%
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-voice.lp")
  %>
  <form class = "form-horizontal" method = "post" action = "<%= uri %>">
    <fieldset id = "mmpbx-profile-tab">
      <legend><%= T"Dial Plan Entries"  %></legend>
      <%
        local html = {}
        html[#html+1] = ui_helper.createTable(dialplan_columns, dialplan_data, dialplan_options, nil, dialplan_helpmsg)
        ngx.print(html)
      %>
    </fieldset>
  </form>
</div>

<div class = "modal-footer">
  <div id = "close-config" class = "btn btn-primary btn-large" data-dismiss = "modal"><%= T"Close" %></div>
</div>
