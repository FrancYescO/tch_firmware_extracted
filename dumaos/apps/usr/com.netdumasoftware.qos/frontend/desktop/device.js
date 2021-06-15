/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
*/

<%
require "libos"
local platform = os.platform_information()
local showUpload = platform.vendor ~= "TELSTRA"
%>

(function (context) {

// Variables
var devicePanel = $("duma-panel", context)[0];
var devicePanel_is_enabled = false;
var loaderDialog = $("#device-loader-dialog", context)[0];
var data = devicePanel.data;
var directionIndex = data.direction === "upload" ? 0: 1;
var throttle = null;
var bandwidth = null;
var flower_tree = null;

// Helpers
function has_correct_domain(domain) {
  return data.parentNodeDomain === domain;
}

function doesVariableExist(variable) {
  return variable === undefined || variable === null;
}

function findDevice(tree, id) {
  if (tree.id == id) {
    return tree;
  } else if (tree.children) {
    for (var i = 0; i < tree.children.length; i++) {
      var v = findDevice(tree.children[i], id);
      if (v) {
        return v;
      }
    }
  }
}

function setInputValue(proportion) {
  $("#device-bandwidth-input", context)
    .prop(
      "value",
      Math.round((
        (
          bandwidth[directionIndex] *
          throttle[directionIndex] *
          (proportion / 100)) /
          (1000 * 1000)) *
          100
      ) / 100
    ).attr("max", (bandwidth[directionIndex] * throttle[directionIndex]) / (1000 * 1000));
};

// Event listeners
function device_bandwidth_input_on_change() {
  if (!$(this).prop("invalid")) {
    $(devicePanel).trigger("device-distribution-update", {
      id: data.id,
      proportion: (
        ($(this).prop("value") * 1000 * 1000) /
        (bandwidth[directionIndex] * throttle[directionIndex])
      ) * 100,
      direction: data.direction,
      flag: "device"
    });
  }
}

function device_panel_bandwidth_total_change(e,data) {
  throttle[0] = data.uploadCap / 100;
  throttle[1] = data.downloadCap / 100;

  bandwidth[0] = data.uploadBandwidth;
  bandwidth[1] = data.downloadBandwidth;

  setInputValue(
    $("#bandwidth-selector", context).val().replace(/%/g, "")
  );
}

function device_panel_device_distribution_update(e,eventData) {
  if (
    data.id == eventData.id &&
    eventData.direction == data.direction &&
    eventData.proportion != $("#bandwidth-selector", context).val().replace(/%/g, "")
  ) {
    $("#bandwidth-selector", context).val(eventData.proportion).trigger("change");
    setInputValue(eventData.proportion);
  }
}

// Use a variable to hold the true event since we can't reconfigure a .knob() element
var _bandwidth_selector_on_change = null;

function bandwidth_selector_on_change(value) {
  if (value > 100) {
    value = 100;
    this.$
      .val(100)
      .trigger("change");
  }

  $("#qos-flower-panel").trigger("device-distribution-update",{
    id: data.id, value: value, direction: data.direction
  });

  setInputValue(value);
}

function update_button_on_click() {
  var distribution = [
    flower_tree.get_upload_tree(),
    flower_tree.get_download_tree()
  ];

  var set = distribution[directionIndex].children;
  var el = findDevice(distribution[directionIndex], data.id);
  var before = el.normprop;
  var after = $("#bandwidth-selector", context).val().replace(/%/g, "") / 100;
  var delta = after - before;

  // calculate how much to move others
  var borrow = -delta;
  
  // update all nodes
  var n = set.length;
  var hungry = n > 0 ? n - 1 : 1;
  while( Math.abs( borrow ) > 0.00001 && hungry > 0 ) {
    var share =  borrow / hungry;     
    hungry = 0; 
    set = set.map( function( d, ii ){
      if( d.id == el.id ){
        d.normprop = after;  
        return d;
      }
       
      var used = 0;
      if( d.normprop + share < 0 ){
        used = -d.normprop;
        d.normprop = 0;
      } else {
        d.normprop += share;
        used = share;
        hungry++;
      } 

      borrow -= used;
      return d;
    });    
  }

  distribution[directionIndex].children = set;
  qos.saveDistribution(loaderDialog, distribution[0], distribution[1]);
  $(devicePanel).on("device-distrubution-update", {
    id: data.id,
    proportion: (
      ($("#device-bandwidth-input", context).prop("value") * 1000 * 1000) /
      (bandwidth[directionIndex] * throttle[directionIndex])
    ) * 100,
    direction: data.direction,
    flag: "device-save"
  });
}

// Enables device panel & sets up appropriate event listeners
function enable_device_panel() {
  $("#flower-panel").trigger("node-change-request");
  
  $("#error",context).hide();
  $("#device-bandwidth-input",context).show();
  $("#bandwidth-selector-div",context).show();
  $("#update-button",context).show();

  devicePanel.header = flower_tree.get_node_name(data.id)
  <% if showUpload then %>
    + " - " + captalise_first_letter(data.direction);
  <% end %>

  if (data.direction === "download") {
    $("#bandwidth-selector", context).val(flower_tree.get_download_node(data.id).normprop * 100.0).trigger("change");
  } else {
    $("#bandwidth-selector", context).val(flower_tree.get_upload_node(data.id).normprop * 100.0).trigger("change");
  }

  $("#device-bandwidth-input",context).change(device_bandwidth_input_on_change);
  $(devicePanel).on("bandwidth-total-change",device_panel_bandwidth_total_change);
  $(devicePanel).on("device-distribution-update",device_panel_device_distribution_update);

  setInputValue($("#bandwidth-selector",context).val().replace(/%/g, ""));

  _bandwidth_selector_on_change = bandwidth_selector_on_change;
  $("#update-button",context).click(update_button_on_click);

  devicePanel_is_enabled = true;
}

// Hide device panel, detach any event listeners and prompt the user with an error
function disable_device_panel() {
  devicePanel.header = "";

  $("#error",context).show();
  $("#error-message",context).html(data.domain === "devices" ? "<%= i18n.deviceError %>": "<%= i18n.applicationError %>");

  $("#device-bandwidth-input",context).hide();
  $("#bandwidth-selector-div",context).hide();
  $("#update-button",context).hide();

  if (devicePanel_is_enabled) {
    $("#device-bandwidth-input",context).off("change");
    $(devicePanel).off("bandwidth-total-change");
    $(devicePanel).off("device_distribution-update");
    _bandwidth_selector_on_change = null;
    $("#update-button",context).off("click");
  }

  devicePanel_is_enabled = false;
}

Q.spread([
  qos.getThrottle(),
  qos.getBandwidth(),
  qos.get_flower_tree()
], function (_throttle,_bandwidth,_flower_tree) {
  
  // Init
  throttle = _throttle;
  bandwidth = _bandwidth;
  flower_tree = _flower_tree;

  // Create JQuery knob for bandwidth selector
  $("#bandwidth-selector", context).knob({
    angleOffset: "-145",
    angleArc: "290",
    step: "0.01",
    fgColor: "<%= theme.PRIMARY_COLOR %>",
    inputColor: "<%= theme.PRIMARY_TEXT_COLOR %>",
    font: "'Roboto', 'Noto', sans-serif",
    bgColor: "rgba(18, 2, 3, 0.5)",
    thickness: "0.25",
    scroll: false,
    width: "100%",

    format: function (value) {
      return Math.round(value) + "%";
    },

    change: function(value) {
      if (_bandwidth_selector_on_change) {
        _bandwidth_selector_on_change.call(this,value);
      }
    },

    draw: function() {
      $(this.i)
        .css("font-size", "24px")
        .css("border", "none")
        .css("outline", "none")
        .css("height", "42px")
        .css("margin", "auto")
        .css("top", "0")
        .css("right", "0")
        .css("bottom", "0")
        .css("left", "0");
    }  
  });

  // Listen for domain changes from the flower panel
  $(devicePanel).on("flower_panel_domain_change",function(data,domain) {
    flower_tree.set_domain(domain);

    if (has_correct_domain(domain) && !devicePanel_is_enabled) {
      enable_device_panel();
    } else if (!has_correct_domain(domain) && devicePanel_is_enabled) {
      disable_device_panel();
    }
  });

  // Check if our configured domain matches what is visible in the flower
  if (has_correct_domain(flower_tree.get_domain())) {
    enable_device_panel();
  } else {
    disable_device_panel();
  }

  // no context as other panel
  var tree = $("#device-tree");
  if(tree[0]){
    $("#back-to-categories",context).on('tap',function(){
      var treeItem = tree.find("paper-tree-node.selected .node-row .node-name")[0];
      if(treeItem){
        treeItem.focus();
        devicePanel.close();
      }
    });
  }else{
    $("#back-to-categories",context).remove();
  }

  devicePanel.loaded = true;
  $("#device-bandwidth-input input", context).focus();
}).done();

})(this);

//# sourceURL=device.js
