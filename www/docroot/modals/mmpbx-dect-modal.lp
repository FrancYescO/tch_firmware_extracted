<%
-- Enable localization
gettext.textdomain('webui-voice')

local tinsert = table.insert
local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local format = string.format


-- function to validate Access code
-- Return true when access code has 4 digits and nil, errmsg when invalid code given
local function validateAccessCode(value)
  local errmsg = T"Access code must composed of 4 digits"
  if value == nil or #value == 0 then
    -- empty Access code just means that we don't want to set one
    return nil, errmsg
  end
  local acc_code = value:match("^(%d%d%d%d)$")
  if acc_code then
    return true
  end
  return nil, errmsg
end


-- function to validate the pair time
-- Return true when pair time is in digits and nil, errmsg when invalid pair time given
local function validatePairTime(value)
  local ermsg = T"Pairing window value is invalid"
  if value == nil or #value == 0 then
    return nil, ermsg
  end
  local pairing_window = value:match("^(%d+)$")
  if pairing_window then
    return true
  end
  return nil, ermsg
end

local mapValid = {
  pairTime = validatePairTime,
  accCode = validateAccessCode,
  baseName = post_helper.validateNonEmptyString,
  mmpbx_enabled = post_helper.validateBoolean
}

local mapParams = {
  mmpbx_enabled = "uci.mmpbx.mmpbx.@global.enabled",
  pairTime = "uci.mmpbxdectdev.dect_base.pairing_window",
  accCode = "uci.mmpbxdectdev.dect_base.access_code",
  baseName = "uci.mmpbxdectdev.dect_base.user_friendly_name"
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

content["handset_id"] = "all"

-- Dect Devices
local dectdev_columms = {
  {
    header = T"Name",
    name = "name",
    param = "FriendlyName",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } }
  },
  {
    header = T"Handset ID",
    name = "ipui",
    param = "IPUI",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } }
  },
  {
    header = T"State",
    name = "locationStatus",
    param = "LocationStatus",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } }
  }
}

local dectdev_options = {
  tableid = "dectDev",
  basepath = "sys.dect.dev.",
  canAdd = false,
  canEdit = false,
  canDelete = false,
  sorted = "FriendlyName"
}

local dectdev_data, dectdev_helpmsg = post_helper.handleTableQuery(dectdev_columms, dectdev_options, nil, nil, nil)

local function findHandsetID(handset_name)
  local devName
  for _, v in ipairs(proxy.getPN("uci.mmpbxdectdev.device.", true)) do -- get the path
    devName = format("%s", proxy.get(v["path"].."user_friendly_name")[1].value)
    if handset_name == devName then
      local num = string.find(v["path"], "@")
      local Dev = string.sub(v["path"], num+1, num+10)
      return Dev
    end
  end
end

-- Build the device selection list
local dect_located_list = {}

tinsert(dect_located_list, {"all", T"ALL"})
for k, v in ipairs(dectdev_data) do
  local disp_val = format("%s", v[1])
  local ipui = format("%s", v[2])
  if ipui ~= "0000000000" then
    tinsert(dect_located_list, {disp_val, disp_val})
  end
end

-- triggered only on a POST with action set pairing
if ngx.req.get_method() == "POST" then
  local args = ngx.req.get_post_args()
  local action = args["action"]
  if action == "paging_handset" then
    --ngx.log (ngx.ERR, "Check Paging Handset - ", "action")
    proxy.set("rpc.mmpbx.dect.paging", "toggle")
  end
  if action == "pairing_handset" then
    ngx.header.content_type = "application/json"
    proxy.set("rpc.mmpbx.dect.registration", "open")
    ngx.print('{ "success":"true" }')
    ngx.exit(ngx.HTTP_OK)
  elseif action == "cancel_pairing" then
    ngx.header.content_type = "application/json"
    proxy.set("rpc.mmpbx.dect.registration", "close")
    ngx.print('{ "success":"true" }')
    ngx.exit(ngx.HTTP_OK)
  end
  -- Deregister one or all DECT handset
  if action == "unreg_handset" then
    local handset_id = args["handset_id"]
    local handset_name = "all"
    if handset_id ~= "all" then
      content["handset_id"]=format("%s", handset_id)
      handset_name = findHandsetID(handset_id)
    end
    --ngx.log (ngx.ERR, "Unregister Handset - ", handset_name)
    proxy.set("rpc.mmpbx.dect.registration.clear", handset_name)
    ngx.header.content_type = "application/json"
    ngx.print('{ "success":"true" }')
    ngx.exit(ngx.HTTP_OK)
  end
