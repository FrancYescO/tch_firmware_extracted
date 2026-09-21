<%
--[[
   Upgrade Page 
   A:David Relf
   E:david.relf@technicolor.com
   
   Page for the FastWeb TG582n v2 due to memory limitation
   
   V1.0 - Initial version with Change control
]]
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local format,find,sub,untaint = string.format, string.find, string.sub, string.untaint
local floor, ipairs = math.floor, ipairs
local print = ngx.print
local lp = require("web.lp")
-- Enable localization




local cui = {
    nsplink = "uci.web.uiconfig.@uidefault.nsplink",
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	versionmask = "uci.version.version.@version[0].mask",
   --Add line for checking for the upgrade flag
   upgrade = "uci.env.var.upgrade",
}
content_helper.getExactContent(cui)
--[[
if ngx.req.get_method() == "POST" then
  local post_args = ngx.req.get_post_args()
  if post_args.do_signout then
    ngx.ctx.session:logout()
    -- Now we redirect to / until we find a better solution
    -- Otherwise, the current page might be rendered while the default user is not allowed to see it
    -- since the access was checked for the user "before" logging out
    -- TODO: find a more elegant solution, in session module?
    ngx.redirect("/");
  end
end
]]
function split(x, sep)
        local sep, fields = sep or ":", {}
        local pattern = format("([^%s]+)", sep)
        x:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end


local sw = {
   version = "uci.version.version.@version[0].version",
}
content_helper.getExactContent(sw)


local version = ""
local tmpsplit = split(sw.version, "-")
if #tmpsplit > 1 then
   version = format("%s-%s",tmpsplit[1],tmpsplit[2])
end

local function wait_for_completion(base_path, return_json, filename)
  local state_path = base_path .. "state"
  local info_path = base_path .. "info"
  local sleep_time = 0.250
  local max_time = 5
  local total_time = 0
  local content
  repeat
    ngx.sleep(sleep_time)
    total_time = total_time + sleep_time

    content = { state = state_path, info = info_path }
    content_helper.getExactContent(content)

    if content.state ~= "Requested" then
      break
    end
  until (total_time >= max_time)
  if filename then
    os.remove(filename)
  end
  if content.state ~= "Complete" then
    if content.state == "Requested" then
      ngx.log(ngx.ERR, "Timeout on ", base_path)
    else
      ngx.log(ngx.ERR, format('Error on %s (state="%s", info="%s")',
        base_path, content.state, content.info or ""))
    end
    if return_json then
      ngx.print('{ "error":"10" }')
      ngx.exit(ngx.OK)
    else
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
  end
end

local function receive_file(filename, match)
  local upload = require("web.fileupload")
  local form, err = upload.fromstream()
  if not form then
    return false, 1, "failed to create upload ctx: " .. err
  end
  local file
  local discard = false
  while true do
    local token, data, err = form:read()
    if not token then
      return false, 2, "read failed: " .. err
    end
    if token == "header" then
      if not discard and not file and find(data[2], match, 1, true) then
        file = io.open(filename, "w")
      end
      if not discard and not file then
        return false, 3, "failed to start receiving file"
      end
    elseif token == "body" then
      if file then
        file:write(data)
      end
    elseif token == "part_end" then
      if file then
        file:close()
        file = nil
        discard = true
      end
    elseif token == "eof" then
      break
    end
  end

  return true
end


local function upgradefw()
  local fwupgrade_rpc_path = "rpc.system.fwupgrade."
  local filename = "fwupgrade.bin"

  local content = {
    fwupgrade_state = fwupgrade_rpc_path .. "state",
    fwupgrade_location = fwupgrade_rpc_path .. "location"
  }
  content_helper.getExactContent(content)
  if content.fwupgrade_state == "Requested" then
    ngx.log(ngx.ERR, "upgrade already in progress")
    ngx.print('{ "error":"0" }')
    ngx.exit(ngx.OK)
  end

  -- flush the web template cache
  lp.flush()

  -- force GC to run to try to prevent lua from taking more memory during
  -- the upgrade action by having it reclaim some unused objects. This won't
  -- shrink the linux memory usage, but it might prevent it from becoming
  -- even bigger.
  collectgarbage()
  collectgarbage()
  local rcv_ok, rcv_errno, rcv_errmsg = receive_file(untaint(content.fwupgrade_location) .. filename, 'name="upgradefile"')

  -- start actual upgrade through rpc
  proxy.set({ [fwupgrade_rpc_path .. "filename"] = "fwupgrade.bin" })
  proxy.set({ [fwupgrade_rpc_path .. "state"] = "Requested" })

  ngx.print('{ "success":"true" }')
  ngx.exit(ngx.HTTP_OK)
