<%
-- Enable localization
gettext.textdomain('webui-mobiledongle')

local tinsert = table.insert
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local attributes = { span = { class = "span4" } }
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local format = string.format
local setmetatable = setmetatable
local untaint_mt = require("web.taint").untaint_mt
local current_operator_map = setmetatable(require("operatorcode_helper"), untaint_mt)

ajax_helper.handleAjaxQuery({
  link_status = "uci.mobiledongle.info.link_status",
  emi_detected = "uci.usb.ehci_emi_detectNumberOfEntries"
}, function(content)
  if content["emi_detected"] then
    content["emi_detected"] = (content["emi_detected"] == "0") and "0" or "1"
  end
end)

-- "Pre-define the translation string per operator mode. If you want a new operator mode in the  GUI list, "
-- "add the item here as well as in the uci.mobiledongle.config.tech_mode_white_list list"
local all_tech_modes = {
  ["auto"] = T'Automatic',
  ["3G"]   = T'3G',
  ["4G"]   = T'4G'
}

-- "Pre-define the translation string per mobile network. If you want a new mobile network in the GUI list, "
-- "add the item here as well as in the uci.mobiledongle.config.mobile_network_list list"
local all_mobile_networks = setmetatable({
  ["telstra_bigpond"]  = T'telstra.bigpond',
  ["telstra_internet"] = T'telstra.internet',
  ["telstra_extranet"] = T'telstra.extranet',
  ["other"]            = T'other'
}, untaint_mt)

local operator_mode_map	= setmetatable({
  ["AUTOMATIC"] = T"Automatic",
  ["MANUAL"]    = T"Manual",
}, untaint_mt)

local technology_map = setmetatable({
  ["3G"] = T"3G",
  ["4G"] = T"4G",
}, untaint_mt)

--"pin_verify_entries_left", "pin_unblock_entries_left"
-- Get the content_info
local content_info = {
  state             = "uci.mobiledongle.info.state",
  device_status     = "uci.mobiledongle.info.device_status",
  link_status       = "uci.mobiledongle.info.link_status",
  network           = "uci.mobiledongle.config.network",
  interface_enabled = "uci.mobiledongle.config.enabled",
  emi_detected      = "uci.usb.ehci_emi_detectNumberOfEntries"
}

content_helper.getExactContent(content_info)

local ci_state = content_info["state"]
if content_info["emi_detected"] then
  content_info["emi_detected"] = (content_info["emi_detected"] == "0") and "0" or "1"
end

