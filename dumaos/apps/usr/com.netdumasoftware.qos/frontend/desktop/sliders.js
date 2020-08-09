/*
 * (C) 2017 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
 * Iain Fraser <iainf@netduma.com>
*/
<%
require "libos"
local platform = os.platform_information()
%>
(function (context) {

var packageId = "com.netdumasoftware.qos";
var dumaAlert = $("duma-alert", context)[0];
var loaderDilaog = $("#sliders-loader-dialog", context)[0];


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

function onAntiBufferbloatStateChange() {
  
  var upload = $("#upload-slider", context).prop("value");
  var download = $("#download-slider", context).prop("value");
  var applyWhen = parseInt($("#atstate", context).prop("selected"));

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
}

function setBandwidth(up, down) {
  $("#upload-bandwidth", context).prop("value", up);
  $("#download-bandwidth", context).prop("value", down);
}

function updateBandwidthAndThrottle(isband) {
  var rpc_set_bandwidth = create_rate_limit_long_rpc_promise( 
                                  qos.getPackageId(), "set_bandwidth", 1000 );
  var rpc_set_throttle = create_rate_limit_long_rpc_promise( 
                                  qos.getPackageId(), "set_link_throttle", 1000 );

  var nan = function(val,def) { return isNaN(val) ? (def || 100) : val; }
  var up_band = nan( $("#upload-bandwidth", context).prop("value") * (1000 * 1000), 1000000);
  var down_band = nan( $("#download-bandwidth", context).prop("value") * (1000 * 1000), 1000000);
  var up_throttle = nan( $("#upload-slider", context).prop("value") / 100, 1.0);
  var down_throttle = nan( $("#download-slider", context).prop("value") / 100, 1.0);
  var promise = Q.all([
    rpc_set_bandwidth( [
      Math.floor( up_band ),
      Math.floor( down_band )
    ]),
    rpc_set_throttle( [
      up_throttle.toString(),
      down_throttle.toString()
    ])
  ]);

  qos.showLoaderDialog(loaderDilaog, promise);
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
      $("#download-bandwidth", context).prop("value") *
      ($("#download-slider", context).prop("immediateValue") / 100) * 10
    ) / 10);

  $("#upload-achievable-bandwidth", context)
    .text(Math.round(
      $("#upload-bandwidth", context).prop("value") *
      ($("#upload-slider", context).prop("immediateValue") / 100) * 10
    ) / 10);
}

function bindBandwidthChange() {
  $("#download-slider, #upload-slider, #upload-bandwidth, #download-bandwidth", context)
    .on("change immediate-value-change", function () {
      if (
        !$("#download-bandwidth", context).prop("invalid") &&
        !$("#upload-bandwidth", context).prop("invalid")
      ) {

        $(".qos-device-panel").trigger("bandwidth-total-change", {
          uploadBandwidth: ( $("#upload-bandwidth",context).prop("value") * 1000 * 1000 ).toString(),
          downloadBandwidth: ( $("#download-bandwidth",context).prop("value") * 1000 * 1000 ).toString(),
          uploadCap: $("#upload-slider",context).prop("immediateValue"),
          downloadCap: $("#download-slider",context).prop("immediateValue")
        });

        setAchievableBandwidthNumbers();
      }
    }).on("change", function () {
      if (
        !$("#download-bandwidth", context).prop("invalid") &&
        !$("#upload-bandwidth", context).prop("invalid")
      ) {
        var eid = $(this).attr("id");
        var isband = eid == "download-bandwidth" || eid == "upload-bandwidth";
        updateBandwidthAndThrottle(isband);
      }
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

function bindDisableAll(){
  var packdm = "com.netdumasoftware.devicemanager";

  $("#disableall", context).change(function () {
    var is = $("#disableall", context).prop("checked");
    if( is ) {
      $("#disableqos-alert", context)[0].show(null,
        [
          { text: "<%= i18n.cancel %>", action: "dismiss", default: true, callback: function()
            {
              setDisableAll(false);
            }
           },
          {
            text: "<%= i18n.proceed %>", action: "confirm", callback: function () {
              var pa = long_rpc_promise(qos.getPackageId(), "disabled", [ is.toString()]);
              var pb = long_rpc_promise(packdm, "set_dpi_settings", [ false, 0, 1024 * 1024 ]);
              qos.showLoaderDialog(loaderDilaog, Q.all([pa,pb]));
           }
          }
        ]
      );
    } else {
      var pa = long_rpc_promise(qos.getPackageId(), "disabled", [ is.toString()]);
      var pb = long_rpc_promise(packdm, "set_dpi_settings", [ true, 8, 1024 * 1024 ]);
      qos.showLoaderDialog(loaderDilaog, Q.all([pa,pb]));
    }

  });
}

function bindOptUpload(start){
  var optUploadCheck = $("#optimiseUpload",context);
  var uploadSlider = $("#upload-slider",context);
  optUploadCheck.prop("checked",start);
  optUploadCheck.on("checked-changed",function(e){
    optUploadCheck.prop("disabled",true);
    uploadSlider.prop("disabled",true);
    var promise = long_rpc_promise(qos.getPackageId(), "throttle_upstream_hw", [e.detail.value]);
    qos.showLoaderDialog(loaderDilaog, promise);
    promise.done(function(){
      uploadSlider.prop("disabled",!e.detail.value);
      optUploadCheck.prop("disabled",false);
    });
  });
  uploadSlider.prop("disabled",!start);
}

function setGoodput(goodput) {
  $("#goodput", context).prop("checked", goodput);
}

function setDisableAll(da){
  $("#disableall", context).prop("checked", da);
}

function toggle_sliders( autoThrottle ){
  $("#download-slider", context).prop("disabled", autoThrottle == 3 );
  <% if platform.vendor ~= "TELSTRA" then %>
  $("#upload-slider", context).prop("disabled", autoThrottle == 3 );
  <% end %>
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

Q.spread([
  qos.getThrottle(),
  qos.getBandwidth(),
  long_rpc_promise(qos.getPackageId(), "get_goodput", []),
  long_rpc_promise(packageId, "auto_throttling", []),
  long_rpc_promise(qos.getPackageId(), "disabled", []),
  <% if platform.vendor == "TELSTRA" then %>
  long_rpc_promise(qos.getPackageId(), "throttle_upstream_hw", []),
  <% end %>
], function (throttle, bandwidth, goodput, autoThrottle, da, optUpload) {
  setSliders(throttle[0], throttle[1]);
  setBandwidth(bandwidth[0] / (1000 * 1000), bandwidth[1] / (1000 * 1000));
  setAutoThrottle(JSON.parse(autoThrottle[0]));
  setGoodput(goodput[0] === "true");
  setDisableAll(da[0] === "true");
  setAchievableBandwidthNumbers();
  bindBandwidthChange();
  bindGoodputChange();
  bindAutoThrottle();
  bindDisableAll();
  <% if platform.vendor == "TELSTRA" then %>
  bindOptUpload(optUpload[0]);
  <% end %>

  pollQosStatus();
  setInterval(pollQosStatus, 1000 * 15);

  $("duma-panel", context).prop("loaded", true);
  
  if( da[0] == "true" ){
    $("#disabled-on-init", context)[0].open( null, [{ text: "Got it", action: "confirm" }] );
  }
}).done();

})(this);

//# sourceURL=sliders.js
