--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')
local ngx = ngx
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("vdf_ui_helper")
local vdf_helper = require("vodafone_helper")
local json = require("dkjson")

local vodafone = {
    variant = "uci.env.var.vodafone_variant",
}
content_helper.getExactContent(vodafone)
local gatewayName, fiberName = vdf_helper.productName(), "Fiber connection"
if vodafone.variant == "NZ" then
    gatewayName, fiberName = gatewayName:gsub("Vodafone", ""), "Fibre connection"
elseif vodafone.variant == "VF-UK" then
    fiberName = "Fibre connection"
end

if ngx.req.get_method() == "GET" then
  if ngx.req.get_uri_args().getstatus == "true" then
    ngx.header.content_type = "application/json"
    ngx.print('{ "status":"progress" }')
    ngx.exit(ngx.HTTP_OK)
  end
  if ngx.req.get_uri_args().getInterfaceValues == "true" then
    interfacedata = {
      wanip  = "rpc.network.interface.@wan.ipaddr",
      dslstatus = "sys.class.xdsl.@line0.Status",
      ethstatus = "sys.class.net.@eth4.operstate",
    }
    content_helper.getExactContent(interfacedata)
    ngx.header.content_type = "application/json"
    ngx.print(json.encode(interfacedata))
    ngx.exit(ngx.HTTP_OK)
  end
end

if ngx.req.get_method() == "POST" then
  local wanStatus = proxy.get("uci.wansensing.state.wanSyncStatus")[1].value
  local setparam
  if ngx.req.get_post_args().reset_dsl == "1" and (wanStatus == "ADSL" or wanStatus == "VDSL" or wanStatus == "GFAST") then
    setparam ={["uci.xdsl.xdsl.@dsl0.enabled"] = "1"}
  elseif ngx.req.get_post_args().reset_ethwan == "1" and wanStatus == "ETH" then
    setparam ={["sys.eth.port.@eth4.reconnect"] = "1"}
  elseif ngx.req.get_post_args().system_reboot == "GUI" then
    setparam ={["rpc.system.reboot"] = "GUI"}
  end
  local success = proxy.set(setparam)
  if success then
    proxy.apply()
  end
  ngx.exit(ngx.HTTP_OK)
end

  ngx.print('\
<h1>');  ngx.print(T"Restart"); ngx.print('</h1>\
<h2><span class="mobile-padding-right-2">\
  ');  ngx.print(T"This page allows to restart your DSL connection and reboot your Vodafone "); ngx.print('\
  ');  if vodafone.variant ~= "VF-UK" then  ngx.print('\
    ');  ngx.print(gatewayName); ngx.print('\
  ');  end  ngx.print('\
  ');  ngx.print(T". Please note that for the entire process all phone, internet and TV services will be temporarily unavailable."); ngx.print('</span></h2>\
<h3>');  ngx.print(T"DSL Connection"); ngx.print('</h3>\
<div class="h3-content h3-content-mobile  padding-bottom-lg">\
  <form id="restart-form" class="form-horizontal" method="post" action="modals/status-support/restart.lp">\
    ');  
      local row = {
        label = ui_helper.createOnlyText({
          id = "restart-lbl-dsl_ipaddress",
          class="mobile-font-bold"
          }),
        element = ui_helper.createOnlyText({
          id = "restart-lbl-dsl_status",
          class="mobile-font-bold"
          }),
        rowClass = "row no-margin-left-right",
        colLeftClass = "col-xs-12 col-sm-6 col-md-6 no-padding-left-right padding-top-bottom-20 restart-text-left mobile-padding-top-none mobile-padding-bottom-10",
        colRightClass = "col-xs-12 col-sm-6 col-md-6 no-padding-left-right padding-top-bottom-20 restart-text-right no-padding-right mobile-padding-top-none mobile-padding-bottom-20",
      }
      ngx.print(ui_helper.createRow(row))

      row = {
        label = ui_helper.createClickButton({
          id="restart-btn-reconnect_dsl",
          class="button button-blank mob-button-width reconnect-btn",
          value=T"Reconnect",
          type="button",
          ["data-toggle"]="modal"
          }),
        rowClass = "row no-margin-left-right",
        colClass = "col-xs-12 col-sm-12 col-md-12 text-right padding-top-bottom-20 no-padding-left-right mobile-padding-top-none mobile-padding-bottom-20"
      }
      ngx.print(ui_helper.createSingleRow(row))
      ngx.print('\
  </form>\
</div>\
\
<h3>');  ngx.print(T(fiberName)); ngx.print('</h3>\
<div class="h3-content h3-content-mobile  padding-bottom-lg">\
  ');  
    row = {
      label = ui_helper.createOnlyText({
        id="restart-lbl-eth_ipaddress",
        class="mobile-font-bold"
        }),
      element = ui_helper.createOnlyText({
        id="restart-lbl-eth_status",
        class="mobile-font-bold"
        }),
      rowClass = "row no-margin-left-right",
      colLeftClass = "col-xs-12 col-sm-6 col-md-6 no-padding-left-right padding-top-bottom-20 restart-text-left mobile-padding-top-none mobile-padding-bottom-10",
      colRightClass = "col-xs-12 col-sm-6 col-md-6 no-padding-left-right padding-top-bottom-20 restart-text-right no-padding-right mobile-padding-top-none mobile-padding-bottom-20",
    }
    ngx.print(ui_helper.createRow(row))

    row = {
      label = ui_helper.createClickButton({
        id="restart-btn-reconnect_eth",
        class="button button-blank mob-button-width reconnect-btn",
        value=T"Reconnect",
        type="button",
        ["data-toggle"]="modal"
        }),
      rowClass = "row no-margin-left-right",
      colClass = "col-xs-12 col-sm-12 col-md-12 text-right padding-top-bottom-20 no-padding-left-right mobile-padding-top-none mobile-padding-bottom-20"
    }
    ngx.print(ui_helper.createSingleRow(row))
    ngx.print('\
</div>\
\
');  if vodafone.variant ~= "VF-UK" then  ngx.print('\
  <h3>');  ngx.print(T("Vodafone " .. gatewayName)); ngx.print('</h3>\
  ');  
    row = {
      {
        label = T("Click here to restart your Vodafone " .. gatewayName),
        element = ui_helper.createClickButton({
          class="button button-blank mob-button-width restart-btn",
            value=T"Restart",
          id="restart-btn-restart_dut",
          type="button",
          ["data-toggle"]="modal",
          ["data-target"]="#restart-modal"
          }),
        rowClass = "row no-margin-left-right",
        colLeftClass = "col-xs-12 col-sm-7 col-md-7 no-padding-left-right padding-top-bottom-20 restart-text-leftm restart-line-height-34 mobile-padding-bottom-none mobile-padding-top-10",
        labelClass = "mobile-font-bold",
        colRightClass = "col-xs-12 col-sm-5 col-md-5 no-padding-left-right padding-top-bottom-20 restart-text-right mobile-padding-bottom-none mobile-padding-top-10"
      }
    }
    ngx.print(ui_helper.createTable(row, "", "h3-content h3-content-mobile margin-bottom-60"))
    ngx.print('\
');  end  ngx.print('\
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
                ');  ngx.print(T("Are you sure you want to restart your Vodafone " .. gatewayName .."?")); ngx.print('\
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
              <p class="padding-top-bottom-20"><span>');  ngx.print(T"Do not turn off your " ..gatewayName.. "."); ngx.print('</span></p>\
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
         <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group no-margin-bottom">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T("Are you sure you want to restart your " .. fiberName .. "?")); ngx.print('\
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
  $.get("/modals/status-support/restart.lp", {"getInterfaceValues" : "true"}, function(responseTxt) {\
    $("#restart-lbl-dsl_ipaddress").text(responseTxt.dslstatus === "Up" && responseTxt.wanip ? responseTxt.wanip : "No IP available");\
    $("#restart-lbl-dsl_status").text(responseTxt.dslstatus === "Up" ? "active" : "Inactive");\
    $("#restart-lbl-eth_ipaddress").text(responseTxt.ethstatus === "up" && responseTxt.wanip ? responseTxt.wanip : "No IP available");\
    $("#restart-lbl-eth_status").text(responseTxt.ethstatus === "up" ? "active" : "Inactive");\
  });\
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
      getInterfaceValues("/modals/status-support/restart.lp?getInterfaceValues=true", params);\
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
      getInterfaceValues("/modals/status-support/restart.lp?getInterfaceValues=true", params);\
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
     getStatus("/modals/status-support/restart.lp?getstatus=true");\
    });\
  });\
