--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local proxy = require("datamodel")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local string = string
local match = string.match
local ipairs = ipairs
local next = next
local usbInfo = content_helper.convertResultToObject("sys.usb.device.", proxy.get("sys.usb.device."))

local paramMap = {
  sambaEnabled =  "uci.samba.samba.enabled",
  shareAll     =  "uci.samba.samba.filesharing",
  printersharingEnabled = "uci.printersharing.config.enabled",
}

local validateMap = {
  sambaEnabled = post_helper.validateBoolean,
  shareAll     = post_helper.validateBoolean,
  printersharingEnabled = post_helper.validateBoolean,
}

local pageInfo, errMsg = post_helper.handleQuery(paramMap, validateMap)

local resetFileSharing = {
  resetFilesharingParam = "uci.uci-defaults.sharingsettings.file_sharing",
}
content_helper.getExactContent(resetFileSharing)

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  if (next(errMsg)) then
    ngx.print('<input type="hidden" id="post_status" value="error">')
  else
    ngx.print('<input type="hidden" id="post_status" value="success">')
  end
end

local getData = {
  resetFilesharingParam = "uci.uci-defaults.sharingsettings.file_sharing",
  gatewayIP             = "uci.network.interface.@lan.ipaddr",
}
content_helper.getExactContent(getData)

local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
\
<h1><span>');  ngx.print(T"Network Share (Samba)"); ngx.print('</span></h1>\
<h2><span>');  ngx.print(T"It is possible to share the content of connected USB devices in your network using network shares(Samba)."); ngx.print('</span></h2>\
<form id="samba_form" class="form-horizontal" method="post" action="modals/samba.lp">\
  <input type="hidden" name= "sambaEnabled" id= "sambaEnabled" value = "');  ngx.print(pageInfo.sambaEnabled); ngx.print('"></input>\
  <input type="hidden" name= "shareAll" id= "shareAll" value = "');  ngx.print(pageInfo.shareAll); ngx.print('"></input>\
  <input type="hidden" name= "printersharingEnabled" id="printersharingEnabled" value = "');  ngx.print(pageInfo.printersharingEnabled); ngx.print('">\
  <input type="hidden" name= "CSRFtoken" id="CSRFtoken" value = "');  ngx.print(CSRFtoken); ngx.print('"></input>\
  <input type="hidden" name= "action" id="action" value = "SAVE"></input>\
<div class="h3-content vdf-table mobile-padding-bottom-lg">\
    <div class="message message-info">\
        ');  ngx.print(T"Remember that this service is by default disabled. For security reasons we recommend that you deactivate these services when you are not using them."); ngx.print('</div>\
    <div class="h3-wrapper-content">\
        <div class="left"></div>\
        <div class="right"></div>\
    </div>\
    <div class="vdf-row">\
        <div class="left">\
            <span>');  ngx.print(T"Shared Network (Samba)"); ngx.print('</span> </div>\
        <div class="right">\
            <div id="samba-btn-sambaService" class="button toggle-row-enable ');  if pageInfo["sambaEnabled"] == "1" and pageInfo["shareAll"] == "1" then  ngx.print('button-on ');  else  ngx.print(' button-off ');  end  ngx.print('"></div>\
        </div>\
    </div>\