elseif ngx.req.get_method() == "GET" then
  local args = ngx.req.get_uri_args()
  local action = args["action"]
  if action == "pairing_state" then
    local dect_content = {
      open = "rpc.mmpbx.dect.registration.open"
    }
    content_helper.getExactContent(dect_content)
    ngx.header.content_type = "application/json"
    if dect_content.open == "1" then
      ngx.print('{ "success":"true" }')
    else
      ngx.print('{ "success":"false" }')
    end
    ngx.exit(ngx.HTTP_OK)
  end
end

-- Retrieving paging state
local rpc_content = {
  paging_state = "rpc.mmpbx.dect.paging.alerting"
}
content_helper.getExactContent(rpc_content)

local autorefresh = nil
local paging_state = format("%s", rpc_content.paging_state)

if paging_state == "1" then
  autorefresh = 2
end

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
  uri = uri .. "?" .. ngx.var.args
end
%>

<%= ui_helper.createHeader(T"Telephony", false, true, autorefresh) %>
<div class="modal-body update">
  <%
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-voice.lp")
  %>
  <form class="form-horizontal" method="post" action="<%= uri %>">
    <%=ui_helper.createMessages(message_helper.popMessages())%>
    <fieldset id ="mmpbx-dect-tab">
      <legend><%= T"Pairing" %></legend>
      <%
        local html = {}
        local base_name_class = {
          input = {
            pattern= "^([a-zA-Z]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$",
            maxlength= "16",
            class= "span4"
          }
        }
        tinsert (html, ui_helper.createInputText(T"Base Name", "baseName", content["baseName"], base_name_class, helpmsg["baseName"]))

        local access_code_class = {
          input = {
            pattern= "^([0-9]{4})$",
            maxlength= "4",
            class= "span4",
          }
        }
        tinsert (html, ui_helper.createInputText(T"Access Code", "accCode", content["accCode"], access_code_class, helpmsg["accCode"]))

        local pairing_window_class = {
	  input = {
            pattern= "^([0-9]{1,4})$",
	    maxlength= "4",
	    class= "span4"
	  }
	}
	tinsert (html, ui_helper.createInputText(T"Pairing Window Time in Sec", "pairTime", content["pairTime"], pairing_window_class, helpmsg["pairTime"]))

        local pairing_class = {
          group = {
            class = "pairing-class"
          },
          button = {
            id = "btn-pairing",
            class = "custom-handler"
          }
        }
        tinsert (html, ui_helper.createButton (T"Pairing Handset",T"Start", "icon-refresh", pairing_class))

        local pairing = {
          alert = {
            class = "alert hide",
            id = "pairing_msg"
          }
        }
        tinsert (html, ui_helper.createAlertBlock(T"Pairing in progress, please wait...", pairing))

        ngx.print (html)
      %>
    </fieldset>
    <fieldset>
      <legend><%=  T"Paging" %></legend>
      <%
        local html = {}
        local page_class = {
          button = {
            ["data-name"] = "action",
            ["data-value"] = "paging_handset"
          }
        }
        if paging_state == "0" then
          tinsert (html, ui_helper.createButton (T"Paging Handset", T"Start", "icon-bolt", page_class))
        else
          tinsert (html, ui_helper.createButton (T"Paging Handset", T"Stop", "icon-ban-circle icon-large red", page_class))
        end
        ngx.print (html)
      %>
    </fieldset>
    <fieldset>
      <legend><%= T"Device List"  %></legend>
      <%
        ngx.print(ui_helper.createTable(dectdev_columms, dectdev_data, dectdev_options, nil, dectdev_helpmsg))
        local handset_class = {
          group = {
            class = ""
          },
          select = {
            class = "no-save",
            id = "handset_id"
          },
          button = {
            id = "btn-unreg",
            class = "custom-handler"
          }
        }
        ngx.print(ui_helper.createInputSelectWithButton(T"Handset Name", "handset_id", dect_located_list, content["handset_id"], T"Unregister", "icon-trash large red", handset_class))
      %>
    </fieldset>
  </form>
</div>

<div id="spinner" class="spinner hide">
<img id="img-spinner" src="../img/spinner.gif" alt="Pairing" style="margin-left: 10px; margin-right: 10px; margin-top: 10px; margin-bottom: 10px; width:128px; height:128px"/>
</div>

<script>
  var cancelMsg = "<%= T"Pairing in progress, Please press Cancel button for stop pairing." %>";
</script>
<script src="/js/mmpbx-dect-modal.js"></script>
<%= ui_helper.createFooter() %>
<%if content and content["mmpbx_enabled"] == "0" then %>
  <style>
    .disabled {
      cursor:not-allowed !important;
      color:#666;
    }
  </style>
  <script>
    $(".nav li a").addClass("disabled");
    $('.modal-body').css('overflow', 'hidden');
    $(".modal form").append('<div class="popUpBG" style="top:53px;"></div>');
  </script>
<%else%>
  <script>
    if($(".nav li a").hasClass("disabled")){
      $(".nav li a").removeClass("disabled");
    }
  </script>
<%end%>