end

local function upgradefwstatus()
  local fwupgrade_rpc_path = "rpc.system.fwupgrade."

  local state = proxy.get(fwupgrade_rpc_path .. "state")[1].value

  ngx.header.content_type = "application/json"
  if state == "Requested" then
    ngx.print('{ "success":"true" }')
  else
    local content = {}
    local results = proxy.get(fwupgrade_rpc_path)
    for _, result in ipairs(results) do
      content[result.param] = result.value
    end

    os.remove(untaint(content.location .. content.filename))
    ngx.print('{ "success":"false" , "errorcode":"' .. untaint(content.errorcode) .. '" }')
  end

  ngx.exit(ngx.HTTP_OK)
end

local function resetreboot(path)
  proxy.set(path, "1")
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

-- Handle fwupgrade/configimport/configexport specific GET/POSTs.
if ngx.req.get_method() == "POST" then
  local action = ngx.req.get_uri_args().action
  -- do not call get_post_args before we know that we don't have a file sent otherwise it will fail
  if action == "import_config" then
    return import_config()
  end
  if action == "upgradefw" then
    return upgradefw()
  end
  -- now process non-file POSTs
  local action = ngx.req.get_post_args().action
  if action == "export_config" then
    return export_config()
  end
  if action == "system_reset" then
    return resetreboot("rpc.system.reset")
  end
  if action == "system_reboot" then
    return resetreboot("rpc.system.reboot")
  end
elseif ngx.req.get_method() == "GET" then
  local action = ngx.req.get_uri_args().action
  local content = {
    fwflash_size = "uci.env.var.banksize"
  }
  content_helper.getExactContent(content)

  if action == "upgradefwstatus" then
      return upgradefwstatus()
  end
  if action == "getbanksize" then
     ngx.header.content_type = "application/json"
     ngx.print('{ "success":"true" , "banksize":"' .. untaint(content.fwflash_size) .. '" }')
     ngx.exit(ngx.HTTP_OK)
        --end
  end
end


local session = ngx.ctx.session
-- Non-configurable data
local content = {
  vendor = "uci.env.var.company_name",
  product_name = "uci.env.var.prod_friendly_name",
  software_name = "uci.version.version.@version[0].marketing_name",
  software_version = "uci.version.version.@version[0].marketing_version",
  firmware_version = "uci.version.version.@version[0].version",
  hardware_version = "uci.env.rip.board_mnemonic",
  factory_id = "uci.env.rip.factory_id",
  serial_number = "uci.env.rip.serial",
  mac_address = "uci.env.rip.eth_mac",
  fwversion_prefix = "uci.versioncusto.override.fwversion_prefix",
  fwversion_suffix = "uci.versioncusto.override.fwversion_suffix",
  fwversion_override = "uci.versioncusto.override.fwversion_override",
}

content_helper.getExactContent(content)
if content["firmware_version"] then
  local version = content["firmware_version"]
  content["firmware_version"] = content.fwversion_prefix .. sub(version, 1, find(version, "%-[^%-]*$") - 1) .. content.fwversion_suffix
  if content.fwversion_override then
    if content.fwversion_override == "override1" then
      content["firmware_version"] = content.fwversion_prefix .. sub(version, 1, find(version, "%-") -1) .. content.fwversion_suffix
    end
  end
end