\
  function getInterfaceValues(target, params) {\
    $.get(target, function(responseTxt, statusTxt, xhr){\
      if (params[0].name == "reset_dsl") {\
        if (responseTxt.dslstatus != "Up") {\
          window.setTimeout(function() {\
            getInterfaceValues("/modals/status-support/restart.lp?getInterfaceValues=true", params);\
          },10000);\
          $("#restart-lbl-dsl_ipaddress").text(responseTxt.dslstatus === "Up" && responseTxt.wanip ? responseTxt.wanip : "No IP available");\
          $("#restart-lbl-dsl_status").text(responseTxt.dslstatus === "Up" ? "active" : "Inactive");\
        }\
        else if (!responseTxt.wanip) {\
          window.setTimeout(function() {\
            getInterfaceValues("/modals/status-support/restart.lp?getInterfaceValues=true", params);\
          },5000);\
        }\
        else {\
          $("#restart-lbl-dsl_ipaddress").text(responseTxt.dslstatus === "Up" && responseTxt.wanip ? responseTxt.wanip : "No IP available");\
          $("#restart-lbl-dsl_status").text(responseTxt.dslstatus === "Up" ? "active" : "Inactive");\
          return;\
        }\
      }\
      else if (params[0].name == "reset_ethwan") {\
        if (responseTxt.ethstatus != "up") {\
          window.setTimeout(function() {\
            getInterfaceValues("/modals/status-support/restart.lp?getInterfaceValues=true", params);\
          },10000);\
          $("#restart-lbl-eth_ipaddress").text(responseTxt.ethstatus === "up" && responseTxt.wanip ? responseTxt.wanip : "No IP available");\
          $("#restart-lbl-eth_status").text(responseTxt.ethstatus === "up" ? "active" : "Inactive");\
        }\
        else if (!responseTxt.wanip) {\
          window.setTimeout(function() {\
            getInterfaceValues("/modals/status-support/restart.lp?getInterfaceValues=true", params);\
          },5000);\
        }\
        else {\
          $("#restart-lbl-eth_ipaddress").text(responseTxt.ethstatus === "up" && responseTxt.wanip ? responseTxt.wanip : "No IP available");\
          $("#restart-lbl-eth_status").text(responseTxt.ethstatus === "up" ? "active" : "Inactive");\
          return;\
        }\
      }\
     });\
  }\
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
        getStatus("/modals/status-support/restart.lp?getstatus=true");\
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