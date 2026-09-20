--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')
local ngx = ngx
local proxy = require("datamodel")
local content_helper = require("web.content_helper")

if ngx.req.get_method() == "GET" then
  if ngx.req.get_uri_args().getstatus == "true" then
    ngx.header.content_type = "application/json"
    ngx.print('{ "status":"progress" }')
    ngx.exit(ngx.HTTP_OK)
  end
end

if ngx.req.get_method() == "POST" then
  local setparam
  if ngx.req.get_post_args().reset_dsl == "1" then
    setparam ={["uci.xdsl.xdsl.@dsl0.enabled"] = "1"}
  elseif ngx.req.get_post_args().reset_ethwan == "1" then
    setparam ={["uci.ethernet.port.@eth4.enable"] = "1"}
  elseif ngx.req.get_post_args().system_reboot == "GUI" then
    setparam ={["rpc.system.reboot"] = "GUI"}
  end
  local success = proxy.set(setparam)
  if success then
    proxy.apply()
  end
  ngx.exit(ngx.HTTP_OK)
end

local interfacedata = {
  wanip  = "rpc.network.interface.@wan.ipaddr",
  dslstatus = "sys.class.xdsl.@line0.Status",
  ethstatus = "sys.class.net.@eth4.operstate",
}

content_helper.getExactContent(interfacedata)
  ngx.print('\
<h1>');  ngx.print(T"Restart"); ngx.print('</h1>\
<h2><span class="padding-right mobile-padding-right-2">');  ngx.print(T"This page allows to restart your DSL connection and reboot your Vodafone Ultra Hub. Please note that for the entire process all phone, internet and TV services will be temporarily unavailable."); ngx.print('</span></h2>\
\
\
    <h3>');  ngx.print(T"DSL Connection"); ngx.print('</h3>\
\
<div class="h3-content h3-content-mobile">\
  <form id="restart-form" class="form-horizontal" method="post" action="modals/restart.lp">\
  <div class="row no-margin-left-right">\
    <div class="col-xs-12 col-sm-6 col-md-6 no-padding-left-right padding-top-bottom-20 restart-text-left mobile-padding-top-none mobile-padding-bottom-10">\
      <span id = "restart-lbl-dsl_ipaddress" class="mobile-font-bold">\
      ');  if interfacedata["dslstatus"] and interfacedata["dslstatus"] == "Up" and interfacedata["wanip"] ~= "" then  ngx.print('\
        ');  ngx.print(interfacedata["wanip"]); ngx.print('\
      ');  else  ngx.print('\
        ');  ngx.print(T"No IP available"); ngx.print('\
      ');  end  ngx.print('\
      </span>\
    </div>\
    <div class="col-xs-12 col-sm-6 col-md-6 no-padding-left-right padding-top-bottom-20 restart-text-right no-padding-right mobile-padding-top-none mobile-padding-bottom-20">\
      <span id = "restart-lbl-dsl_status" class="mobile-font-bold">\
      ');  if interfacedata["dslstatus"] and interfacedata["dslstatus"] == "Up" then  ngx.print('\
        ');  ngx.print(T"Active"); ngx.print('\
      ');  else  ngx.print('\
        ');  ngx.print(T"Inactive"); ngx.print('\
      ');  end  ngx.print('\
      </span>\
    </div>\
  </div>\
  <div class="row no-margin-left-right">\
    <div class="col-xs-12 col-sm-12 col-md-12 text-right padding-top-bottom-20 no-padding-left-right mobile-padding-top-none mobile-padding-bottom-20">\
      <input id="restart-btn-reconnect_dsl" class="button button-blank mob-button-width reconnect-btn" value="');  ngx.print(T"Reconnect"); ngx.print('" type="button" data-toggle="modal" />\
    </div>\
  </div>\
  </form>\
</div>\
\
    <h3>');  ngx.print(T"Fibre connection"); ngx.print('</h3>\
<div class="h3-content h3-content-mobile">\
  <div class="row no-margin-left-right">\
    <div class="col-xs-12 col-sm-6 col-md-6 no-padding-left-right padding-top-bottom-20 restart-text-left mobile-padding-top-none mobile-padding-bottom-10">\
      <span id="restart-lbl-eth_ipaddress" class="mobile-font-bold">\
      ');  if interfacedata["ethstatus"] and interfacedata["ethstatus"] == "up" and interfacedata["wanip"] ~= "" then  ngx.print('\
        ');  ngx.print(interfacedata["wanip"]); ngx.print('\
      ');  else  ngx.print('\
        ');  ngx.print(T"No IP available"); ngx.print('\
      ');  end  ngx.print('\
      </span>\
    </div>\
    <div class="col-xs-12 col-sm-6 col-md-6 no-padding-left-right padding-top-bottom-20 restart-text-right mobile-padding-top-none mobile-padding-bottom-20">\
      <span id="restart-lbl-eth_status" class="mobile-font-bold">\
      ');  if interfacedata["ethstatus"] and interfacedata["ethstatus"] == "up" then  ngx.print('\
        ');  ngx.print(T"Active"); ngx.print('</span>\
      ');  else  ngx.print('\
        ');  ngx.print(T"Inactive"); ngx.print('\
      ');  end  ngx.print('\
      </span>\
    </div>\
  </div>\
  <div class="row no-margin-left-right">\
    <div class="col-xs-12 col-sm-12 col-md-12 text-right no-padding-left-right padding-top-bottom-20 mobile-padding-top-none mobile-padding-bottom-20">\
      <input id="restart-btn-reconnect_eth" class="button button-blank mob-button-width reconnect-btn" value="');  ngx.print(T"Reconnect"); ngx.print('" type="button" data-toggle="modal" />\
    </div>\
  </div>\
</div>\
\
    <h3>');  ngx.print(T"Vodafone Ultra Hub"); ngx.print('</h3>\
<div class="h3-content h3-content-mobile margin-bottom-60">\
  <div class="row no-margin-left-right">\
    <div class="col-xs-12 col-sm-7 col-md-7 no-padding-left-right padding-top-bottom-20 restart-text-leftm restart-line-height-34 mobile-padding-bottom-none mobile-padding-top-10">\
      <span class="mobile-font-bold">');  ngx.print(T"Click here to restart your Vodafone Ultra Hub"); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-sm-5 col-md-5 no-padding-left-right padding-top-bottom-20 restart-text-right mobile-padding-bottom-none mobile-padding-top-10">\
      <input class="button button-blank mob-button-width restart-btn" value="');  ngx.print(T"Restart"); ngx.print('" id="restart-btn-restart_dut" type="button" data-toggle="modal" data-target="#restart-modal" />\
    </div>\
  </div>\