%>
<!DOCTYPE HTML>
<%= string.format('<html lang="%s">', gettext.language()) %>
  <head>
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta charset="UTF-8">
    <meta name="CSRFtoken" content="<%= ngx.ctx.session:getCSRFtoken() %>">
    
    <link href="/css/gw.css" rel="stylesheet">
    <link href="/css/responsive.css" rel="stylesheet">
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->
    <script src="/js/main-min.js" ></script>
    
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->
    <title><%= T"Upgrade" %></title>
  <script type='text/javascript'> 
    function Popup(x){
        var moveLeft = 10;
        var moveRight = -390;
        var moveDown = -50;
        var header = '<%= ui_helper.createCardHeader(T"Processing", "", "","")  %>';
       $("body").append('<div class=\"popUpBG\"></div>')
       $("body").append('<div id="popUp"  class="smallcard span3">'+header+'<div id="Poptxt" class="content"></div>')
            
       $("#Poptxt").html(x);
       $d = $("#popUp");
       var pagewidth = $("body").width();
       var thiswidth = $d.width();
       var center = (pagewidth / 2) - (thiswidth / 2);
       var width = window.innerWidth || document.documentElement.clientWidth;
       $d.css({'left': center, 'height': '130px', 'margin': '0px'}).appendTo('body').slideDown("fast");
          
    } 
    function PopupRemove(){  
      $('.popUpBG').remove();
      $('#popUp').remove();
    }   
  </script>
  </head>

