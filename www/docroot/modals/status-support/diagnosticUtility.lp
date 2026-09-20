--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local rIP = post_helper.reservedIPValidation
local gAndVal = post_helper.getAndValidation
local gOrVal = post_helper.getOrValidation
local validateHost = gOrVal(gAndVal(post_helper.validateStringIsIP, rIP), post_helper.validateStringIsDomainName)
local json = require("dkjson")
local next, string = next, string
local format, untaint, match = string.format, string.untaint, string.match
local traceroutePaths = {}
local ui_helper = require("vdf_ui_helper")
local vdf_helper = require("vodafone_helper")
local path_tcpdump = format("rpc.system.tcpdump.")
local vdf_helper = require("vodafone_helper")

local variant = vdf_helper.getVariant()
local gatewayName = vdf_helper.productName()

local wanStatus = {
  wan_ip = "rpc.network.interface.@wan.ipaddr",
  wwan_up = "rpc.network.interface.@wwan.up",
}
content_helper.getExactContent(wanStatus)

local content_line2 = {
  hookstate = "rpc.mmpbx.device.@fxs_dev_1.hookstate",
}
content_helper.getExactContent(content_line2)

local connectivityTestPaths = {
  "rpc.network.interface.@wan.default_gateway_ping",
  "rpc.network.interface.@wan.dnsserver1_ping",
  "rpc.network.interface.@wan.dnsserver2_ping",
}

if variant == "NZ" and wanStatus.wan_ip == "" and wanStatus.wwan_up == "1" then
  connectivityTestPaths = {
    "rpc.network.interface.@wwan.default_gateway_ping",
    "rpc.network.interface.@wwan.dnsserver1_ping",
    "rpc.network.interface.@wwan.dnsserver2_ping",
 }
end

local connectionTypes = {
  {"WANData", T"WAN/Data"},
  {"LANMain", T"LAN/Main"},
  {"LANGuest", T"LAN/Guest"},
  {"Mobile", T"Mobile"},
  {"ANY", T"ANY"}
}

if ngx.req.get_method() == "GET" and ngx.req.get_uri_args().action == "tracing" then
  local tracingStatus = proxy.get("rpc.packetcapture.status")
  tracingStatus = tracingStatus and tracingStatus[1] and  tracingStatus[1].value or ""
  ngx.header.content_type = "application/json"
  ngx.print('{"status":"'.. string.untaint(tracingStatus) ..'"}')
  ngx.exit(ngx.OK)
end

local connectedIntf = proxy.get("rpc.packetcapture.connectedIntf")
connectedIntf = connectedIntf and connectedIntf[1].value
local usbStatus = proxy.get("rpc.packetcapture.usbStatus")
usbStatus = usbStatus and usbStatus[1].value

local startCapture = proxy.get("rpc.packetcapture.startCapture")
startCapture = startCapture and startCapture[1].value

if variant == "VHA" then
  -- By default when traceroute path doesnot exist.
  if(not proxy.get("uci.traceroute.@diagping.DiagnosticsState")) then
    -- Creating traceroute path with name diagping
    proxy.add("uci.traceroute.","diagping")
  end
  -- Getting values for traceroute related parameters.
  traceroutePaths = {
    hostname = "uci.traceroute.@diagping.Host",
    hopcount = "uci.traceroute.@diagping.MaxHopCount",
    size = "uci.traceroute.@diagping.DataBlockSize",
    variant = "uci.env.var.vodafone_variant"
  }content_helper.getExactContent(traceroutePaths)
end

local connectivityTestResult = "0"

-- Function to perform connectivity test
-- If default gateway ping and any one of dnsserver ping
-- succeed, test is passed else test fails
-- If Wait time > 20 seconds, test fails
-- @param #pathIndex number - index of connectivityTestPaths table
--                        1 - default_gateway_ping
--                        2 - dnsserver1_ping
--                        3 - dnsserver2_ping
-- @param #waitTime number - seconds waited
-- @param #set boolean - if yes, calls transformer set else don't.
-- @return nil
local function startConnectivityTest(pathIndex, waitTime, set)
  if not set then
    proxy.set(connectivityTestPaths[pathIndex], "Requested")
    proxy.apply()
  end
  ngx.sleep(1)
  waitTime = waitTime + 1
  local testResult = { path = connectivityTestPaths[pathIndex] }
  content_helper.getExactContent(testResult)
  if testResult.path == "Requested" or testResult.path == "Waiting" then
    if waitTime > 20 then -- we've waited too long, so let's assume test has failed
      connectivityTestResult = "0"
    else
      startConnectivityTest(pathIndex, waitTime, true)
    end
  elseif testResult.path == "Success" then
    if pathIndex >= 2 then -- test has succeeded
      connectivityTestResult = "1"
    else
      startConnectivityTest(pathIndex+1, waitTime, false)
    end
  else -- status is either None or Failed
    if pathIndex == 2 then -- dnsserver_2_ping may get passed. so give a try
      startConnectivityTest(pathIndex+1, waitTime, false)
    else
      connectivityTestResult = "0"
    end
  end
end

if ngx.req.get_method() == "GET" and ngx.req.get_uri_args().action == "diagnose" then
  ngx.header.content_type = "application/json"
  local diagnoseResult  = {
    dataIPconnection    = "rpc.diagnostic_utility.dataIPconnection",
    wanstatus           = "rpc.diagnostic_utility.wanstatus",
    numberoflandevices  = "rpc.diagnostic_utility.numberoflandevices",
    voicePPPconnection  = "rpc.diagnostic_utility.voicePPPconnection",
    linkstatus          = "rpc.diagnostic_utility.linkstatus",
    dataPPPconnection   = "rpc.diagnostic_utility.dataPPPconnection",
    wanmode             = "rpc.diagnostic_utility.wanmode",
    lanstatus           = "rpc.diagnostic_utility.lanstatus",
    numberofUSBdevices  = "sys.usb.DeviceNumberOfEntries",
    voiceIPconnection   = "rpc.diagnostic_utility.voiceIPconnection",
    wifi2G              = "rpc.diagnostic_utility.wifi2G",
    wifi5G              = "rpc.diagnostic_utility.wifi5G",
  }
  if variant ~= "VHA" then
    diagnoseResult.teleLine1 = "uci.mmpbxrvsipnet.profile.@sip_profile_0.enabled"
    diagnoseResult.teleLine2 = "uci.mmpbxrvsipnet.profile.@sip_profile_1.enabled"
    if content_line2.hookstate == "" then
      diagnoseResult.teleLine2 = nil
    end
  end
  content_helper.getExactContent(diagnoseResult)
  -- Check for Internally connected device and USBHub Connection
  if diagnoseResult["numberofUSBdevices"] > "0" then
     local USBDevices = proxy.get("sys.usb.device.")
     if next(USBDevices) then
       for _, v in ipairs(USBDevices) do
          if v.param == "idVendor" and v.value == "2c7c" then
             diagnoseResult.Vendorid = "2c7c"
          end
          if v.param == "bDeviceClass" and v.value == "09" then
             diagnoseResult.USBDeviceClass = "09"
          end
       end
     end
  end

  if variant == "NZ" and connectivityTestPaths[1] == "rpc.network.interface.@wwan.default_gateway_ping" then
    --for vodafon nz mobile network, default gw is not allowed to ping. So we have to skip it.
    startConnectivityTest(2, 0, false)
  else
    startConnectivityTest(1, 0, false)
  end
  diagnoseResult.connectivity = connectivityTestResult
  ngx.print(json.encode(diagnoseResult))
  ngx.exit(ngx.OK)
