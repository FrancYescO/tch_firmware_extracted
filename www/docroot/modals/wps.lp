--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')
local session = ngx.ctx.session
local proxy = require("datamodel")
local ngx, format, untaint = ngx, string.format, string.untaint
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")

--[[
  Bart said we need to trigger both 2.4 and 5 Ghz at same time  instead of doing it seprately. rpc.wireless.ap.@apx.wps.enrollee_pbc  will trigger accesspoints seprately. For that we used "rpc.wireless.wps_button" to trigger both
]]

local wpsParams = {
  wps24State = "uci.wireless.wifi-ap.@ap0.wps_state",
  wps5State  = "uci.wireless.wifi-ap.@ap1.wps_state",
  wpsButton = "uci.button.button.@wps.state",
}

local wpsValidations = {
  wps24State = post_helper.validateBoolean,
  wps5State =  post_helper.validateBoolean,
  wpsButton = post_helper.validateBoolean,
}

local wpsInfo, wpsMsg = post_helper.handleQuery(wpsParams, wpsValidations)
local resetwps = {
  reset_wps_btn_status = "uci.uci-defaults.wps.wps_function_enable",
  reset_wps_btn_hardbutton = "uci.uci-defaults.wps.wps_button_enable"
}
content_helper.getExactContent(resetwps)
local msgClass = ""

if proxy.get("rpc.wireless.radio.@radio_5G.oper_state")[1].value == "1" and proxy.get("rpc.wireless.radio.@radio_2G.oper_state")[1].value == "1" then
  msgClass = "hide"
end

if ngx.req.get_method() == "GET" and ngx.req.get_uri_args().wpsstatus == "true" then
  local sessionState = {
    lastSessionState24 = "rpc.wireless.ap.@ap0.wps.last_session_state",
    lastSessionState5 = "rpc.wireless.ap.@ap1.wps.last_session_state",
  }content_helper.getExactContent(sessionState)

  local status24 = sessionState and untaint(sessionState.lastSessionState24)
  local status5 = sessionState and untaint(sessionState.lastSessionState5)
  ngx.header.content_type = "application/json"
  ngx.print('{"status24":"' ..status24.. '","status5":"'..status5..'"}')
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "POST" then
  if ngx.req.get_post_args().startwps == "1" then
    local wpsPush = {["rpc.wireless.wps_button"] = "1"}
    if proxy.set(wpsPush) then
      proxy.apply()
    end
    ngx.exit(ngx.HTTP_OK)
  end

  if not next(wpsMsg) then
    ngx.print('<input type="hidden" id="post_status" value="success">')
  else
    ngx.print('<input type="hidden" id="post_status" value="error">')
  end
  if ngx.req.get_post_args().stopwps == "1" then
    local wpsStop = {
      ["rpc.wireless.ap.@ap1.wps.enrollee_pbc"] = "0",
      ["rpc.wireless.ap.@ap0.wps.enrollee_pbc"] = "0",
    }
    if proxy.set(wpsStop) then
      proxy.apply()
    end
    ngx.exit(ngx.HTTP_OK)
  end