<body>
   <div class="feedback">

  </div>
  <div class="container">
    <div class="row">
      <div class="header span12">
        <a href="<%= cui.nsplink %>" target="_blank"><img src="/img/logo.gif"></a>
        <%
        local session = ngx.ctx.session
        local html = {}

        html[#html + 1] = [[<div class="pull-right">]]
        if session:isdefaultuser() then
            html[#html + 1] = '<a href="login.lp" class="btn" id="signin">'
            html[#html + 1] = T"Sign in"
            html[#html + 1] = '</a>'
        else
            html[#html + 1] = [[          <div class="btn-group" id="logged">
                    <button class="btn"> ]]
            html[#html + 1] = session:getusername()
            html[#html + 1] = [[ </button>
                    <button class="btn dropdown-toggle" data-toggle="dropdown">
                      <span class="caret"></span>
                    </button>
                    <ul class="dropdown-menu pull-right">
                      <li><a tabindex="-1" href="/password.lp" id="changepass">]]
            html[#html + 1] = T"Change my password"
            html[#html + 1] = [[ </a></li><li class="divider"></li><li><a tabindex="-1" href="/" id="signout"> ]]
            html[#html + 1] = T"Sign out"
            html[#html + 1] = [[</a></li></ul></div>]]
        end
        html[#html + 1] = [[</div>]]

        html[#html + 1] = [[<div class="pull-right">]]
        html[#html + 1] = ui_helper.createLanguageSelect('webui-core', gettext.language())
        html[#html + 1] = [[</div>]]

        ngx.print(html)
        %>
      </div>
    </div>
    
    <div class="row">
        <div class="smallcard span6 upgrade_card">
      
          <%= ui_helper.createCardHeader(T"Upgrade", "", "","")  %>
            <div class="upgrade_contents">
               
               
               
               
   
               
            <fieldset>
               <legend><%= T"Upgrade Options" %></legend>  
               
               
               
           <%
      local basic = {
        span = {
          class = "span5"
        },
      }
      local advanced = {
        group = {
          class = "advanced hide",
        },
        span = {
          class = "span5"
        },
      }
      local wait_for_reboot = {
        group = {
          class = "wait-for-reboot"
        },
        button = {
          id = "btn-system-reboot",
          class = "custom-handler"
        }
      }
      local rebooting = {
        alert = {
          class = "alert hide",
          id = "rebooting-msg"
        }
      }
      local wait_for_reset = {
        group = {
          class = "wait-for-reset"
        },
        button = {
          id = "btn-system-reset",
          class = "custom-handler"
        }
      }
      local resetting = {
        alert = {
          class = "alert hide",
          id = "resetting-msg"
        }
      }

      local upgradefw = {
        button = {
          class = "upgradefw",
          id = "btn-upgrade"
        }
      }
      local upgrading_nofile = {
        alert = {
          class = "alert-error hide",
          id = "upgrade-nofile-msg"
        }
      }
      local upgrading_transfer = {
        alert = {
          class = "alert hide",
          id = "upgrade-transfer-msg"
        }
      }
      local upgrading_busy = {
        alert = {
          class = "alert hide",
          id = "upgrade-busy-msg"
        }
      }
      local upgrading_fail = {
        alert = {
          class = "alert-error hide",
          id = "upgrade-failed-msg"
        }
      }
      local upgrading_wrong_ext_fail = {
        alert = {
          class = "alert-error hide",
          id = "upgrade-wrong-ext-msg"
        }
      }
      local upgrading_too_big_fail = {
        alert = {
          class = "alert-error hide",
          id = "upgrade-too-big-msg"
        }
      }
      local nw_enable_class = {
        input = {
          class = "monitor-changes",
          --disabled = "disabled",
        }
      }
      local upgradecancel = {
        button = {
          class = "upgradecancel",
          id = "btn-upgradecancel"
        }
      }
      local upgradefile = {
        button = {
          class = "upgradefile",
          id = "btn-upgradefile"
        }
      }
      local file_selected = {
        alert = {
          class = "alert hide",
          id = "file_selected-msg"
        }
      }
      local html = {} 

      --if cui.upgradefw == "1" then
        html[#html + 1] = '<form class="form-horizontal" id="form-upgradefw" method="post" action="upgrade.lp?action=upgradefw" enctype="multipart/form-data">'
        html[#html + 1] = '<div class="control-group">'
        html[#html + 1] = format('<label class="control-label">%s</label>', T"Upgrade firmware")
        html[#html + 1] = '<div class="controls">'
        html[#html + 1] = ui_helper.createSimpleButton(T"Select File", "icon-file", upgradefile)
        html[#html + 1] = ui_helper.createSimpleButton(T"Upgrade", "icon-shield", upgradefw)

       
        html[#html + 1] = ui_helper.createSimpleButton(T"Cancel", "icon-remove", upgradecancel)
        html[#html + 1] = ui_helper.createAlertBlock(T"File Selected.", file_selected)
        html[#html + 1] = ui_helper.createAlertBlock(T"No file selected.", upgrading_nofile)
        html[#html + 1] = ui_helper.createAlertBlock(T"Uploading firmware, please wait...", upgrading_transfer)
        html[#html + 1] = ui_helper.createAlertBlock(T"Firmware upgrade in progress, please wait...", upgrading_busy)
        html[#html + 1] = ui_helper.createAlertBlock(T"Firmware upgrade failed.  Unknown Error.", upgrading_fail)
        html[#html + 1] = ui_helper.createAlertBlock(T"Firmware upgrade failed.  Invalid file used: expected file with extension rbi.  Please use correct firmware.", upgrading_wrong_ext_fail)
        html[#html + 1] = ui_helper.createAlertBlock(T"Firmware upgrade failed.  Invalid file used: file too large.  Please use correct firmware.", upgrading_too_big_fail)

        html[#html + 1] = '</div></div>'
      --end
      
      ngx.print(html)
    %>

 
  </fieldset>
</div>

<script>
(function() {
  var refreshTimeOut = 5000;
  var refreshDelay = 3000;
  var target = $("#form-upgradefw form").attr("action");

  function wait_for_webserver_running() {
    $.ajax({ url: "/", timeout: refreshTimeOut })
    .done(function(data) {
      document.open("text/html");
      document.write(data);
      document.close();
    })
    .fail(function() {
      window.setTimeout(wait_for_webserver_running, refreshDelay);
    });
  }

  function wait_for_webserver_down() {
    $.ajax({ url: target, timeout: refreshTimeOut })
    .done(function() {
      window.setTimeout(wait_for_webserver_down, refreshDelay);
    })
    .fail(function() {
      window.setTimeout(wait_for_webserver_running, refreshDelay);
    });
  }

  function resetreboot(msg, msg_dst, action) {
    msg_dst.after(msg);
    msg.removeClass("hide");
    msg[0].scrollIntoView();
    $.post(
      target,
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
      wait_for_webserver_down,
      "json"
    );
    return false;
  }

 
  

  function wait_for_upgradefw() {

 // Do not use the default values.
 // On low memory boards sysupgrade use all resources.
 // Do not request too often an upgradefwstatus.
 // It takes more than 5 sec to check if sysupgrade is running.
 // Sysupgrade is running for at least 10 sec.

    var upgrfw_refreshTimeOut = 15000;
    var upgrfw_refreshDelay = 10000;
    var msg = $("#upgrade-busy-msg");
    var msg_dst = $(this);
    msg_dst.after(msg);
    msg.removeClass("hide");
    msg[0].scrollIntoView();
    PopupRemove();
    Popup("<%=T"Firmware upgrade in progress, please wait..."%>");
    function waitForShutdownOrError() {
      $.ajax({ url: target, data: "action=upgradefwstatus", timeout: upgrfw_refreshTimeOut, dataType: "json" })
      .done(function(data) {
        if (data.success == "true") {
          window.setTimeout(waitForShutdownOrError, upgrfw_refreshDelay);
        }
        else {
          msg.addClass("hide");
          var failure_msg = $("#upgrade-failed-msg");
          switch (data.errorcode) {
          case "1":
            failure_msg.text("<%= T'Firmware upgrade failed.  Insufficient free memory available. Please reboot and try again.' %>");
            break;
          case "10":
          case "255":
            failure_msg.text("<%= T'Firmware upgrade failed; please use the correct firmware.' %>");
            break;
          default:
            failure_msg.text("<%= T'Firmware upgrade failed.' %>");
            break;
          }
          failure_msg.text(failure_msg.text() + " (<%= T'Errorcode: ' %>" + data.errorcode + ")")
          failure_msg.removeClass("hide");
          failure_msg[0].scrollIntoView();
          PopupRemove();
          
        }
      })
      .fail(wait_for_webserver_running)
    }
    window.setTimeout(waitForShutdownOrError, upgrfw_refreshDelay);
    return false;
  }

  $(".upgradefw").click(function() {
    $('#file_selected-msg').hide();
    var nofile_msg = $("#upgrade-nofile-msg");
    var wrongext_msg = $("#upgrade-wrong-ext-msg");
    var toobig_msg = $("#upgrade-too-big-msg");
    if ($("#file-upgradefw").val() == "") {
      nofile_msg.removeClass("hide");
      nofile_msg[0].scrollIntoView();
      return false;
    }
    nofile_msg.addClass("hide");

    var validExtensions = ['rbi','fw'];
    var fileName = $("#file-upgradefw").val();
    var fileNameExt = fileName.substr(fileName.lastIndexOf('.') + 1);
    if ($.inArray(fileNameExt, validExtensions) == -1){
        wrongext_msg.removeClass("hide");
	wrongext_msg[0].scrollIntoView();
	return false;
    }
    wrongext_msg.addClass("hide");
    var fileSize = $("#file-upgradefw")[0].files[0].size;

    $.ajax({ url: target, data: "action=getbanksize", timeout: refreshTimeOut, dataType: "json" })
      .done(function(data) {
          if (data.success == "true") {
	    var targetBankSize = Number(data.banksize);

	    if (fileSize > targetBankSize) {
    		toobig_msg.removeClass("hide");
		toobig_msg[0].scrollIntoView();
		return false;
	    }
	  }
      })
    toobig_msg.addClass("hide");

    var _this = $(this).parents(".control-group");
    $("#upgrade-failed-msg").addClass("hide");
    var upgrading_msg = $("#upgrade-transfer-msg");
    upgrading_msg.removeClass("hide");
    upgrading_msg[0].scrollIntoView();
    $.fileUpload($("#form-upgradefw"), {
      params: { CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
      completeCallback: function(form, response) {
        $("#upgrade-transfer-msg").addClass("hide");
        if (response.success) {
          wait_for_upgradefw.call(_this);
        }
        else {
          $("#upgrade-failed-msg").removeClass("hide");
        }
      }
    });
    return false;
  });
  $(".upgradecancel").click(function() {
      $(location).attr("href","/");
  });
  $(".upgradefile").click(function() {
      $('#file-upgradefw').click();
  });
}());


</script>
               
      
               
</fieldset>
               
               
               
               
               
               
               
               
               
               
               
               
               
               
               
               
               
               
               
               
               
               
               
                 

        </div>
      </div>
    <%
local html2 = {}

html2[#html2 + 1] = '<input type="file" name="upgradefile" id="file-upgradefw" style="visibility : hidden;">&nbsp;'
ngx.print(html2)
%>

<script>
(function() {
$('#file-upgradefw').on('change',function(){if ($('#file-upgradefw').val()){$('#file_selected-msg').show();}else{$('#file_selected-msg').hide();}});
}());
</script>
   </form>

    <div class="row">
      <div class="copyright span12">
         <p>&copy; Technicolor 2015</p>

         <p><%=format(T"Software Version: %s",version)%></p>
      </div>
    </div>
  </div>




</body>
</html>