-- "Find the translator strings in all_tech_modes and create a table to be displayed."
-- "The created current_tech_modes table is used as well for input validation."
local base = {}
local incomplete = {
  technology_list    = "uci.mobiledongle.config.technology_list.",
  operator_mode_list = "uci.mobiledongle.config.operator_mode_list.",
  operator_code_list = "uci.mobiledongle.config.operator_code_list.",
  mobile_networks    = "uci.mobiledongle.config.mobile_network_list."
}
content_helper.addListContent(base, incomplete )
local current_mobile_networks = {}
for index, value in ipairs(base.mobile_networks) do
  if all_mobile_networks[value] then
    current_mobile_networks[#current_mobile_networks + 1] = {value, all_mobile_networks[value]}
  end
end

local current_technology = {}
for index, value in ipairs(base.technology_list) do
  if technology_map[value] then
    current_technology[#current_technology + 1] = {value, technology_map[value]}
  end
end

local current_operator_mode = {}
for index, value in ipairs(base.operator_mode_list) do
  if operator_mode_map[value] then
    current_operator_mode[#current_operator_mode + 1] = {value, operator_mode_map[value]}
  end
end

local current_operator_code = {}
for index, value in ipairs(base.operator_code_list) do
  if current_operator_map[value] then
    current_operator_code[#current_operator_code + 1] = { value, current_operator_map[value] }
  end
end

if ngx.req.get_method() == "POST" then
  local args = ngx.req.get_post_args()
  local action = args["action"]

  if action == "CONNECT"  then
    proxy.set("uci.mobiledongle.config.enabled","1")
    proxy.apply()
  elseif action == "DISCONNECT"  then
    proxy.set("uci.mobiledongle.config.enabled","0")
    proxy.apply()
  elseif action == "NETWORK_CHANGE"  then
    local network = args["network"]
    content_info["network"] = network
    if (network) then
      proxy.set("uci.mobiledongle.config.network",network)
      proxy.apply()
    end
    ngx.print('{ "success":"true" }')
    ngx.exit(ngx.HTTP_OK)
  end
end

--- based on the ui_helper.createFooter Template we add the Connect/Disconnect button when the state is Disabled.
local function createFooterConnect()
	if  content_info["device_status"] == "CONNECTED" then
  		return format([[
     		<div class="modal-footer">
				<div class="monitor-link_status monitor-ERROR monitor-NA">
					<div id="modal-no-change">
						<div id=CONNECT class="btn btn-large custom-handler" data-value="connect" data-name="action">%s</div>
						<div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal">%s</div>
					</div>
					<div id="modal-changes" class="hide">
						<div id=CONNECT class="btn btn-large custom-handler" data-value="connect" data-name="action">%s</div>
						<div id="cancel-config" class="btn btn-large" data-dismiss="modal">%s</div>
						<div id="save-config" class="btn btn-primary btn-large">%s</div>
					</div>
				</div>
				<div class="monitor-link_status monitor-CONNECTED monitor-CONNECTING monitor-SEARCHING">
					<div id="modal-no-change">
						<div id=DISCONNECT class="btn btn-large custom-handler monitor-link_status monitor-CONNECTED" data-value="disconnect" data-name="action">%s</div>
						<div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal">%s</div>
					</div>
					<div id="modal-changes" class="hide">
						<div id=DISCONNECT class="btn btn-large custom-handler monitor-link_status monitor-CONNECTED" data-value="disconnect" data-name="action">%s</div>
						<div id="cancel-config" class="btn btn-large" data-dismiss="modal">%s</div>
						<div id="save-config" class="btn btn-primary btn-large">%s</div>
					</div>
				</div>
			</div>
    		]], T"Connect", T"Close", T"Connect" , T"Cancel", T"Save", T"Disconnect", T"Close", T"Disconnect", T"Cancel", T"Save")
	else
		return ui_helper.createFooter()
	end
end

--
-- validate SIM pin code. Must be 4 digits)
--
local function vPIN(value)
	    local errmsg = T"PIN code must composed of 4 digits"
    	if value == nil or #value == 0  then
			-- empty pin code just means that we don't want to set one
        	return true
    	end

	    local pin4 = value:match("^(%d%d%d%d)$")
	    if pin4 then
        	return true
    	end
    	return nil, errmsg
end

-- validate SIM puk code. Must be 8 digits)
local function vPUK(value)
    local errmsg = T"PUK code must composed of 8 digits"
    if value == nil or #value == 0 then
        -- empty pin code just means that we don't want to set one
        return true
    end

    local pin8 = value:match("^(%d%d%d%d%d%d%d%d)$")
    if pin8 then
        return true
    end
    return nil, errmsg
end

-- validate PPP password. Must be diff "*****" )
local function vPassword(value)
    local errmsg = T"PPP password must be different from *****"
    if value == nil or #value == 0 then
        -- empty pin code just means that we don't want to set one
        return true
    end

    local v = value:match("^([^* ]+)$")
    if v then
        return true
    end
    return nil, errmsg
end

local function vPUK(value)
    local errmsg = T"PUK code must composed of 8 digits"
    if value == nil or #value == 0 then
        -- empty pin code just means that we don't want to set one
        return true
    end

    local pin8 = value:match("^(%d%d%d%d%d%d%d%d)$")
    if pin8 then
        return true
    end
    return nil, errmsg
end

-- validate APN . can be validDomainName or Empty)
local function vAPN(value)
    if value == nil or #value == 0 then
        -- empty APN just means that we don't want to set one
        return true
    end
   return post_helper.validateNonEmptyString(value)
end