</div>\
<div id="fileshare-name-info" class="vdf-row" ');  if pageInfo["sambaEnabled"] == "0" or pageInfo["shareAll"] == "0" then ngx.print('style="display:none"');  end  ngx.print('>\
  ');  for _, data in ipairs(usbInfo) do
    for key in pairs(data) do  ngx.print('\
      ');  local interfaceIndex = match(key , "^interface%.(%d)%.bInterfaceClass$")  ngx.print('\
      ');  if interfaceIndex and data["interface."..interfaceIndex..".bInterfaceClass"] == "08" then  ngx.print('\
        ');  local partitionTable = content_helper.convertResultToObject("sys.usb.device."..data["paramindex"]..".partition.", proxy.get("sys.usb.device."..data["paramindex"]..".partition."))  ngx.print('\
        ');  if next(partitionTable) then  ngx.print('\
          <h3><span>');  ngx.print(data["product"]); ngx.print('</span></h3>\
            <div class="h3-content vdf-table mobile-padding-bottom-lg">\
              ');  for _, partition in ipairs(partitionTable) do  ngx.print('\
                <div class="vdf-row">\
                  <div class="left">\
                    <span> </span> </div>\
                    <div class="right break-words">\
                      <span id="samba-info-mountPath">');  ngx.print("\\\\"..getData["gatewayIP"].."\\"..partition["Share"]); ngx.print('</span>\
                    </div>\
                </div>\
              ');  end  ngx.print('\
			</div>\
        ');  end  ngx.print('\
      ');  end
    end  ngx.print('\
</div>\
');  end  ngx.print('\
        <!-- TODO -->\
        <!-- Not supported elements -->\
        <!--<div class="vdf-row">\
            <div class="left">\
                <span>');  ngx.print(T"Enable Device for Content Sharing via Network Share"); ngx.print('</span> </div>\
            <div class="right">\
                <div class="button button-on"></div>\
            </div>\
        </div>\
        <div class="vdf-row">\
            <div class="left">\
                <span>');  ngx.print(T"Require Username and Password"); ngx.print('</span> </div>\
            <div class="right">\
                <div class="button button-on"></div>\
            </div>\
        </div>\
        <div class="vdf-row">\
            <div class="left">\
                <span>');  ngx.print(T"Username"); ngx.print('</span> </div>\
            <div class="right">\
                <input value="vodafone" type="text">\
            </div>\
        </div>\
        <div class="vdf-row">\
            <div class="left">\
                <span>');  ngx.print(T"Current Password"); ngx.print('</span> </div>\
            <div class="right">\
                <input id="pwdCharact" value="vodafone" type="password">\
            </div>\
        </div>\
        <div class="vdf-row">\
            <div class="left"></div>\
            <div class="right">\
                <span>');  ngx.print(T"Display Characters"); ngx.print('</span>\
                <input id="displayCharact" class="checkbox checkbox-unchecked" type="checkbox">\
                <label for="displayCharact"></label>\
            </div>\
        </div>\
        <div class="vdf-row">\
            <div class="left"></div>\
            <div class="right">\
                <input class="button button-blank change-pw" value="Change Password" type="button" data-toggle="modal" data-target="#sambaChangePasswordModal">\
            </div>\
        </div>-->\
</div>\
\
');  
    lp.include("apply-cancel.lp")
    lp.include("reset-wrap-mobile.lp")
  ngx.print('\
 </form>\
\
<!-- TODO -->\
<!-- Not supported elements -->\
<!-- Reset Password Popup Modal-->\
<!--<div class="modal fade" id="sambaChangePasswordModal" role="dialog" tabindex="-1" aria-hidden="true" data-keyboard="false" data-backdrop="static">\
	<div class="modal-dialog">\
		<!-- Modal content-->\
		<!--<div class="modal-content change-password-content">\
			<div class="modal-header hidden-md hidden-sm hidden-lg">\
				<div class="mobile-cancel-popup button-cancel" data-dismiss="modal"> </div>\
			</div>\
			<div class="modal-body no-padding mobile-modal-padding-top">\
				<p class="title">\
					');  ngx.print(T"Change password"); ngx.print('    </p>\
				<div class="table-wrapper vdf-table">\
					<div class="vdf-row">\
						<div class="left">\
							<span>');  ngx.print(T"New Password"); ngx.print('</span>            </div>\
						<div class="right">\
							<input type="password">\
						</div>\
					</div>\
					<div class="vdf-row">\
						<div class="left">\
							<span>');  ngx.print(T"Confirm Password"); ngx.print('</span>            </div>\
						<div class="right">\
							<input type="password">\
						</div>\
					</div>\
				</div>\
				<div class="apply-cancel">\
					<input class="button button-apply no-mobile-margin-top mob-button-width" value="Apply" type="button" data-dismiss="modal">\
					<input class="button button-cancel mob-apply-cancel mob-button-width" value="Cancel" type="button" data-dismiss="modal">\
				</div>\
			</div>\
		</div>\
	</div>\
</div>-->\
<!-- End -->\
<script src="/js/global.js"> </script>\
<script>\
$(\'select\').chosen({\
  disable_search_threshold: 100000,\
  allow_single_deselect: true\
});\
  $(function() {\
    $("#samba-btn-sambaService").click(function(){\
      var id = $(this).attr("id");\
      var printersharingEnabled = $("#printersharingEnabled").val();\
      if($(this).hasClass(\'button-on\')){\
        if (id == "samba-btn-sambaService") {\
          if (printersharingEnabled == "0")\
            $("#sambaEnabled").val("0");\
          $("#shareAll").val("0");\
          $(".samba").slideUp("400");\
        }\
        $(this).removeClass(\'button-on\').addClass(\'button-off\');\
        $("#fileshare-name-info").hide();\
      }\
      else{\
        if (id == "samba-btn-sambaService"){\
          $("#sambaEnabled,#shareAll").val("1");\
          $(".samba").slideDown("400");\
        }\
        $(this).removeClass(\'button-off\').addClass(\'button-on\');\
        $("#fileshare-name-info").css("display","table-row");\
      }\
    });\
\
  $("#global-apply").click(function() {\
    postHandler("/modals/samba.lp", $("#samba_form").serializeArray());\
  });\
\
  $("#global-cancel").click(function() {\
    $("#content").load("/modals/samba.lp");\
  });\
});\
\
$("#resetR, .resetR").click(function(){\
  function changeButton(id, value, hiddenClass)\
  {\
    $(id).val(value);\
    if (value == "1") {\
      $(id).addClass(\'button-on\').removeClass(\'button-off\');\
      $(hiddenClass).val("1");\
      if (id == "#samba-btn-sambaService")\
        $(".samba").slideDown("400");\
    }\
    else\
    {\
      $(id).addClass(\'button-off\').removeClass(\'button-on\');\
      $(hiddenClass).val("0");\
      if (id == "#samba-btn-sambaService")\
        $(".samba").slideUp("400");\
    }\
  }\
  changeButton("#samba-btn-sambaService", "0", "#sambaEnabled");\
});\
</script>\
'); 