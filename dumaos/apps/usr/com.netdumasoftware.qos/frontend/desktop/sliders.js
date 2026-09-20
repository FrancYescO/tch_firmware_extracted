/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
 * Iain Fraser <iainf@netduma.com>
*/
<%
require "libos"
local platform = os.platform_information()
%>
(function (context) {

var packageId = "com.netdumasoftware.qos";
var dumaAlert = $("duma-alert", context)[0];
var loaderDilaog = $("#sliders-loader-dialog", context)[0];1

// upload, download
var maxBandwidthSpeeds = [100,100];

var dialogBoxHistory = {};
function rateLimitShowDialogBox(id) {

  var now = new Date();

  if (
    typeof dialogBoxHistory[id] === "undefined" ||
    (now - dialogBoxHistory[id] > 5 * 1000)
  ) {

    $("#" + id, context)[0].open(
      null, 

      [{ text: "<%= i18n.gotIt %>", action: "confirm", callback: function(){
          dialogBoxHistory[id] = new Date();
        }
      }],
      {
        enabled: true,
        packageId: qos.getPackageId(),
        id: id
      }
    )
  
  }
}

function devicePrioritisationUnchanged( callback ) {
  function is_reset( a ){
    var x = JSON.parse( a );
    if( !x.children || !x.children.length ) return true;

    var last = x.children[0].normprop;
    for( var i = 0; i < x.children.length; i++ ){
      if( last != x.children[i].normprop ) return false;
    }
    return true;
  }

  qos.getBandwidthDistribution( function( a, b ){
    callback( is_reset( a ) && is_reset( b ) );
  })
  return false;
}

function setQoSAutoSetupDisabled(){
  var applyWhen = parseInt($("#atstate", context).prop("selected"));
  $("qos-auto-setup",context).find("#auto-setup-button").prop("disabled",applyWhen === 3);
}

function onAntiBufferbloatStateChange() {
  
  var upload = $("#upload-slider", context).prop("value");
  var download = $("#download-slider", context).prop("value");
  var applyWhen = parseInt($("#atstate", context).prop("selected"));
  
  setQoSAutoSetupDisabled();

  switch (applyWhen) {
    case 1:
      if (upload == 100 && download == 100) {
        rateLimitShowDialogBox("sliders-always-100");
      } else {
        rateLimitShowDialogBox("sliders-always-not-100");
      }
      break;
    case 2:
      if (upload == 100 && download == 100) {
        rateLimitShowDialogBox("sliders-hpt-100");
      } else {
        rateLimitShowDialogBox("sliders-hpt-not-100");
      }
      break;
    case 3:
      devicePrioritisationUnchanged( function( unchanged ) {
        if( unchanged ) {
          rateLimitShowDialogBox("sliders-never-unchanged");
        } else {
          rateLimitShowDialogBox("sliders-never-changed");
        }
      });
      break;
  }
}

function pollQosStatus() {
  long_rpc_promise(packageId, "application_status", [])
    .then(function (ready) {
      if (JSON.parse(ready)) {
        $("paper-toast", context)[0].close();
      } else {
        $("paper-toast", context)[0].open();
      }
    });
}

function setSliders(up, down) {
  $("#download-slider", context).prop("value", down * 100);
  $("#upload-slider", context).prop("value", up * 100);
  var autoSetup = $("#auto-setup-require",context)[0];
  if(autoSetup){
    autoSetup.callback = function(){
      var setup = $(this).find("qos-auto-setup")[0];
      setup.download = down * 100;
      setup.upload = up * 100;
      setup.callback = function(upload,download){
        $("#upload-slider", context)[0].value = upload * 100;
        $("#download-slider", context)[0].value = download * 100;
        updateBandwidthAndThrottle(false);
        setAchievableBandwidthNumbers();
      }
      setQoSAutoSetupDisabled();
    }
  }
}

function setBandwidth(up, down) {
  maxBandwidthSpeeds[0] = up;
  maxBandwidthSpeeds[1] = down;
  setAchievableBandwidthNumbers();
}

function updateBandwidthAndThrottle(isband) {
  var rpc_set_throttle = create_rate_limit_long_rpc_promise( 
                                  qos.getPackageId(), "set_link_throttle", 1000 );

  var nan = function(val,def) { return isNaN(val) ? (def || 100) : val; }
  var up_throttle = nan( $("#upload-slider", context).prop("value") / 100, 1.0);
  var down_throttle = nan( $("#download-slider", context).prop("value") / 100, 1.0);
  <% if platform.vendor == "TELSTRA" then %>
  up_throttle = Math.max(0.5,up_throttle);
  <% end %>
  var promise = Q.all([
    rpc_set_throttle( [
      up_throttle.toString(),
      down_throttle.toString()
    ]),
    <% if platform.odm == "TECHNICOLOR" or platform.model == "SMARTHUB3" then %>
    $(top.document).find("network-speeds")[0]._promiseTchWait()
    <% end %>
  ]);
  
  <% if platform.odm == "TECHNICOLOR" or platform.model == "SMARTHUB3" then %>
  //only on DJA0231 because the _promiseTchWait takes a while
  qos.showLoaderDialog(loaderDilaog, promise);
  <% end %>
  promise.done(function () {
    if (up_throttle < 0.1 || down_throttle < 0.1) {
      dumaAlert.show(
        "<%= i18n.lowAllocationWarning %>",

        [{ text: "<%= i18n.gotIt %>", action: "confirm" }],

        {
          enabled: true,
          packageId: qos.getPackageId(),
          id: "qos-low-throttle-warning"
        }
      );
    }

    if( !isband )
      onAntiBufferbloatStateChange();
  });
}

function setAchievableBandwidthNumbers() {
  $("#download-achievable-bandwidth", context)
    .text(Math.round(
      maxBandwidthSpeeds[1] *
      ($("#download-slider", context).prop("immediateValue") / 100) * 10
    ) / 10);

  $("#upload-achievable-bandwidth", context)
    .text(Math.round(
      maxBandwidthSpeeds[0] *
      ($("#upload-slider", context).prop("immediateValue") / 100) * 10
    ) / 10);

    $("#download-slider",context).attr("aria-label","<%= i18n.ariaLabelDownload %>".format(maxBandwidthSpeeds[1]));
    $("#upload-slider",context).attr("aria-label","<%= i18n.ariaLabelUpload %>".format(maxBandwidthSpeeds[0]));
}

function bindBandwidthChange() {
  $("#download-slider, #upload-slider", context)
    .on("change immediate-value-change", function () {
      $(".qos-device-panel").trigger("bandwidth-total-change", {
        uploadBandwidth: ( maxBandwidthSpeeds[0] * 1000 * 1000 ).toString(),
        downloadBandwidth: ( maxBandwidthSpeeds[1] * 1000 * 1000 ).toString(),
        uploadCap: $("#upload-slider",context).prop("immediateValue"),
        downloadCap: $("#download-slider",context).prop("immediateValue")
      });

      setAchievableBandwidthNumbers();
    }).on("change", function () {
      updateBandwidthAndThrottle(false);
    });
}

function bindGoodputChange() {
  $("#goodput", context).change(function () {
    var promise = long_rpc_promise(qos.getPackageId(), "set_goodput", [
      $("#goodput", context).prop("checked").toString()
    ]);

    qos.showLoaderDialog(loaderDilaog, promise);
    promise.done(function () {
      if ($("#goodput", context).prop("checked")) {
        dumaAlert.show(
          "<%= i18n.goodputEnabledInformation %>",

          [{ text: "<%= i18n.gotIt %>", action: "confirm" }],

          {
            enabled: true,
            packageId: qos.getPackageId(),
            id: "qos-goodput-checked"
          }
        )
      }
    });
  });
}

function setDisabledForAllPanels(state){
  var panels = $("duma-panels")[0].list();
  for(var i = 0; i < panels.length; i++){
    var panel = $(panels[i].element).find("duma-panel")[0];
    if(location.pathname.indexOf("com.netdumasoftware.qos") !== -1){
      panel.disabled = !!state;
      panel.disabledText = "<%= i18n.qosDisabled %>";
    }
  }
}

function bindDisableAll(){
  var packdm = "com.netdumasoftware.devicemanager";

  // set if dpi is enabled
  function SetDPIEnabled(state){
    state = state || false;

    // the rpc previously switched between 0 & 8 when enabling / disabling.
    // something to do with packet byte marks
    var scan_size = 0;
    if(state)
      scan_size = 8;
    var prom = long_rpc_promise(packdm, "set_dpi_settings", [ state, scan_size, 1024 * 1024 ]);
    qos.showLoaderDialog(loaderDilaog, prom);
    setDisableDPI(!state);
  }
  // set if qos is disabled
  function SetQOSDisabled(state){
    state = state || false;
    // re-enable dpi when qos is enabled
    if(!state){
      SetDPIEnabled(true);
    }
    var prom = long_rpc_promise(qos.getPackageId(), "disabled", [ state.toString()]);
    qos.showLoaderDialog(loaderDilaog, prom);
    setDisableQoS(state);
  }

  $("#disableqos", context).change(function () {
    var is = $("#disableqos", context).prop("checked");
    if( is ) {
      $("#disableqos-alert", context)[0].show(null,
        [
          { text: "<%= i18n.cancel %>", action: "dismiss", default: true, callback: function()
            {
              setDisableQoS(false);
            }
           },
          {
            text: "<%= i18n.proceed %>", action: "confirm", callback: function () {
              SetQOSDisabled(true);
           }
          }
        ]
      );
    } else {
      SetQOSDisabled(false);
    }
    setDisabledForAllPanels(is);

  });

  $("#disabledpi", context).change(function () {
    var is = $("#disabledpi", context).prop("checked");
    if( is ) {
      $("#disabledpi-alert", context)[0].show(null,
        [
          { text: "<%= i18n.cancel %>", action: "dismiss", default: true, callback: function()
            {
              setDisableDPI(false);
            }
           },
          {
            text: "<%= i18n.disableAllDPIConfirmButton %>", action: "confirm", callback: function () {
              SetDPIEnabled(false);
           }
          }
        ]
      );
    } else {
      SetDPIEnabled(true);
    }

  });
}

function setGoodput(goodput) {
  $("#goodput", context).prop("checked", goodput);
}

function setDisableDPI(da){
  $("#disabledpi", context).prop("checked", da);
}

function setDisableDPIDisabled(state){
  $("#disabledpi", context).prop("disabled", state || null);
}

function setDisableQoS(da){
  $("#disableqos", context).prop("checked", da);
  setDisabledForAllPanels(da);
  setDisableDPIDisabled(!da);
}

function toggle_sliders( autoThrottle ){
  $("#download-slider", context).prop("disabled", autoThrottle == 3 );
  $("#upload-slider", context).prop("disabled", autoThrottle == 3 );
}

function setAutoThrottle(autoThrottle) {
/*
  $("#auto-throttle", context).prop("checked", autoThrottle);
*/
  $("#atstate", context).prop("selected", autoThrottle );
  toggle_sliders(autoThrottle);
}

function bindAutoThrottle() {
/*
  $("#auto-throttle", context)
    .change(function() {
      var is = JSON.stringify( $("#auto-throttle", context).prop("checked") );
      var promise = long_rpc_promise(packageId, "auto_throttling", [ is ]);
      qos.showLoaderDialog(loaderDilaog, promise);
      
      promise.done(function () {
        if (!$("#auto-throttle", context).prop("checked")) {
          dumaAlert.show(
            "You have chosen to disable Auto Anti-Bufferbloat. The " +
            "percentages (%) on your Anti-Bufferbloat will now always " +
            "be applied, regardless of whether the router is detecting " +
            "high priority traffic, such as games. Re-enable this option " +
            "if you would prefer for these percentages to only take effect " +
            "when high priority traffic is detected.",

            [{ text: "Got it", action: "confirm" }],

            {
              enabled: true,
              packageId: qos.getPackageId(),
              id: "qos-auto-anti-bufferbloat"
            }
          );
        }
      });
    });
*/
  
  $("#atstate", context).on("iron-select", function () {
    var at = $("#atstate", context).prop("selected");
    var jat = JSON.stringify( at );
    var promise = long_rpc_promise(packageId, "auto_throttling", [ jat ]);
    qos.showLoaderDialog(loaderDilaog, promise);
    promise.done(function () {
      toggle_sliders( parseInt(at ) );
      onAntiBufferbloatStateChange();
    });
  });
}

function bindGlobalNetworkDialog(){
  $("html").on("network-speeds-changed",function(e){
    var data = e.detail;
    setBandwidth(data.up,data.down);
    setAchievableBandwidthNumbers();
  });
}

function bindSetNetworkSpeedsButton(){
  $("#show-network-speeds-dialog",context).on("click",function(){
    $(top.document).find("#network-speeds-button").click();
  })
}

Q.spread([
  qos.getThrottle(),
  qos.getBandwidth(),
  long_rpc_promise(qos.getPackageId(), "get_goodput", []),
  long_rpc_promise(packageId, "auto_throttling", []),
  long_rpc_promise(qos.getPackageId(), "disabled", []),
  long_rpc_promise("com.netdumasoftware.devicemanager", "get_dpi_settings", []),
], function (throttle, bandwidth, goodput, autoThrottle, da, dpi) {
  setSliders(throttle[0], throttle[1]);
  setBandwidth(bandwidth[0] / (1000 * 1000), bandwidth[1] / (1000 * 1000));
  bindGlobalNetworkDialog();
  bindSetNetworkSpeedsButton();
  setAutoThrottle(JSON.parse(autoThrottle[0]));
  setGoodput(goodput[0] === "true");
  setDisableQoS(da[0] === "true");
  setDisableDPI(dpi[0].enabled != true);
  setAchievableBandwidthNumbers();
  bindBandwidthChange();
  bindGoodputChange();
  bindAutoThrottle();
  bindDisableAll();

  pollQosStatus();
  setInterval(pollQosStatus, 1000 * 15);
  
  setQoSAutoSetupDisabled();

  $("duma-panel", context).prop("loaded", true);
  
  if( da[0] == "true" ){
    $("#disabled-on-init", context)[0].open( null, [{ text: "Got it", action: "confirm" }] );
  }
}).done();

})(this);

//# sourceURL=sliders.js