-- validate Requested Operator . can be an operator code or Empty in case of no config)
local function vRO(value)
    if value == nil or #value == 0  or #current_operator_code == 0 then
        -- empty current_operator just means that we don't want to set one
        return true
    end
    return post_helper.getValidateInEnumSelect(current_operator_code)
end

local selected_network_id = string.untaint(content_info["network"])
local mapParams = {
  pin                  = "uci.mobiledongle.sim.pin",
  puk                  = "uci.mobiledongle.sim.puk",
  network              = "uci.mobiledongle.config.network",
  apn                  = "uci.mobiledongle.mobile_network.@".. selected_network_id .. ".apn",
  username             = "uci.mobiledongle.mobile_network.@".. selected_network_id .. ".username",
  password             = "uci.mobiledongle.mobile_network.@".. selected_network_id .. ".password",
  operator_mode        = "uci.mobiledongle.config.operator_mode",
  requested_technology = "uci.mobiledongle.config.requested_technology",
  requested_operator   = "uci.mobiledongle.config.requested_operator",
}

local mapValid = {
  pin                  = post_helper.getValidationPassword(vPIN),
  puk                  = post_helper.getValidationPassword(vPUK),
  apn                  = vAPN,
  password             = post_helper.getValidationPassword(vPassword),
  operator_mode        = post_helper.getValidateInEnumSelect(current_operator_mode),
  requested_technology = post_helper.getValidateInEnumSelect(current_technology),
  requested_operator   =  vRO,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
%>

<%= ui_helper.createHeader(T"Mobile 3G/4G", false, true)%>
<div class="modal-body update">
  <form class="form-horizontal" method="post" action="modals/mobiledongle-configuration-modal.lp">
  <%
  local usb_error_attribs = {
    alert = {
      class = "alert-danger monitor-emi_detected monitor-1"
    }
  }
  if content_info["emi_detected"] == "0" then
    usb_error_attribs.alert.class = usb_error_attribs.alert.class .. " hide"
  end
  ngx.print(ui_helper.createAlertBlock(T"USB Error detected, please restart manually your device", usb_error_attribs))
  if ((ngx.req.get_method() == "POST") and (ngx.req.get_post_args().action == "CONNECT")) then %>
    <div class="alert alert-warning" id="warning_msg"><%=T"Please do not remove the wan interface cable when connecting to the mobile network"%></div>
  <% else %>
    <div class="alert alert-warning hide" id="warning_msg"><%=T"Please do not remove the wan interface cable when connecting to the mobile network"%></div>
  <% end

  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  local tabs = {
    {
      desc = T"Information",
      target = "modals/mobiledongle-information-modal.lp",
    },
    {
      desc = T"Configuration",
      active = "active",
      target = "modals/mobiledongle-configuration-modal.lp",
    },
  }
  ngx.print(ui_helper.createModalTabs(tabs))
  %>

    <fieldset id="mobiledongle-configuration-tab">

	<%
		local html = {}
                local emi_detected_attributes = {
                        input = {
                                class = "monitor-changes",
                                id = "emi_detected",
                                ["data-ajaxrefresh"] = "5",
                        },
                }
                html[#html+1] = ui_helper.createSimpleInputHidden("emi_detected", content_info["emi_detected"], emi_detected_attributes)

		local link_status_attributes = {
			span = {
				class = "span4",
        	},
			input = {
				class = "monitor-changes",
				id = "link_status",
				["data-ajaxrefresh"] = "5",
			},
		}
		tinsert(html, ui_helper.createSimpleInputHidden("link_status", content_info["link_status"], link_status_attributes))

		tinsert(html, "<legend>" .. T"Mobile Configuration" .. "</legend>")
		tinsert(html, "<div class=\"control-group monitor-link_status monitor-ERROR monitor-NA\">")
	    local networkattributes = {
			span = {
				class = "span4",
			},
	        select = {
	            class = "monitor-changes custom-handler",
				id = "network",
	        }
	    }
		tinsert(html, ui_helper.createInputSelect(T"Network","network", current_mobile_networks, content["network"],networkattributes))
		-- Show the APN
		local edit_apnclass = {
	        group = {
	            class ="monitor-network monitor-other",
	        },
			input = {
				pattern= "^([a-zA-Z]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$", -- [RFC 1034]
				maxlength= "255",
				class= "span3",
			}
		}
		local ro_apnclass = {
	        group = {
	            class ="monitor-network monitor-telstra_bigpond monitor-telstra_internet monitor-telstra_extranet",
	        },
			input = {
				class= "span3",
			}
		}
		tinsert(html, ui_helper.createInputText(T"APN", "apn", content["apn"], edit_apnclass, helpmsg["apn"]))
		tinsert(html, ui_helper.createLabel(T"APN", content["apn"], ro_apnclass))
	    local operator_mode_attributes_edit = {
			span = {
				class = "span4",
			},
	        group = {
	            class = "monitor-network monitor-other",
	        },
	        select = {
	            class = "monitor-changes",
	        }
	    }
		tinsert(html, ui_helper.createInputSelect(T"Operator Mode", "operator_mode", current_operator_mode, content["operator_mode"], operator_mode_attributes_edit))
		local show_manual_class_edit = {
	        group = {
	            class ="monitor-operator_mode monitor-MANUAL monitor-link_status monitor-ERROR monitor-NA",
	        },
			input = {
				class= "span3",
			}
		}
		tinsert(html, ui_helper.createInputSelect(T"Requested Operator", "requested_operator", current_operator_code, content["requested_operator"] or "", show_manual_class_edit))
		tinsert(html, ui_helper.createInputSelect(T"Requested Technology", "requested_technology", current_technology, content["requested_technology"], show_manual_class_edit))
		local mobiledongle_pin_class_edit = {
			input = {
				pattern= "^([0-9]{4})$",
				maxlength= "4",
				class= "span3"
			}
		}
		local mobiledongle_puk_class_edit = {
			input = {
				pattern= "^([0-9]{8})$",
				maxlength= "8",
				class= "span3"
			}
		}
		tinsert(html, ui_helper.createInputPassword(T"PIN", "pin", content["pin"], mobiledongle_pin_class_edit, helpmsg["pin"]))
		if ci_state == "PUK_REQUIRED" then
			tinsert(html, ui_helper.createInputPassword(T"PUK", "puk", content["puk"], mobiledongle_puk_class_edit, helpmsg["puk"]))
		end

		tinsert(html, "</div>")
		tinsert(html, "<div class=\"control-group monitor-link_status monitor-CONNECTED monitor-CONNECTING monitor-SEARCHING\">")
		local networkattributesLabel = {
			span = {
				class = "span4",
			},
			select = {
				class = "monitor-changes custom-handler",
				id = "network",
			}
		}
		tinsert(html, ui_helper.createLabel(T"Network", all_mobile_networks[content["network"]],networkattributesLabel))

		local noedit_ro_apnclass = {
	        group = {
	            class ="monitor-network monitor-telstra_bigpond monitor-other",
	        },
			input = {
				class= "span3",
			}
		}
		tinsert(html, ui_helper.createLabel(T"APN", content["apn"], noedit_ro_apnclass))

	    local operator_mode_attributes = {
			span = {
				class = "span4",
			},
--	        group = {
--	            class = "monitor-link_status",
--	        },
	        select = {
	            class = "monitor-changes",
	        }
	    }
		tinsert(html, ui_helper.createLabel(T"Operator Mode", operator_mode_map[content["operator_mode"]], operator_mode_attributes))

		local show_manual_class = {
	        group = {
	            class ="monitor-operator_mode monitor-MANUAL",
	        },
			input = {
				class= "span3",
			}
		}
		tinsert(html, ui_helper.createLabel(T"Requested Operator", current_operator_map[content["requested_operator"]], show_manual_class))
		tinsert(html, ui_helper.createLabel(T"Requested Technology", technology_map[content["requested_technology"]], show_manual_class))

		local mobiledongle_pin_class = {
			input = {
				pattern= "^([0-9]{4})$",
				maxlength= "4",
				class= "span3"
			}
		}
		local mobiledongle_puk_class = {
			input = {
				pattern= "^([0-9]{8})$",
				maxlength= "8",
				class= "span3"
			}
		}
		tinsert(html, ui_helper.createLabel(T"PIN", "********", mobiledongle_pin_class))
		if ci_state == "PUK_REQUIRED" then
			tinsert(html, ui_helper.createLabel(T"PUK", "********", mobiledongle_puk_class))
		end

		tinsert(html, "</div>")

		tinsert(html, "<legend>" .. T"Network Authentication" .. "</legend>")
	    local show_cred_class_edit = {
	        group = {
	            class ="monitor-network monitor-other monitor-telstra_bigpond monitor-link_status monitor-ERROR monitor-NA",
	        },
	        input = {
	            class= "span4",
	        }
	    }
	    local show_cred_class = {
	        group = {
	            class ="monitor-network monitor-other monitor-telstra_bigpond monitor-link_status monitor-CONNECTED monitor-CONNECTING monitor-SEARCHING",
	        },
	        input = {
	            class= "span4",
	        }
	    }
		tinsert(html, ui_helper.createInputText(T"Username", "username", content["username"], show_cred_class_edit, helpmsg["username"]))
		tinsert(html, ui_helper.createInputPassword(T"Password", "password", content["password"], show_cred_class_edit, helpmsg["password"]))
		tinsert(html, ui_helper.createLabel(T"Username", content["username"], show_cred_class))
		tinsert(html, ui_helper.createLabel(T"Password",  "********", show_cred_class))

		tinsert(html, "</fieldset>")

		ngx.print(html)
		%>
	</form>
</div>
<div id="spinner"  class="loading-wrapper hide" style="background:none;">
  <img id="img-spinner" src="../img/spinner.gif" alt="changing connection state" />
</div>
<div id="spinner_small" class="spinner hide">
  <img id="img-spinner" src="../img/spinner.gif" alt="changing network" style="margin-left: 5px; margin-right: 5p
x; margin-top: 5px; margin-bottom: 5px; width:64px; height=64px"/>
</div>
<% ngx.print(createFooterConnect()) %>

<script>
(function() {
  var modalbody = $(".modal-body");
  var busy_msg = $("#spinner");
  var target = $(".modal form").attr("action");
  var scrolltop = $(".modal-body").scrollTop();
  var initialDelay = 5000;
  var delay = initialDelay;

  function wait_for_connect_reply() {
    if ( delay === initialDelay) {
      delay = 0;
      window.setTimeout(function() {
        tch.loadModal(target, function () {
          $(".modal-body").scrollTop(scrolltop);
        });
      }
      , initialDelay);
    }
  };

  function wait_for_network_reply() {
    tch.loadModal(target, function () {
      $(".modal-body").scrollTop(scrolltop);
    });
  };

  $("#CONNECT").click(function(){
    $("#warning_msg").removeClass("hide");
    busy_msg.removeClass("hide");
    $(this).addClass("hide");
    $(".modal-action-refresh").addClass("hide");
    busy_msg[0].scrollIntoView();

    $.post(
      target,
      {
        action:"CONNECT",
        CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
      },
      function(data){
        window.setTimeout(function(){
        $("#mobiledongle-information-modal").html(data);
        busy_msg.addClass("hide");
        tch.modalLoaded();},5000);
      }
    );
    return false;
  });

  $("#DISCONNECT").click(function() {
    $("#warning_msg").addClass("hide");
    busy_msg.removeClass("hide");
    $(this).addClass("hide");
    $(".modal-action-refresh").addClass("hide");
    busy_msg[0].scrollIntoView();
    $.post(
      target,
      {
        action:"DISCONNECT",
        CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
      },
      wait_for_connect_reply
    );
    return false;
  });

  $("#network").change(function() {
    var msg_dst = $(this);
    var busy_msg = $("#spinner_small");
    msg_dst.after(busy_msg);
    busy_msg.removeClass("hide");
    busy_msg[0].scrollIntoView();
    $("#connect").addClass("hide");

    $.post(
      target,
      {
        action:"NETWORK_CHANGE",
        network: document.getElementById("network").value,
        CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
      },
      wait_for_network_reply,
      "json"
    );
  return false;
  });
}());
</script>