end

-- To handle ajax get request, when diagnostics state is requested then trace result are captured
-- from datamodel path returns in json format.
if ngx.req.get_method() == "GET" and ngx.req.get_uri_args().action == "gettraceresult" then
  ngx.header.content_type = "application/json"
  local traceState = proxy.get("uci.traceroute.@diagping.DiagnosticsState")
  if next(traceState) then
    local hopTime1, hopTime2, hopTime3
    local traceResult = {}
    -- Traceroute results are captured and  data are manipulated according to user need, results are
    -- stored in table
    local traceData = content_helper.convertResultToObject("uci.traceroute.@diagping.RouteHops.",proxy.get("uci.traceroute.@diagping.RouteHops."))
    for _, trace in ipairs(traceData) do
      if trace["HopRTTimes"] ~= "*" then
        -- pattern match to seprate hoptimes.
        hopTime1, hopTime2, hopTime3 = match(trace["HopRTTimes"],"(%d*),?(%d*),?(%d*)")
      else
        hopTime1, hopTime2, hopTime3 = "*", "*", "*"
      end
      if trace["HopHost"] == "" then
        trace["HopHost"] = trace["HopHostAddress"]
      end
      traceResult[#traceResult + 1] = format('<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',  trace["HopHost"], trace["HopErrorCode"], hopTime1, hopTime2, hopTime3)
    end
    local trace = table.concat(traceResult, "")
    ngx.print('{"status":"' ..untaint(traceState[1].value).. '", "trace":"'..trace..'"}')
  else
    ngx.print('{"status":"' ..untaint(next(traceState) and traceState[1].value).. '"}')
  end
  ngx.exit(ngx.OK)
end

if ngx.req.get_method() == "GET" and ngx.req.get_uri_args().action == "getPingStatus" then
  ngx.header.content_type = "application/json"
  local pingStatus = {
    state          = "uci.ipping.@diagping.DiagnosticsState",
    SuccessCount   = "uci.ipping.@diagping.SuccessCount",
    FailureCount   = "uci.ipping.@diagping.FailureCount",
  }
  content_helper.getExactContent(pingStatus)
  if pingStatus.state == "Requested" then
    ngx.print('{"status":"progress"}')
  elseif pingStatus.state == "Complete" and pingStatus.SuccessCount ~= "0" then
    local pingResult    = {
      IP          = "uci.ipping.@diagping.Trace.@1.IP",
      SuccessRate = "uci.ipping.@diagping.SuccessCount",
      PacketSize  = "uci.ipping.@diagping.DataBlockSize",
      AverageRTT  = "uci.ipping.@diagping.AverageResponseTime",
    }
    content_helper.getExactContent(pingResult)
    pingResult.status = "success"
    ngx.print(json.encode(pingResult))
  else
    ngx.print('{"status":"error"}')
  end
  ngx.exit(ngx.OK)
end

local mapValidTrace = {
  hopcount = post_helper.getValidateNumberInRange(1,64),
  size = post_helper.getValidateNumberInRange(38,32768),
  hostname = gOrVal(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
}

if ngx.req.get_method() == "POST" then
  local postArgs = ngx.req.get_post_args()
  proxy.set("rpc.packetcapture.connectedIntf", postArgs.connectedIntf)
  proxy.set("rpc.packetcapture.startCapture", postArgs.startCapture)
  proxy.apply()
end

-- In order to trigger trace request. Diagnostics state will be changed to requested
-- state. Before setting all these values parameters are validated.
-- @param : data contains post data.
-- return boolean
local function restartTestTrace(data)
  local success, msg = false, {}
  if type(data) == "table"  then
    success, msg = content_helper.validateObject(data, mapValidTrace)
    if success then
      success = proxy.set({
        ["uci.traceroute.@diagping.Host"]= data["hostname"],
        ["uci.traceroute.@diagping.MaxHopCount"]= data["hopcount"],
        ["uci.traceroute.@diagping.DataBlockSize"]= data["size"],
        ["uci.traceroute.@diagping.DiagnosticsState"]= "Requested",
      })
    end
    if success then
      proxy.apply()
    end
  end
  return success, msg
end

if ngx.req.get_method() == "POST"  and (ngx.req.get_post_args().action == "Tracestart" or ngx.req.get_post_args().action == "Tracestop") then
  local postArgs = ngx.req.get_post_args()
  local success, errorMsg  = true, {}
  local traceState = proxy.get("uci.traceroute.@diagping.DiagnosticsState")
  ngx.header.content_type = "application/json"
  if ngx.req.get_post_args().action == "Tracestart" and next(traceState) and traceState[1].value ~= "Requested" then
    success, errorMsg  = restartTestTrace(postArgs)
  end
  if ngx.req.get_post_args().action == "Tracestop" then
    success = proxy.set("uci.traceroute.@diagping.DiagnosticsState", "Canceled")
    if success then
      proxy.apply();
    end
  end
  if success then
    ngx.print('{ "status":"success"}')
  else
    ngx.print(json.encode(errorMsg))
  end
  ngx.exit(ngx.HTTP_OK)
end



if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "downloadPingResult" then
  ngx.header.content_disposition = "attachment; filename=ping-result.txt"
  ngx.header.content_type = "application/octet-stream"
  ngx.header.set_cookie = "fileDownload=true; Path=/"  -- the JQuery download code requires this cookie
  local file = io.open("/tmp/ping_diagping")
  if file then
    ngx.print(file:read("*all"))
    file:close()
  else
    ngx.print(T"Error reading the file")
  end
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "getPingResult" then
  local host = ngx.req.get_post_args().host
  local pingStatus = proxy.get("uci.ipping.@diagping.DiagnosticsState")
  if pingStatus then
    pingStatus = pingStatus[1].value
  end
  ngx.header.content_type = "application/json"
  if validateHost(host) and pingStatus ~= "Requested" then
    if not proxy.getPN("uci.ipping.@diagping.", true) then
      proxy.add("uci.ipping.","diagping")
    end
    proxy.set({
      ["uci.ipping.@diagping.Host"]                 = host,
      ["uci.ipping.@diagping.NumberOfRepetitions"] = "5",
      ["uci.ipping.@diagping.DiagnosticsState"]     = "Requested",
    })
    proxy.apply()
    ngx.print('{"status":"progress"}')
  else
    ngx.print('{"status":"error"}')
  end
  ngx.exit(ngx.OK)
end

  ngx.print('\
<h1>');  ngx.print(T"Diagnostic Utility"); ngx.print('</h1>\
<h2>');  ngx.print(T"This section shows a list of tools which can be used to check the status of your network connection."); ngx.print('</h2>\
<div id="diagUtility-div-diagnose">\
  <h3>');  ngx.print(T"Automated Diagnosis"); ngx.print('</h3>\
  <div class="h3-content h3-content-mobile mobile-padding-bottom-between-elements">\
   <div class="row no-margin-right">\
    <div class="col-xs-12 col-sm-12 col-md-12 padding-top-bottom-20 no-padding-right restart-text-left mobile-padding-top-none">\
      <span style="font-weight: normal;">');  ngx.print(T"This diagnosis should take up to 2 minutes and cannot be cancelled once it has been started."); ngx.print('</span>\
    </div>\
  </div>\
  ');  
    row = {
      label = ui_helper.createClickButton({
        id="diagUtility-btn-diagnose",
        class="button button-blank mob-button-width",
        type="button",
        value=T"Diagnose"
        }),
      rowClass = "row no-margin-right",
      colClass = "col-xs-12 col-sm-12 col-md-12 text-right padding-top-bottom-20 no-padding-left mobile-padding-top-none diagnostic-utlity-padding-52"
    }
    ngx.print(ui_helper.createSingleRow(row))
    ngx.print('\
</div>\
</div>\
<h3>');  ngx.print(T"Ping Test"); ngx.print('</h3>\
<div class="h3-content no-padding-bottom">\
 <div class="diagnotstic-util">\
  <div class="left padding-top-bottom-20 mobile-padding-top-none">\
    <span style="font-weight: normal;">');  ngx.print(T"Please enter a valid hostname or IP address to execute the Ping test."); ngx.print('</span>\
  </div>\
</div>\
</div>\
');  
  local row = {
    {
      label = ui_helper.createTextField({
        id="diagUtility-txt-host",
        class="ipCheck full-width",
        maxlength="255",
        type="text"
        }),
      element = ui_helper.createClickButton({
        id="diagUtility-btn-ping",
        class="button button-blank mob-button-width",
        value=T"Ping",
        type="button"
        }),
      colLeftClass = "right padding-top-bottom-20 mobile-padding-top-none",
      colRightClass = "right padding-top-bottom-20 mobile-padding-top-none"
    }
  }
  ngx.print(ui_helper.createTable(row, "", "h3-content diagnostic-table"))
  ngx.print('\
<div class="row">\
  <div style="margin-top: 24px;" id="errMsg" class="message info message-info hidden">\
    <span  style="font-weight:normal;line-height:0px;">');  ngx.print(T"Please provide a valid hostname or IP address for a ping target"); ngx.print('\
    </span>\
  </div>\
</div>\
');  if vdf_helper.getVariant() == "VF-UK" then  ngx.print('\
  <h3>\
    ');  ngx.print(T"Tracing Tool"); ngx.print('\
  </h3>\
  <div class="h3-content no-padding-bottom mobile-no-table padding-top-20" style="margin-bottom: 20px !important">\
  </div>\
  <div class="h3-content no-padding-bottom vdf-table" style="margin-bottom: 0px !important">\
  ');  
    local row = {
      label = T"Connection Type",
      rowClass = "vdf-row",
      colRightClass = "right mobile-full",
      element = format('<div id="top-info-mode" class="rel">%s</div>', ui_helper.createDropDown(
      {
        class = dropdown,
        id = "sel-conn-type",
        style = "width: 165px;"
      }, connectionTypes, connectedIntf))
    }
    ngx.print(ui_helper.createRow(row))
    ngx.print('\
  </div>\
  ');  
    row = {
      label = ui_helper.createClickButton({
        class="button button-blank popup-trigger",
        id="tracetool-btn-start",
        value=T"Start",
        type="button"
      }),
      rowClass = "row restart-padding-top-20 no-margin-right",
      colClass = "col-xs-12 col-sm-12 col-md-12 text-right padding-bottom no-padding-right"
    }
    ngx.print(ui_helper.createSingleRow(row))
    ngx.print('\
\
  <div class="popup tL tracing-PopUp-usb-not-connected" id = "tracing-PopUp-usb-not-connected" role="dialog" style="display:none;" data-backdrop="false" >\
    <div class="row">\
      <div class="left">\
        <span>Please insert a USB device into one of the available USB slots before starting the tracing.</span>\
      </div>\
    </div>\
    <div class="apply-cancel">\
      <input value="OK" id = "tracetool-usb-ok" class="button button-apply" type="button">\
    </div>\
  </div>\
  <div class="popup tL tracing-PopUp-interface-not-up" id = "tracing-PopUp-interface-not-up" role="dialog" style="display:none;" data-backdrop="false" >\
    <div class="row">\
      <div class="left">\
        <span>The selected interface appears to be disconnected.</span>\
      </div>\
    </div>\
    <div class="apply-cancel">\
      <input value="OK" id = "tracetool-intf-not-up" class="button button-apply" type="button">\
    </div>\
  </div>\
  <div class="popup tL tracing-PopUp hidden" id = "Trace-In-Progress" role="dialog" data-backdrop="static">\
    <div class="row">\
      <div id="progress-bar-thinking-box">\
        <img src="/img/look_4/icons/icon-thinking.gif" alt="Loading...">\
      </div>\
    </div>\
    <p class="title">\
      <span>Tracing in Progress</span>\
    </p>\
    <div class="row padding-top-bottom-20">\
      <div class="left">\
        <span>Your Vox 3.0 is now recording all connection events. The capture file will be stored on the USB device. Please make sure to stop the capture before unplugging the USB device.</span>\
      </div>\
    </div>\
    <div class="apply-cancel">\
      <input value="OK" id = "traceInprogress"class="button button-apply" type="button" data-dismiss="modal" >\
    </div>\
  </div>\
');  end  ngx.print('\
<!-- Trace Route -->\
<div id="diagUtility-div-traceroute">\
  <h3>');  ngx.print(T"Tracing Route"); ngx.print('</h3>\
  <div class="h3-content h3-content-mobile">\
    ');  
      local rows =  {
        {
          label = T"Status",
          element = ui_helper.createOnlyText({
            id="traceroute-lbl-status"
            }),
          rowClass = "row restart-padding-top-20 no-margin-right",
          colLeftClass = "col-xs-12 col-sm-6 col-md-6 col-xl-6 padding-top-botto restart-text-leftm",
          colRightClass = "col-xs-12 col-sm-6 col-md-6 col-xl-6 padding-top-bottom padding-top-bottom restart-text-right no-padding-right",
        }, {
          label = T"Hostname",
          element = ui_helper.createTextField({
            id="traceroute-txt-hostname",
            name="hostname",
            value= next(traceroutePaths) and traceroutePaths.hostname,
            type="text"
            }),
          rowClass = "row restart-padding-top-20 no-margin-right",
          colLeftClass = "col-xs-12 col-sm-6 col-md-6 col-xl-6 padding-top-botto restart-text-leftm",
          colRightClass = "col-xs-12 col-sm-6 col-md-6 col-xl-6 padding-top-bottom padding-top-bottom restart-text-right no-padding-right",
        }, {
          label = T"Max Hop Count",
          element = ui_helper.createTextField({
            type="text",
            id="traceroute-txt-hopcount",
            name="hopcount",
            value= next(traceroutePaths) and traceroutePaths.hopcount
            }),
          rowClass = "row restart-padding-top-20 no-margin-right",
          colLeftClass = "col-xs-12 col-sm-6 col-md-6 col-xl-6 padding-top-botto restart-text-leftm",
          colRightClass = "col-xs-12 col-sm-6 col-md-6 col-xl-6 padding-top-bottom padding-top-bottom restart-text-right no-padding-right",
        }, {
          label = T"size(bytes)",
          element = ui_helper.createTextField({
            type="text",
            id="traceroute-txt-size",
            name="size",
            value= next(traceroutePaths) and traceroutePaths.size
            }),
          rowClass = "row restart-padding-top-20 no-margin-right",
          colLeftClass = "col-xs-12 col-sm-6 col-md-6 col-xl-6 padding-top-botto restart-text-leftm",
          colRightClass = "col-xs-12 col-sm-6 col-md-6 col-xl-6 padding-top-bottom padding-top-bottom restart-text-right no-padding-right",
        }
      }
      ngx.print(ui_helper.createMultipleRows(rows))

      row = {
        label = ui_helper.createClickButton({
          class="button button-blank mob-button-width",
          id="traceroute-btn-start",
          value=T"Tracestart",
          type="button"
          }),
        rowClass = "row restart-padding-top-20 no-margin-right",
        colClass = "col-xs-12 col-sm-12 col-md-12 text-right padding-top-bottom no-padding-right"
      }
      ngx.print(ui_helper.createSingleRow(row))
      ngx.print('\
    <div class = "table-responsive">\
      <table id="traceroute-tbl" style="width:100%">\
        <thead>\
          <tr>\
            <th>');  ngx.print(T"Hostname"); ngx.print('</th>\
            <th>');  ngx.print(T"Error code"); ngx.print('</th>\
            <th>');  ngx.print(T"RTT1(ms)"); ngx.print('</th>\
            <th>');  ngx.print(T"RTT2(ms)"); ngx.print('</th>\
            <th>');  ngx.print(T"RTT3(ms)"); ngx.print('</th>\
          </tr>\
        </thead>\
        <tbody id= "traceroute-tbl-data">\
        </tbody>\
      </table>\
    </div>\
  </div>\
</div>\
\
\
<!-- Modal -->\
<div class="modal" id="diagUtility-div-inProgressPopUp" role="dialog" data-backdrop="static" data-keyboard="false">\
  <div class="modal-dialog diag-inprogressPopup">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-body no-padding mobile-modal-padding-top">\
        <form class="form-horizontal">\
          <div id="diagUtility-info-diagnoseInProgress">\
            <div class="form-group no-margin-bottom">\
              <div class="col-sm-12">\
                <img src="img/look_4/icons/icon-thinking.gif" alt="Loading..." class="padding-top-bottom-20" />\
                <p class="no-padding-left title"><span style="font-weight: normal">');  ngx.print(T"Diagnosis in Progress"); ngx.print('</span></p>\
              </div>\
            </div>\
          </div>\
          <div id="diagUtility-info-pingInProgress">\
            <div class="form-group no-margin-bottom">\
              <div class="col-sm-12">\
                <img src="img/look_4/icons/icon-thinking.gif" alt="Loading..." class="padding-top-bottom-20" />\
                <p class="no-padding-left title"><span style="font-weight: normal">');  ngx.print(T"Ping Test in Progress"); ngx.print('</span></p>\
              </div>\
            </div>\
          </div>\
          <!-- TODO - Tracing Tool - No Lower layer support\
          <div id="diagUtility-info-traceInProgress" class="hidden">\
            <div class="form-group">\
              <div class="col-sm-12">\
                <img src="img/look_4/icons/icon-thinking.gif" alt="Loading..." class="padding-top-bottom-20" />\
                <h3 class="padding-bottom-20">Tracing in Progress</h3>\
              </div>\
            </div>\
            <div class="form-group">\
              <div class="col-sm-12">\
                <p class="padding-bottom-40"><span>');  ngx.print(T("Your " .. gatewayName .." is now recording all connection events.")); ngx.print('</span></p>\
                <p><span>');  ngx.print(T"This process runs in the background, so you can close this window. A message box below the menu will indicate this process is still running, and on this message box you can press Stop at any time. You can then view the results file."); ngx.print('</span></p>\
              </div>\
            </div>\
            <div class="form-group">\
              <div class="col-sm-12">\
                <div class="modal-footer">\
                  <input value="');  ngx.print(T"OK"); ngx.print('" class="button button-apply mob-button-width" id="tracingOkButton" type="button" data-dismiss="modal">\
                </div>\
              </div>\
            </div>\
          </div>\
        -->\
      </form>\
    </div>\
  </div>\
</div>\
</div>\
<!-- End -->\
\
<!-- Modal -->\
<div class="modal" id="diagUtility-div-diagnoseResults" role="dialog" data-backdrop="static" data-keyboard="false">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel"></div>\
      </div>\
      <div class="modal-body no-padding mobile-modal-padding-top">\
        <form class="form-horizontal">\
          <div id="diagUtility-info-diagnoseCompleted" class="hidden">\
            <div class="form-group no-margin-bottom">\
              <div class="col-sm-12">\
                <p class="no-padding-left margin-bottom-25 title" style="padding-bottom: 25px;"><span style="font-weight: normal;">');  ngx.print(T"Diagnosis Completed"); ngx.print('</span></p>\
              </div>\
            </div>\
            ');  
              rows = {
                {
                  label = T"LAN",
                  element = ui_helper.createOnlyText({
                    id="diagUtility-info-lanstatus"
                    }),
                  rowClass = "row",
                  colLeftClass = "col-md-6 col-xs-12",
                  colRightClass = "col-md-6 col-xs-12 txt-align mobile-padding-bottom-10",
                }, {
                  label = T"Number of LAN devices:",
                  element = ui_helper.createOnlyText({
                    id="diagUtility-info-numberoflandevices"
                    }),
                  rowClass = "row",
                  colLeftClass = "col-md-6 col-xs-12 diagnostic-notch",
                  colRightClass = "col-md-6 col-xs-12 txt-align mobile-padding-bottom-10",
                }
              }
              ngx.print(ui_helper.createMultipleRows(rows))
              ngx.print('\
            <div class="row">\
              <span>&nbsp;</span>\
            </div>\
            ');  
              rows = {
                {
                  label = T"WAN",
                  element = ui_helper.createOnlyText({
                    id="diagUtility-info-wanstatus"
                    }),
                  rowClass = "row",
                  colLeftClass = "col-md-6 col-xs-12",
                  colRightClass = "col-md-6 col-xs-12 txt-align mobile-padding-bottom-10",
                }, {
                  label = T"WAN Mode",
                  element = ui_helper.createOnlyText({
                    id="diagUtility-info-wanmode"
                    }),
                  rowClass = "row",
                  colLeftClass = "col-md-6 col-xs-12 diagnostic-notch",
                  colRightClass = "col-md-6 col-xs-12 txt-align  mobile-padding-bottom-10",
                }, {
                  label = T"Link status",
                  element = ui_helper.createOnlyText({
                    id="diagUtility-info-linkstatus"
                    }),
                  rowClass = "row",
                  colLeftClass = "col-md-6 col-xs-12 diagnostic-notch",
                  colRightClass = "col-md-6 col-xs-12 txt-align mobile-padding-bottom-10",
                }
              }
              ngx.print(ui_helper.createMultipleRows(rows))

              if variant ~= "VF-UK" then
                rows = {
                  {
                   label = T"Data IP connection",
                   element = ui_helper.createOnlyText({
                     id="diagUtility-info-dataIPconnection"
                     }),
                   rowClass = "row",
                   colLeftClass = "col-md-6 col-xs-12 diagnostic-notch",
                   colRightClass = "col-md-6 col-xs-12 txt-align mobile-padding-bottom-10",
                  }
                }
                ngx.print(ui_helper.createMultipleRows(rows))
              end

              if variant == "VF-UK" then
                rows = {
                  {
                   label = T"PPP connection",
                   element = ui_helper.createOnlyText({
                     id="diagUtility-info-dataPPPconnection"
                     }),
                   rowClass = "row",
                   colLeftClass = "col-md-6 col-xs-12 diagnostic-notch",
                   colRightClass = "col-md-6 col-xs-12 txt-align mobile-padding-bottom-10",
                  }
                }
                ngx.print(ui_helper.createMultipleRows(rows))
              end

              if variant ~= "VHA" and variant ~= "VF-UK" then
                rows = {
                  {
                    label = T"Voice IP connection",
                    element = ui_helper.createOnlyText({
                      id="diagUtility-info-voiceIPconnection"
                      }),
                    rowClass = "row",
                    colLeftClass = "col-md-6 col-xs-12 diagnostic-notch",
                    colRightClass = "col-md-6 col-xs-12 txt-align mobile-padding-bottom-10",
                  }, {
                    label = T"Data PPP connection",
                    element = ui_helper.createOnlyText({
                      id="diagUtility-info-dataPPPconnection"
                      }),
                    rowClass = "row",
                    colLeftClass = "col-md-6 col-xs-12 diagnostic-notch",
                    colRightClass = "col-md-6 col-xs-12 txt-align mobile-padding-bottom-10",
                  }, {
                    label = T"Voice PPP connection",
                    element = ui_helper.createOnlyText({
                      id="diagUtility-info-voicePPPconnection"
                      }),
                    rowClass = "row",
                    colLeftClass = "col-md-6 col-xs-12 diagnostic-notch",
                    colRightClass = "col-md-6 col-xs-12 txt-align mobile-padding-bottom-10",
                  }
                }
                ngx.print(ui_helper.createMultipleRows(rows))
              end

              if variant ~= "VHA"  and  variant ~= "VF-UK" then
                rows = {
                  {
                    label = T"Telephone",
                    element = ui_helper.createOnlyText({
                      id="diagUtility-info-telephone"
                      }),
                    rowClass = "row margin-top",
                    colLeftClass = "col-md-6 col-xs-12 mobile-bottom-20",
                    colRightClass = "col-md-6 col-xs-12 txt-align mobile-padding-bottom-10s",
                 }, {
                    label = T"Line 1:",
                    element = ui_helper.createOnlyText({
                      id="diagUtility-info-line1"
                      }),
                    rowClass = "row",
                    colLeftClass = "col-md-6 col-xs-12 diagnostic-notch",
                    colRightClass = "col-md-6 col-xs-12 txt-align  mobile-padding-bottom-10",
                 }, {
                    label = T"Line 2:",
                    element = ui_helper.createOnlyText({
                      id="diagUtility-info-line2"
                      }),
                    rowClass = "row",
                    colLeftClass = "col-md-6 col-xs-12 diagnostic-notch",
                    colRightClass = "col-md-6 col-xs-12 txt-align  mobile-padding-bottom-10",
                  }
                }
                ngx.print(ui_helper.createMultipleRows(rows))
              end

              rows = {
                {
                  label = T"USB",
                  element = ui_helper.createOnlyText({}, T"succeeded"),
                  rowClass = "row margin-top",
                  colLeftClass = "col-md-6 col-xs-12",
                  colRightClass = "col-md-6 col-xs-12 txt-align  mobile-padding-bottom-10",
                }, {
                  label = T"Number of USB devices:",
                  element = ui_helper.createOnlyText({
                    id="diagUtility-info-numberofUSBdevices"
                    }),
                  rowClass = "row",
                  colLeftClass = "col-md-6 col-xs-12 diagnostic-notch",
                  colRightClass = "col-md-6 col-xs-12 txt-align  mobile-padding-bottom-10",
                }, {
                  label = T"Wi-Fi",
                  element = ui_helper.createOnlyText({
                    id="diagUtility-info-wifi"
                    }),
                  rowClass = "row margin-top",
                  colLeftClass = "col-md-6 col-xs-12",
                  colRightClass = "col-md-6 col-xs-12 txt-align  mobile-padding-bottom-10",
                }, {
                  label = T"Wi-Fi 2.4GHz:",
                  element = ui_helper.createOnlyText({
                    id="diagUtility-info-wifi24status"
                    }),
                  rowClass = "row",
                  colLeftClass = "col-md-6 col-xs-12 padding-left-25 diagnostic-notch",
                  colRightClass = "col-md-6 col-xs-12 txt-align  mobile-padding-bottom-10",
                }, {
                  label = T"Wi-Fi 5GHz:",
                  element = ui_helper.createOnlyText({
                    id="diagUtility-info-wifi5status"
                    }),
                  rowClass = "row padding-bottom",
                  colLeftClass = "col-md-6 col-xs-12 padding-left-25 diagnostic-notch",
                  colRightClass = "col-md-6 col-xs-12 txt-align  mobile-padding-bottom-10",
                }, {
                  label = T"Connectivity Test",
                  element = ui_helper.createOnlyText({
                    id="diagUtility-info-connectivity"
                    }),
                  rowClass = "row margin-top",
                  colLeftClass = "col-md-6 col-xs-12 mobile-bottom-20",
                  colRightClass = "col-md-6 col-xs-12 txt-align",
                }
              }
              ngx.print(ui_helper.createMultipleRows(rows))
              ngx.print('\
            <div class="form-group">\
              <div class="col-sm-12">\
                <div class="modal-footer">\
                  <input value="');  ngx.print(T"OK"); ngx.print('" class="button button-apply mob-button-width" id="diagUtility-btn-diagnosisOK" type="button">\
                </div>\
              </div>\
            </div>\
          </div>\
\
          <div id="diagUtility-div-diagnoseError" class="hidden">\
            <div class="form-group">\
              <div class="col-sm-12">\
                <h3 class="padding-bottom-20">');  ngx.print(T"Diagnosis timed out"); ngx.print('</h3>\
              </div>\
            </div>\
            <div class="form-group">\
              <div class="col-sm-12">\
               <p><span>');  ngx.print(T"Please try again."); ngx.print('</span></p>\
             </div>\
           </div>\
           <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input value="');  ngx.print(T"OK"); ngx.print('" class="button button-apply mob-button-width" id="okButton2" type="button" data-dismiss="modal">\
              </div>\
            </div>\
          </div>\
        </div>\
\
        <div id="diagUtility-div-pingError" class="hidden">\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="no-padding-left title"><span style="font-weight: normal;">');  ngx.print(T"Ping Test Failed"); ngx.print('</span></p>\
            </div>\
          </div>\
          <div class="row big padding-top-bottom-20 mobile-big">\
\
            <div class="col-sm-12">\
             <span>');  ngx.print(T"The ping test failed to complete. Please check the IP address you specified and try again."); ngx.print('</span>\
           </div>\
         </div>\
         <div class="row">\
          <div class="col-sm-12">\
            <div class="modal-footer">\
              <input value="');  ngx.print(T"OK"); ngx.print('" class="button button-apply mob-button-width" id="okButton2" type="button" data-dismiss="modal">\
            </div>\
          </div>\
        </div>\
      </div>\
      <div id="diagUtility-div-pingSuccess" class="hidden">\
        <div class="form-group">\
          <div class="col-sm-12">\
            <p class="no-padding-left title"><span style="font-weight: normal;">');  ngx.print(T"Ping Test Successful"); ngx.print('</span></p>\
          </div>\
        </div>\
        ');  
          rows = {
            {
              label = T"IPv4 Address",
              element = ui_helper.createOnlyText({
                id="diagUtility-info-IP"
                }),
              rowClass = "row big padding-top-bottom-20 mobile-big",
              colLeftClass = "col-md-6 col-xs-12 mobile-padding-bottom-none",
              colRightClass = "col-md-6 col-xs-12 mobile-padding-top-none mobile-padding-bottom-10 txt-align",
            }, {
              label = T"Packet Success Rate",
              element = ui_helper.createOnlyText({
                id="diagUtility-info-successRate"
                }),
              rowClass = "row padding-top-bottom-20 mobile-padding-bottom-10",
              colLeftClass = "col-md-6 col-xs-12",
              colRightClass = "col-md-6 col-xs-12 txt-align mobile-padding-top-none",
            }, {
              label = T"Packet Size",
              element = ui_helper.createOnlyText({
                id="diagUtility-info-packetSize"
                }),
              rowClass = "row padding-top-bottom-20 mobile-padding-bottom-10",
              colLeftClass = "col-md-6 col-xs-12 mobile-padding-bottom-none",
              colRightClass = "col-md-6 col-xs-12 txt-align mobile-padding-top-none",
            }, {
              label = T"Average Roundtrip Time",
              element = ui_helper.createOnlyText({
                id="diagUtility-info-RTT"
                }),
              rowClass = "row padding-top-bottom-20 mobile-padding-bottom-10",
              colLeftClass = "col-md-6 col-xs-12 mobile-padding-bottom-none",
              colRightClass = "col-md-6 col-xs-12 txt-align mobile-padding-top-none",
            }
          }
          ngx.print(ui_helper.createMultipleRows(rows))
          ngx.print('\
        <div class="form-group">\
          <div class="col-sm-12">\
            <div class="modal-footer hidden-xs">\
              <input class="button button-cancel downloadStuff mob-button-width mobile-margin-bottom-20" type="button" id="diagUtility-btn-downloadPingResult" value="');  ngx.print(T"Download"); ngx.print('" data-dismiss="modal">\
              <input value="');  ngx.print(T"OK"); ngx.print('" class="button button-apply mob-button-width" id="diagUtility-btn-pingSuccessOK" type="button" data-dismiss="modal">\
            </div>\
            <div class="modal-footer mobile">\
              <input value="');  ngx.print(T"OK"); ngx.print('" class="button button-apply mob-button-width mobile-margin-bottom-20" id="diagUtility-btn-pingSuccessOK" type="button" data-dismiss="modal">\
              <input class="button button-cancel downloadStuff mob-button-width" type="button" id="diagUtility-btn-downloadPingResult" value="');  ngx.print(T"Download"); ngx.print('" data-dismiss="modal">\
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
\
<!-- Modal -->\
<div class="modal fade" id="diagUtility-div-diagnoseCompleted" role="dialog" data-backdrop="static" data-keyboard="false">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel"></div>\
      </div>\
      <div class="modal-body no-padding mobile-modal-padding-top">\
        <form class="form-horizontal">\
          <div class="form-group no-margin-bottom">\
            <div class="col-sm-12">\
              <p class="no-padding-left title"><span style="font-weight: normal;">');  ngx.print(T"Diagnosis Completed"); ngx.print('</span></p>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12 padding-top-bottom-20 mobile-padding-bottom-none">\
              <p><span>');  ngx.print(T("Your " .. gatewayName .. " detected no issues.")); ngx.print('</span></p>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input value="');  ngx.print(T"OK"); ngx.print('" class="button button-apply mob-button-width" id="diagUtility-btn-diagnoseOK" type="button">\
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
<script>\
bindChosen();\
var target = "modals/status-support/diagnosticUtility.lp";\
\
var variant = "');  ngx.print(variant); ngx.print('"\
var resultsMap = [\
{ "0" : "');  ngx.print(T"disconnected"); ngx.print('", "1" : "');  ngx.print(T"connected"); ngx.print('" },\
{ "0" : "');  ngx.print(T"Disabled"); ngx.print('",     "1" : "');  ngx.print(T"Enabled"); ngx.print('"   },\
{ "0" : "');  ngx.print(T"failed"); ngx.print('",       "1" : "');  ngx.print(T"succeeded"); ngx.print('" },\
]\
\
var T = {\
  "Ongoing"        : "');  ngx.print(T"Ongoing"); ngx.print('",\
  "Completed"      : "');  ngx.print(T"Completed"); ngx.print('",\
  "Tracestart"     : "');  ngx.print(T"Tracestart"); ngx.print('",\
  "Tracestop"      : "');  ngx.print(T"Tracestop"); ngx.print('",\
  "Failed"         : "');  ngx.print(T"Failed"); ngx.print('",\
  "Not Connected"  : "');  ngx.print(T"Not Connected"); ngx.print('"\
}\
$(function () {\
$(".mobile-cancel-popup").click(function(){\
  $(".modal").modal(\'hide\');\
});\
\
var startcapture = "');  ngx.print(startCapture); ngx.print('"\
if( startcapture == "inprogress"){\
  $("#tracetool-btn-start").prop("disabled", true).addClass("op40");\
   $("#Alert-unplug-usb").removeClass("hidden");\
}\
\
// Show Automated diagnosis and traceroute only when Admin Mode is selected.\
if ($("#home-sel-mode").val() !== "35"){\
  if (variant !== "NZ" && variant !== "VF-UK") {\
    $("#diagUtility-div-diagnose, #diagUtility-div-traceroute").hide();\
  }else {\
    $("#diagUtility-div-diagnose").show();\
    $(" #diagUtility-div-traceroute").hide();\
  }\
}else {\
  if (variant == "VHA"){\
    $("#diagUtility-div-traceroute").show();\
  }else {\
    $("#diagUtility-div-traceroute").hide();\
  }\
}\
var w = window.innerWidth;\
\
if (w > 980) {\
  if ($("#home-sel-mode").val() !== "35"){\
    if (variant !== "NZ" && variant !== "VF-UK") {\
      $("#diagUtility-div-diagnose, #diagUtility-div-traceroute").hide();\
    }else {\
      $("#diagUtility-div-diagnose").show();\
      $(" #diagUtility-div-traceroute").hide();\
    }\
  }\
} else {\
  if ($("#home-sel-mobmode").val() !== "35") {\
    if (variant !== "NZ" && variant !== "VF-UK") {\
      $("#diagUtility-div-diagnose, #diagUtility-div-traceroute").hide();\
    }else {\
      $("#diagUtility-div-diagnose").show();\
      $(" #diagUtility-div-traceroute").hide();\
    }\
  } else {\
    $("#diagUtility-div-diagnose").show();\
    if (variant == "VHA") $("#diagUtility-div-traceroute").show();\
  }\
}\
\
$(document).on("change", "#home-sel-mode", function(){\
  if ($(this).val() === "35") {\
    $("#diagUtility-div-diagnose").show()\
    if (variant == "VHA") $("#diagUtility-div-traceroute").show();\
  } else {\
    if (variant !== "NZ" && variant !== "VF-UK") {\
      $("#diagUtility-div-diagnose, #diagUtility-div-traceroute").hide();\
    }else {\
      $("#diagUtility-div-diagnose").show();\
      $(" #diagUtility-div-traceroute").hide();\
    }\
  }\
});\
\
$(document).on("change", "#home-sel-mobmode", function(){\
  if ($(this).val() == "35") {\
    $("#diagUtility-div-diagnose").show();\
    if (variant == "VHA") $("#diagUtility-div-traceroute").show();\
  } else {\
    if (variant !== "NZ" && variant !== "VF-UK") {\
      $("#diagUtility-div-diagnose, #diagUtility-div-traceroute").hide();\
    }else {\
      $("#diagUtility-div-diagnose").show();\
      $(" #diagUtility-div-traceroute").hide();\
    }\
  }\
});\
\
$("#diagUtility-btn-diagnose").click(function() {\
  $("#diagUtility-div-inProgressPopUp").modal();\
  $("#diagUtility-div-pingError, #diagUtility-info-traceInProgress, #diagUtility-info-pingInProgress").addClass("hidden");\
  $("#diagUtility-info-diagnoseInProgress").removeClass("hidden");\
  $.ajax({\
    url: target+"?action=diagnose",\
    dataType: \'json\',\
    timeout: 30000,\
    cache: false,\
    contentType: false,\
    processData: false,\
    type: \'get\'\
  })\
.success(function(responseTxt, statusTxt, xhr) {\
  var line2 = "');  ngx.print(content_line2.hookstate); ngx.print('";\
  $("#diagUtility-div-inProgressPopUp").modal("hide");\
  $("#diagUtility-div-pingSuccess").addClass("hidden");\
  $("#diagUtility-info-diagnoseCompleted").removeClass("hidden");\
  $("#diagUtility-div-diagnoseError").addClass("hidden");\
  $("#diagUtility-div-diagnoseResults").modal();\
  $("#diagUtility-info-lanstatus").text(resultsMap[2][responseTxt.lanstatus])\
  $("#diagUtility-info-numberoflandevices").text(responseTxt.numberoflandevices)\
  $("#diagUtility-info-wanstatus").text(resultsMap[2][responseTxt.wanstatus])\
  $("#diagUtility-info-wanmode").text(responseTxt.wanmode)\
  $("#diagUtility-info-linkstatus").text(resultsMap[0][responseTxt.linkstatus])\
  $("#diagUtility-info-dataIPconnection").text(resultsMap[0][responseTxt.dataIPconnection])\
  $("#diagUtility-info-dataPPPconnection").text(resultsMap[0][responseTxt.dataPPPconnection])\
  if (variant !== "NZ") {\
    $("#diagUtility-info-voiceIPconnection").text(resultsMap[0][responseTxt.voiceIPconnection])\
    $("#diagUtility-info-voicePPPconnection").text(resultsMap[0][responseTxt.voicePPPconnection])\
  } else {\
    $("#diagUtility-info-voiceIPconnection").closest(".row").addClass("hidden")\
    $("#diagUtility-info-voicePPPconnection").closest(".row").addClass("hidden")\
  }\
  $("#diagUtility-info-telephone").text(resultsMap[2][(responseTxt.teleLine1 == "1" || responseTxt.teleLine2 == "1") ? 1 : 0])\
  $("#diagUtility-info-line1").text(resultsMap[1][responseTxt.teleLine1])\
  if (line2 !== "") {\
    $("#diagUtility-info-line2").text(resultsMap[1][responseTxt.teleLine2])\
  } else {\
    $("#diagUtility-info-line2").closest(".row").addClass("hidden")\
  }\
  if (responseTxt.Vendorid == "2c7c" && responseTxt.USBDeviceClass == "09") {\
    $("#diagUtility-info-numberofUSBdevices").text(responseTxt.numberofUSBdevices - 2)\
  } else {\
    if (responseTxt.Vendorid == "2c7c" || responseTxt.USBDeviceClass == "09") {\
      $("#diagUtility-info-numberofUSBdevices").text(responseTxt.numberofUSBdevices - 1)\
    } else {\
    $("#diagUtility-info-numberofUSBdevices").text(responseTxt.numberofUSBdevices)\
    }\
  }\
  $("#diagUtility-info-wifi").text(resultsMap[2][(+responseTxt.wifi2G || +responseTxt.wifi5G) + ""])\
  $("#diagUtility-info-wifi24status").text(resultsMap[1][responseTxt.wifi2G])\
  $("#diagUtility-info-wifi5status").text(resultsMap[1][responseTxt.wifi5G])\
  $("#diagUtility-info-connectivity").text(resultsMap[2][responseTxt.connectivity])\
\
  $("#diagUtility-btn-diagnosisOK").unbind().click(function() {\
    $("#diagUtility-div-diagnoseResults").modal("hide");\
    if(+responseTxt.lanstatus && +responseTxt.wanstatus && (+responseTxt.wifi2G || +responseTxt.wifi5G) && +responseTxt.connectivity) {\
      $("#diagUtility-div-diagnoseCompleted").modal();\
    }\
    $("#diagUtility-info-pingInProgress, #diagUtility-info-diagnoseInProgress, #diagUtility-info-traceInProgress").addClass("hidden");\
  });\
})\
.error(function() {\
  $("#diagUtility-div-inProgressPopUp").modal("hide");\
  $("#diagUtility-div-pingSuccess").addClass("hidden");\
  $("#diagUtility-info-diagnoseCompleted").addClass("hidden");\
  $("#diagUtility-div-diagnoseError").removeClass("hidden");\
  $("#diagUtility-div-diagnoseResults").modal();\
  $("#diagUtility-btn-diagnosisOK").unbind().click(function() {\
    $("#diagUtility-div-diagnoseResults").modal("hide");\
    $("#diagUtility-info-pingInProgress, #diagUtility-info-diagnoseInProgress, #diagUtility-info-traceInProgress").addClass("hidden");\
  });\
});\
});\
$("#diagUtility-btn-downloadPingResult").click(function() {\
 var params = new Array(\
  { name : "action", value : "downloadPingResult" },\
  { name : "CSRFtoken", value : "');  ngx.print(CSRFtoken); ngx.print('" });\
downloadFile(target, params);\
});\
$("#diagUtility-btn-diagnoseOK").click(function() {\
  $("#diagUtility-div-diagnoseCompleted").modal("hide");\
});\
\
var elements = {\
  hostName: "#diagUtility-txt-host"\
}\
var validations = {\
  hostName: function(value) {\
    return validateDomain(value) && value !== "0.0.0.0";\
  }\
}\
\
$("#diagUtility-btn-ping").click(function() {\
  $("#errMsg").addClass("hidden");\
  if (!validateElements(elements, validations)) {\
    $("#errMsg").removeClass("hidden");\
    return false;\
  }\
  $(".mobile-cancel-popup").addClass("modal-margin-top-20");\
  $.post(target, {"CSRFtoken" : "');  ngx.print(CSRFtoken); ngx.print('", "host" : $("#diagUtility-txt-host").val(), "action" : "getPingResult"}, function(responseTxt) {\
    if (responseTxt.status == "progress") {\
      $("#diagUtility-div-inProgressPopUp").modal();\
      $("#diagUtility-info-traceInProgress, #diagUtility-info-diagnoseCompleted, #diagUtility-info-diagnoseInProgress").addClass("hidden");\
      $("#diagUtility-info-pingInProgress").removeClass("hidden");\
      window.setTimeout(function(){\
        getStatus(target);\
      }, 5000);\
} else {\
  $(".mobile-cancel-popup").removeClass("modal-margin-top-20");\
  $("#diagUtility-info-diagnoseCompleted, #diagUtility-div-pingSuccess").addClass("hidden");\
  $("#diagUtility-div-inProgressPopUp").modal("hide");\
  $("#tracing-PopUp").modal("hide");\
  $("#diagUtility-div-diagnoseResults").modal();\
  $("#diagUtility-div-pingError").removeClass("hidden");\
}\
}\
);\
});\
});\
\
function getStatus(target) {\
  $.ajax({\
    url: target+"?action=getPingStatus",\
    dataType: \'json\',\
    timeout: 10000, // If a request takes more than 10 seconds, Show failed message\
    cache: false,\
    contentType: false,\
    processData: false,\
    type: \'get\'\
  })\
.success(function(responseTxt, statusTxt, xhr) {\
  if (responseTxt.status == "success") {\
    $("#diagUtility-div-inProgressPopUp").modal("hide");\
    $("#diagUtility-div-pingError").addClass("hidden");\
    $("#diagUtility-div-diagnoseResults").modal();\
    $("#diagUtility-info-RTT").text(responseTxt.AverageRTT + "ms");\
    $("#diagUtility-info-successRate").text(responseTxt.SuccessRate + " ');  ngx.print(T"from"); ngx.print(' 5");\
    $("#diagUtility-info-IP").text(responseTxt.IP);\
    $("#diagUtility-info-packetSize").text(responseTxt.PacketSize + " Bytes");\
    $("#diagUtility-div-pingSuccess").removeClass("hidden");\
    return true;\
  } else if (responseTxt.status == "progress") {\
    window.setTimeout(function() {\
      xhr.abort();\
      getStatus(target);\
      return true;\
    }, 5000);\
} else {\
  showFailedPopup();\
  return false;\
}\
})\
.error(function() {\
  showFailedPopup();\
  return false;\
});\
}\
\
function showFailedPopup() {\
  $("#diagUtility-div-inProgressPopUp").modal("hide");\
  $("#tracing-PopUp-usb-not-connected, #tracing-PopUp-interface-not-up").modal("hide");\
  $("#diagUtility-div-pingSuccess").addClass("hidden");\
  $("#diagUtility-div-diagnoseResults").modal();\
  $("#diagUtility-div-pingError").removeClass("hidden");\
}\
\
//AJAX Request to get result dynamically.\
function getTraceResult(target){\
  $.ajax({\
    url: target+"?action=gettraceresult",\
    dataType: \'json\',\
    timeout: 10000, // If a request takes more than 10 seconds, Show failed message\
    cache: false,\
    contentType: false,\
    processData: false,\
    type: \'get\'\
  })\
  .success(function(responseTxt, statusTxt, xhr) {\
    if (responseTxt.status == "Requested") {\
      $("#traceroute-lbl-status").text(T["Ongoing"])\
      $("#traceroute-tbl-data").html(responseTxt.trace)\
      window.setTimeout(function() {\
        getTraceResult(target)\
      }, 2000);\
    } else if (responseTxt.status == "Complete") {\
        $("#traceroute-lbl-status").text(T["Completed"]);\
        $("#traceroute-tbl-data").html(responseTxt.trace)\
        $("#traceroute-btn-start").val(T["Tracestart"]);\
    } else if (responseTxt.status == "None"){\
        $("#traceroute-lbl-status").text(T["Not Connected"]);\
        $("#traceroute-btn-start").val(T["Tracestart"]);\
    } else{\
        $("#traceroute-lbl-status").text(T["Failed"]);\
        $("#traceroute-tbl-data").html(responseTxt.trace)\
        $("#traceroute-btn-start").val(T["Tracestart"]);\
    }\
    return true\
  })\
  .error(function() {\
    return false;\
  });\
}\
\
//To display red border and errorMsg in tooltip\
function errorPopover(id, text){\
  $("#traceroute-txt-"+id).addClass(\'error-tooltip\');\
  $("#traceroute-txt-"+id).each(function() {\
    var $this = $(this);\
    $this.popover({\
      trigger: \'hover\',\
      placement: \'bottom\',\
      html: true,\
      content:text\
    });\
  });\
}\
\
$("#traceroute-btn-start").click(function(){\
  var buttonValue = $(this).val();\
  if (buttonValue  == "Tracestart"){\
    $(this).val(T["Tracestop"]);\
  }\
  $("#traceroute-txt-hostname, #traceroute-txt-hopcount, #traceroute-txt-size").removeClass(\'error-tooltip\');\
  $("#traceroute-tbl-data").empty();\
  var params = new Array(\
  { name : "action", value : buttonValue },\
  { name : "CSRFtoken", value : "');  ngx.print(CSRFtoken); ngx.print('" },\
  { name : "size", value : $("#traceroute-txt-size").val()},\
  { name : "hopcount", value : $("#traceroute-txt-hopcount").val()},\
  { name : "hostname", value : $("#traceroute-txt-hostname").val()});\
  $.post(target, params, function(reponseTxt){\
    if (reponseTxt.status == "success") {\
      getTraceResult(target);\
    } else {\
      $("#traceroute-btn-start").val(T["Tracestart"]);\
      $.each(reponseTxt, function(key, value){\
        errorPopover(key, value)\
      });\
    }\
  });\
});\
$("#tracetool-btn-start").click(function(){\
  var connType = $("#sel-conn-type").children("option").filter(":selected").val();\
  var params = new Array(\
    { name : "action", value : "SAVE" },\
    { name : "CSRFtoken", value : "');  ngx.print(CSRFtoken); ngx.print('" },\
    { name : "startCapture", value : "start" },\
    { name : "connectedIntf", value : connType});\
  var usbStatus = "');  ngx.print(usbStatus); ngx.print('";\
  $.post(target, params, function(reponseTxt){\
    if (usbStatus == "Connected") {\
      $("#Trace-In-Progress").removeClass("hidden");\
    } else {\
      $("#tracing-PopUp-usb-not-connected").modal();\
    }\
  });\
});\
\
$("#tracetool-usb-ok, #tracetool-intf-not-up").click(function(){\
  $("#content").load("/modals/status-support/diagnosticUtility.lp");\
});\
\
var interval;\
var target = "modals/status-support/diagnosticUtility.lp";\
//AJAX Request to get result dynamically.\
function getstatus(target) {\
  $.get(target+"?action=tracing",function(responseTxt, status, xhr) {\
    if (responseTxt.status == "completed"){\
      $("#Alert-unplug-usb").addClass("hidden");\
      $("#tracetool-btn-start").prop("disabled", false).removeClass("op40");\
      clearInterval(interval);\
    }\
  });\
}\
\
$("#traceInprogress").click(function(){\
  $("#tracetool-btn-start").prop("disabled", true).addClass("op40");\
  $("#Trace-In-Progress").addClass("hidden");\
  $("#tracing-PopUp-usb-not-connected").modal("hide");\
  $("#Alert-unplug-usb").removeClass("hidden");\
  interval = setInterval(function(){ getstatus(target) }, 5000);\
});\
\
$("#global-btn-stop").click(function(event){\
  clearInterval(interval);\
  var post_param = new Array(\
    { name : "action", value : "SAVE" },\
    { name : "CSRFtoken", value : "');  ngx.print(CSRFtoken); ngx.print('" },\
    { name : "startCapture", value : "stop" });\
  $.post(target, post_param);\
  $("#Alert-unplug-usb").addClass("hidden");\
  $("#tracetool-btn-start").prop("disabled", false).removeClass("op40");\
  event.stopImmediatePropagation();\
});\
</script>\
'); 