</div>\
\
<!-- Modal -->\
<div class="modal fade" id="restart-modal" data-backdrop="static" data-keyboard="false" role="dialog">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group no-margin-bottom">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T"Are you sure you want to restart your Vodafone Ultra Hub?"); ngx.print('\
              </p>\
            </div>\
          </div>\
          <div class="form-group no-margin-bottom">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input value="');  ngx.print(T"Apply"); ngx.print('" class="button button-apply mob-button-width" id="restart-btn-apply" type="button" />\
                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" id="restart-btn-cancel" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" />\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
<!-- End -->\
\
<!-- Modal -->\
<div class="modal fade" id="restart-inprogress-modal" data-backdrop="static" data-keyboard="false" role="dialog">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group">\
            <div class="col-sm-12">\
			  <p class="title">');  ngx.print(T"Restarting in Progress"); ngx.print('</p>\
              <p class="padding-top-bottom-20"><span>');  ngx.print(T"Do not turn off your Vodafone Ultra Hub."); ngx.print('</span></p>\
			   <div class="progress">\
				  <div class="progress-bar progress-bar-striped active" role="progressbar"\
				  aria-valuenow="" aria-valuemin="0" aria-valuemax="100" style="width:100%; background-color: #a8b400;">\
				  </div>\
				</div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
<!-- End -->\
<!-- Modal -->\
<div class="modal fade" id="restart-dsl-modal" data-backdrop="static" data-keyboard="false" role="dialog">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group no-margin-bottom">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T"Are you sure you want to restart your DSL connection?"); ngx.print('\
              </p>\
            </div>\
          </div>\
          <div class="form-group no-margin-bottom">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input value="');  ngx.print(T"Apply"); ngx.print('" class="button button-apply mob-button-width" id="restart-dsl-btn-apply" type="button" data-dismiss="modal" />\
                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" id="restart-dsl-btn-cancel" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" />\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
<!-- End -->\
<!-- Modal -->\
<div class="modal fade" id="restart-ethernet-modal" data-backdrop="static" data-keyboard="false" role="dialog">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
         <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div> \
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group no-margin-bottom">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T"Are you sure you want to restart your Fibre connection?"); ngx.print('\
              </p>\
            </div>\
          </div>\
          <div class="form-group no-margin-bottom">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input value="');  ngx.print(T"Apply"); ngx.print('" class="button button-apply mob-button-width" id="restart-ethernet-btn-apply" type="button" data-dismiss="modal" />\
                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" id="restart-ethernet-btn-cancel" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" />\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
<!-- End -->\
<script>\
  var isDone = false;\
  $(function()\
  {\
    $("#restart-btn-reconnect_dsl").click(function() {\
      $(\'#restart-dsl-modal\').modal();\
    });\
    $("#restart-dsl-btn-apply").click(function(){\
      var params = [];\
      params.push({\
        name : "reset_dsl",\
        value : "1"\
      },{\
        name : "CSRFtoken",\
        value : "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('"\
      });\
      $.post($("#restart-form").attr("action"),params);\
    });\
    $("#restart-btn-reconnect_eth").click(function() {\
     $(\'#restart-ethernet-modal\').modal();\
    });\
    $("#restart-ethernet-btn-apply").click(function(){\
      var params = [];\
      params.push({\
        name : "reset_ethwan",\
        value : "1"\
      },{\
        name : "CSRFtoken",\
        value : "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('"\
      });\
      $.post($("#restart-form").attr("action"),params);\
    });\
    $("#restart-btn-apply").click(function() {\
      $(\'#restart-modal\').modal(\'hide\');\
      $(\'#restart-inprogress-modal\').modal();\
      var params = [];\
      params.push({\
        name : "system_reboot",\
        value : "GUI"\
      },{\
        name : "CSRFtoken",\
        value : "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('"\
      });\
      $.post($("#restart-form").attr("action"),params);\
     getStatus("/modals/restart.lp?getstatus=true");\
    });\
  });\
\
  function getStatus(target) {\
    $.get(target, function(responseTxt, statusTxt, xhr){\
      if ( isDone || !(responseTxt.status) ) {\
        window.setTimeout(function() {\
        $( ".progress-bar progress-bar-striped active" ).remove();\
        window.location = "/";\
        },5000);\
        return;\
      }\
      else {\
        window.setTimeout(function() {\
        getStatus("/modals/restart.lp?getstatus=true");\
        }, 5000);\
      }\
    }).fail(function(data) {\
      isDone = true;\
      window.setTimeout(function(){\
      getStatus("/")}, 5000);\
    });\
  }\
</script>\
'); 