end
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")

  ngx.print('\
<script src="js/global.js">\
</script>\
<script>\
  $(function () {\
    $(\'select\').chosen({\
      disable_search_threshold: 100000,\
      allow_single_deselect: true\
    });\
  });\
</script>\
<h1>');  ngx.print(T"WPS"); ngx.print('</h1>\
<h2>');  ngx.print(T"The WPS functions help you securely pair your WiFi devices automatically with the router. You can choose and configure the allowed security mechanisms below."); ngx.print(' </h2>\
  <form id="wps_form" class="form-horizontal" method="post" action="modals/wps.lp">\
    <input type="hidden" name="CSRFtoken" value ="');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('"></input>\
    <input type="hidden" name="action" value ="SAVE"></input>\
  <div class="row padding-top-bottom-20 wps-message ');  ngx.print(msgClass); ngx.print('">\
    <div class="col-md-12">\
      <div class="message message-info message-error not-8-characterss mobile-margin-left-right-15" style="display: block;">\
        ');  ngx.print(T"Your Wi-Fi is currently disabled, therefore these options are inactive. Changes can be still be made and will take effect when Wi-Fi is re-enabled. To enable the Wi-Fi, enable it on the General Page." ); ngx.print('\
      </div>\
    </div>\
  </div>\
<div class="h3-content no-padding-bottom diagnostic-table">\
    <div class="vdf-row">\
        <div class="left">\
            <span>');  ngx.print(T"WPS Function"); ngx.print('</span>\
        </div>\
        <div class="right">\
            <input type="hidden" name="wps24State" value ="');  ngx.print(wpsInfo["wps24State"]); ngx.print('" class="wps-txt-status" ></input>\
            <input type="hidden" name="wps5State" value ="');  ngx.print(wpsInfo["wps5State"]); ngx.print('" class="wps-txt-status" ></input>\
            <div id="wps-btn-status" class="button ');  if wpsInfo["wps24State"] == "1" and  wpsInfo["wps5State"] == "1" then    ngx.print(' button-on ');  else   ngx.print(' button-off ');  end  ngx.print(' pin-enable"></div>\
        </div>\
    </div>\
</div>\
<div class="level-3 wpsOnOff shadowProblem">\
  <div id = "wps-div-hide" class = "show">\
    <h3><span>');  ngx.print(T"WPS-PBC: Push button on devices"); ngx.print('</span></h3>\
    <div class="h3-content no-padding-bottom">\
        <div class=" vdf-row description">\
            <div class="left ">\
                <span class="font-normal lineheight20 ">');  ngx.print(T"To pair your devices press Pair on this page and then on your other device"); ngx.print('&#40;');  ngx.print("s"); ngx.print('&#41;');  ngx.print(T". Your router will be open for pairing for 2 minutes after you press Pair."); ngx.print('\
                </span>\
            </div>\
        </div>\
    </div>\
\
    <div class="h3-content vdf-table mobile-no-table padding-bottom-50">\
        <div class="vdf-row with-float">\
            <div class="left">\
                <span>');  ngx.print(T"Pressing the WPS button on your Vodafone Ultra Hub for more than 1 second activates WPS pairing"); ngx.print('</span>\
            </div>\
            <div class="right">\
               <input type="hidden" name="wpsButton" value ="');  ngx.print(wpsInfo["wpsButton"]); ngx.print('" class="wps-txt-hardbutton" ></input>\
               <div id="wps-btn-hardbutton" class="button ');  if wpsInfo["wpsButton"] ~= "0" then    ngx.print(' button-on ');  else   ngx.print(' button-off ');  end  ngx.print(' pin-enable "></div>\
            </div>\
        </div>\
        <div class="vdf-row display-block">\
            <div class="left padding-bottom-mobile-10 display-block">\
                <span class="">');  ngx.print(T"Pair (within 2 minutes)"); ngx.print('</span>            </div>\
            <div class="right mobile-border-kill mobile-no-padding-top display-block">\
                <input id="wps-btn-pair" class="button button-blank button-mediumwidth pair1 mob-button-width " type="button" value="');  ngx.print(T"Pair"); ngx.print('">\
            </div>\
        </div>\
    </div>\
  </div>\
</div>\
  </form>\
');  
    lp.include("apply-cancel.lp")
    lp.include("reset-wrap-mobile.lp")
  ngx.print('\
\
<!--Below Popup section commented out, currently we dont have support in lower layer to show status of WPS Page   -->\
<!-- End  -->\
<!-- Popup1 -->\
<div class="row">\
  <!--Modal -->\
  <div class="modal install-update-popup-1" id="install-update-popup-1" role="dialog" data-backdrop="static" data-keyboard="false">\
    <div class="modal-dialog">\
     <!-- Modal content  -->\
      <div class="modal-content">\
        <div class="modal-header hidden-sm hidden-md hidden-lg">\
           <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
        </div>\
        <div class="modal-body no-padding">\
          <img src="/img/look_4/icons/icon-thinking.gif" alt="Loading..." class="padding-top-bottom-20" />\
          <h3 class="padding-bottom-20" style="padding-left:0px;">');  ngx.print(T"Attempting to Pair"); ngx.print('</h3>\
          <p class="padding-bottom-20">\
            <span>');  ngx.print(T"Your Vodafone Ultra Hub is now attempting to pair with other devices."); ngx.print('\
            </span>\
          </p>\
          <p class="padding-top-bottom-20">\
            <span id="demo"></span>\
            <span>');  ngx.print(T"seconds remaining."); ngx.print('\
            </span>\
          </p>\
        </div>\
        <div class="modal-footer">\
          <input class="button button-cancel clear-interval" value=');  ngx.print(T"Cancel"); ngx.print(' type="button" data-dismiss="modal"  id = "wps-btn-cancelpair"/>\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
<!--Popup2 -->\
<div class="row">\
   <!--Modal -->\
  <div class="modal install-update-popup-2" id="install-update-popup-2" role="dialog" data-backdrop="static" data-keyboard="false">\
    <div class="modal-dialog">\
      <!--Modal content-->\
      <div class="modal-content">\
        <div class="modal-header hidden-sm hidden-md hidden-lg">\
           <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
        </div>\
        <div class="modal-body no-padding">\
          <h3 class="padding-bottom-20" style="padding-left:0px;">');  ngx.print(T"Pairing Timed out"); ngx.print('</h3>\
          <p class="padding-bottom-20">\
            <span>');  ngx.print(T"No devices have connected to your Vodafone Ultra Hub. If you still want to pair a device, click the Pair button again."); ngx.print('\
            </span>\
          </p>\
        </div>\
        <div class="modal-footer">\
          <input id="button-ok-timeout" class="button button-cancel clear-interval" value=');  ngx.print(T"OK"); ngx.print(' type="button" data-dismiss="modal">\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
<!--Popup3-->\
<div class="row">\
  <!--Modal-->\
  <div class="modal install-update-popup-3" id="install-update-popup-3" role="dialog" data-backdrop="static" data-keyboard="false">\
    <div class="modal-dialog">\
       <!--Modal content-->\
      <div class="modal-content">\
        <div class="modal-header hidden-sm hidden-md hidden-lg">\
          <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
        </div>\
        <div class="modal-body no-padding">\
          <h3 class="padding-bottom-20"  style="padding-left:0px;">');  ngx.print(T"Pairing Successful"); ngx.print('</h3>\
          <p class="padding-bottom-20">\
            <span>');  ngx.print(T"Your Vodafone Ultra Hub has successfully paired with another device."); ngx.print('\
            </span>\
          </p>\
        </div>\
        <div class="modal-footer">\
          <input id="button-ok-pair-success" class="button button-cancel clear-interval" value=');  ngx.print(T"OK"); ngx.print(' type="button" data-dismiss="modal" />\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
\
<!--Popup4\
<div class="row">\
  <div class="modal install-update-popup-4" id="install-update-popup-4" role="dialog">\
    <div class="modal-dialog">\
      <div class="modal-content">\
        <div class="modal-header hidden-sm hidden-md hidden-lg">\
           <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div> \
        </div>\
        <div class="modal-body no-padding">\
          <p class="padding-bottom-20">\
            <span>');  ngx.print(T"Are you sure you want to cancel the changes?"); ngx.print('\
            </span>\
          </p>\
        </div>\
        <div class="modal-footer">\
          <input id="button-ok-wps" class="button button-cancel" value="OK" type="button" data-dismiss="modal" />\
          <input id="button-cancel-wps" class="button button-cancel" value="cancel" type="button" data-dismiss="modal" />\
        </div>\
      </div>\
    </div>\
  </div>\
</div> -->\
<script>\
  $(function()\
    {\
    if ($("#wps-btn-status").hasClass("button-on")){\
      $("#wps-div-hide").removeClass("hide").addClass("show");\
    }else{\
       $("#wps-div-hide").removeClass("show").addClass("hide");\
    }\
    $("#wps-btn-status").click(function(){\
       if ($("#wps-btn-status").hasClass("button-on")){\
         $("#wps-div-hide").removeClass("hide").addClass("show");\
         $("#wps-txt-status").val("1");\
       }\
       else{\
         $("#wps-div-hide").removeClass("show").addClass("hide");\
         $("#wps-txt-status").val("0");\
       }\
    });\
\
    $("#wps-btn-pair").click(function(){\
      var params = [];\
      params.push({\
        name : "startwps",\
        value : "1"\
      },{\
        name : "CSRFtoken",\
        value : "');  ngx.print( ngx.ctx.session:getCSRFtoken()); ngx.print('"\
      });\
      $.post($("#wps_form").attr("action"),params);\
       $(\'#install-update-popup-1\').modal();\
        var totalSeconds = 120, start = 1;\
        var interval = setInterval(function() {\
        var reminingSeconds = totalSeconds - start;\
        if (reminingSeconds > 0){\
          document.getElementById(\'demo\').innerHTML = reminingSeconds;\
          start++;\
        }else{\
          document.getElementById(\'demo\').innerHTML = "0";\
        }\
        },1000);\
       var requestinterval = setInterval(function(){\
        $.get("/modals/wps.lp?wpsstatus=true",function(responseTxt, statusTxt, xhr){\
          if (responseTxt.status24 == "success" || responseTxt.status5 =="success" ){\
            $(\'#install-update-popup-1\').modal(\'hide\');\
            clearInterval(requestinterval);\
            clearInterval(interval);\
            $(\'#install-update-popup-3\').modal();\
          }else if ((responseTxt.status24 != "success" && responseTxt.status24 != "inprogress" ) && ( responseTxt.status5 != "success" &&responseTxt.status5 != "inprogress" )){\
            $(\'#install-update-popup-1\').modal(\'hide\');\
            clearInterval(requestinterval);\
            clearInterval(interval);\
            $(\'#install-update-popup-2\').modal();\
          }\
       });\
      },3000);\
       $("#wps-btn-cancelpair").click(function(){\
          document.getElementById(\'demo\').innerHTML = "";\
          clearInterval(interval);\
          clearInterval(requestinterval);\
      });\
       setTimeout(function(){clearInterval(requestinterval);},180000);\
    });\
     $("#global-apply").click(function(){\
        if ($("#wps-btn-status").hasClass("button-on")){\
          $(".wps-txt-status").val("1");\
        }else{\
          $(".wps-txt-status").val("0");\
        }\
        if ($("#wps-btn-hardbutton").hasClass("button-on")){\
          $(".wps-txt-hardbutton").val("1");\
        }else{\
          $(".wps-txt-hardbutton").val("0");\
        }\
        postHandler($("#wps_form").attr("action"),$("#wps_form").serializeArray());\
      });\
    $("#button-ok-timeout").click(function(){\
      $(\'#install-update-popup-2\').modal(\'hide\');\
    });\
    $("#button-ok-pair-success").click(function(){\
      $(\'#install-update-popup-3\').modal(\'hide\');\
    });\
    $("#wps-btn-cancelpair").click(function(){\
      var params = [];\
      params.push({\
        name : "stopwps",\
        value : "1"\
      },{\
        name : "CSRFtoken",\
        value : "');  ngx.print( ngx.ctx.session:getCSRFtoken()); ngx.print('"\
      });\
      $.post($("#wps_form").attr("action"),params)\
    });\
    $("#global-cancel").click(function(){\
      $("#content").load("/modals/wps.lp");\
    });\
});\
\
$("#resetR, .resetR").click(function(){\
\
function changeButton(id, value, hiddenClass, hiddenField) {\
    $(id).val(value);\
    if (value == "1") {\
      $(id).addClass(\'button-on\').removeClass(\'button-off\');\
      $(hiddenClass).val("1");\
      $(hiddenField).removeClass("hide").addClass("show");\
    } else {\
      $(id).addClass(\'button-off\').removeClass(\'button-on\');\
      $(hiddenClass).val("0");\
      $(hiddenField).removeClass("show").addClass("hide");\
    }\
  }\
\
changeButton("#wps-btn-status", ');  ngx.print(resetwps["reset_wps_btn_status"]); ngx.print(', ".wps-txt-status", "#wps-div-hide");\
changeButton("#wps-btn-hardbutton", ');  ngx.print(resetwps["reset_wps_btn_hardbutton"]); ngx.print(', ".wps-txt-hardbutton");\
});\
\
</script>\
'); 