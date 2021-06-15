/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
*/

<%
require "libos"
local showUpload = os.platform_information().vendor ~= "TELSTRA"
%>

(function (context) {

var flowerPanel = $("#qos-flower-panel", context)[0];
var loaderDialog = $("#flower-loader-dialog", context)[0];
var dumaAlert = $("#flower-duma-alert", context)[0];
var flower_tree = null;

function doesVariableExist(variable) {
  if (typeof variable === "undefined" || variable === null) {
    return false;
  } else {
    return true;
  }
}

function flowerDistributionConversion(nodes) {
  var tree;

  for (var i = 0; i < nodes.length; i++)  {
    var node = nodes[i];
    if (!doesVariableExist(tree)) {
      tree = node.data.parentNode;
      tree.children = [];
    }

    tree.children.push({
      id: node.data.id,
      domain: node.data.domain,
      share_excess: node.data.share_excess,
      normprop: node.mag / 100,
      children: node.data.children
    });
  }

  return tree;
}

function resetFlower() {
  var nodes = $("#device-flower", context)[0].data;
  var equalProportion = 100 / nodes.length;

  for (var i = 0; i < nodes.length; i++) {
    nodes[i].mag = equalProportion;
  }

  $("#device-flower", context)[0].data = nodes.slice();
  onNodeChange();

  return equalProportion;
}

function getNodeTitle(parentNodeDomain, nodeDomain, id, devices) {
  if (nodeDomain === "devices") {
    return "<%= i18n.devices %>";
  } else if (nodeDomain === "appcat") {
    return "<%= i18n.applications %>";
  } else if (!doesVariableExist(nodeDomain) && (parentNodeDomain === "devices" || parentNodeDomain === "appcat")) {
    return flower_tree.get_node_name(id);
  }
}

function getNodeIcon(parentNodeDomain, nodeDomain, id, devices)
{
  if (!doesVariableExist(nodeDomain))
  {
    if (parentNodeDomain == "devices")
      return duma.devices.get_devices_icon(devices[id].type.toLowerCase());
    else if (parentNodeDomain == "appcat")
      return duma.applications.get_application_icon(devices[id]);
  }
  else if (nodeDomain == "devices")
    return duma.devices.get_devices_icon("other");
  else if (nodeDomain == "appcat")
    return duma.applications.get_application_icon("categories")
}

function generateDeviceTree(node, devices) {
  var process = function (node, parentNodeDomain) {
    if (!doesVariableExist(node)) {
      return;
    }
    
    var output = {
      name: getNodeTitle(parentNodeDomain, node.domain, node.id, devices),
      data: {
        id: node.id,
        domain: node.domain,
        proportion: node.normprop,
        parentNodeDomain: parentNodeDomain
      },
      icon: getNodeIcon(parentNodeDomain, node.domain, node.id, devices)
    };
    if(node.domain === "appcat")
      output.help = true;

    if (doesVariableExist(node.children) && node.children.length > 0) {
      output.children = [];
      for (var i = 0; i < node.children.length; i++)  {
        output.children.push(process(node.children[i], node.domain));
      }
    }

    return output;
  };

  var processedNode = process(node);
  processedNode.open = true;

  return processedNode;
}

function generateDistributionFlower(node, devices) {
  if (!doesVariableExist(node.children)) {
    return;
  }

  var distributionFlower = [];
  for (var i = 0; i < node.children.length; i++) {
    var child = node.children[i];

    distributionFlower.push({
      name: getNodeTitle(node.domain, child.domain, child.id, devices),
      mag: child.normprop * 100,
      data: {
        parentNode: node,
        id: child.id,
        domain: child.domain,
        children: child.children,
        share_excess: child.share_excess
      }
    });
  }

  return distributionFlower;
}

function loadDeviceTree(distribution, devices) {
  $("#device-tree", context)[0].data = generateDeviceTree(distribution, devices);
}

function loadDeviceFlower(distribution, devices) {
  $("#device-flower", context)[0].data = generateDistributionFlower(distribution, devices);
}

function bindDeviceTreeClick() {
  var devicePanel = null;

  $("#device-tree", context).on("select", function (e) {
    var data = e.detail.data.data;
    
    data.direction = getSelectedDirection();
    
    if (data.domain == "devices" && devicePanel !== true && devicePanel) {
      qos.removePanel(devicePanel);
      qos.updatePanel(flowerPanel, {width: 12});
      devicePanel = null;
      return;
    }

    if (
      typeof(data.id) == "undefined" ||
      flowerPanel.desktop || // Flags if we're on the dashboard
      devicePanel === true
    ) {
      return;
    }
    
    if (devicePanel) {
      qos.removePanel(devicePanel);
    }

    devicePanel = true;
    
    qos.updatePanel(flowerPanel, {width: 8}); 

    qos.addPanel("device.html", data, {
      x: 8, y: 7, width: 4, height: 20,
      initialisationCallback: function (panel) {

        setTimeout(function () {
          onNodeChange();
        });
        
        devicePanel = panel;

        $(devicePanel).one("closeClick", function () {
          qos.updatePanel(flowerPanel, {width: 12});
          devicePanel = null;
        });
      }
    });
  });
}

function updateNode(id, proportion, direction, flag) {
  var index = idMap(id, $("#device-flower", context)[0].data);
  if (
    flag != "flower" &&
    direction === getSelectedDirection() &&
    $("#device-flower", context)[0].data[index].mag != proportion
  ) {
    $("#device-flower", context)[0].update_node(index, proportion);
  }
}

function onNodeChange() {
  var flowerData = $("#device-flower", context)[0].data;
  for (var i = 0; i < flowerData.length; i++) {
    $(".qos-device-panel").trigger("device-distribution-update", {
      id: flowerData[i].data.id,
      proportion: flowerData[i].mag,
      direction: getSelectedDirection(),
      flag: "flower"
    });
  }
}

function idMap(id, flower) {
  for (var i = 0; i < flower.length; i++) {
    var v = flower[i];
    if (v.data.id == id) {
      return i;
    }
  }
}

function setShareExcess(uploadTree, downloadTree, devices) {
  switch (getSelectedDirection()) {
    case "download":
      $("#share-excess-up", context).prop("checked", uploadTree.share_excess);
      $("#share-excess-down", context).prop("checked", downloadTree.share_excess);
      loadDeviceTree(downloadTree, devices);
      loadDeviceFlower(downloadTree, devices);
      break;
    case "upload":
      $("#share-excess-up", context).prop("checked", uploadTree.share_excess);
      $("#share-excess-down", context).prop("checked", downloadTree.share_excess);
      loadDeviceTree(uploadTree, devices);
      loadDeviceFlower(uploadTree, devices);
      break;
  }
}

function setPanelHeader(download) {
  <% if showUpload then %>
    flowerPanel.header = "<%= i18n.bandwidthAllocation %> - " + (download === "download" ? "<%= i18n.download %>" : "<%= i18n.upload %>");
  <% else %>
    flowerPanel.header = "<%= i18n.bandwidthAllocation %>"
  <% end %>
}

function setAllocationAlgorithm(upload, download) {
  switch (getSelectedDirection()) {
    case "download":
      $("#allocation-algorithm", context).prop("selected", download);
      break;
    case "upload":
      $("#allocation-algorithm", context).prop("selected", upload);
      break;
  }
}

function saveAllocationAlgorithm(uploadAlgorithm, downloadAlgorithm) {
  var promise = long_rpc_promise(qos.getPackageId(), "set_hierarchy_algo", [
    uploadAlgorithm,
    downloadAlgorithm
  ]);

  qos.showLoaderDialog(promise);
  promise.done();
}

function loadSavedSettings() {
  var direction = duma.storage(qos.getPackageId(), "direction");
  direction = direction ? direction : "download";

  <% if showUpload then %>
  $("#direction-radio", context).prop("selected", direction);
  <% end %>
}

function show_share_excess_disabled_warning() {
	dumaAlert.show(
		"<%= i18n.shareExcessDisabledWarning %>",
		[{text: "<%= i18n.gotIt %>", action: "confirm"}],
		{enabled: true, packageId: qos.getPackageId(), id: "qos-restrictive-device-warning"}
	);
}

function show_share_excess_enabled_warning() {
	dumaAlert.show(
		"<%= i18n.shareExcessEnabledInformation %>",
		[{ text: "<%= i18n.gotIt %>", action: "confirm" }],
		{enabled: true, packageId: qos.getPackageId(), id: "qos-share-excess-enabled"}
	);
}

function getSelectedDirection()
{
  <% if showUpload then %>
    return $("#direction-radio", context).prop("selected");
  <% else %>
    return "download"
  <% end %>
}

// Check if a tree has a device or appcat with no
// bandwidth when share-excess is disabled.
function check_if_device_restricted(flower_tree,direction) {
	var download_tree = flower_tree.get_download_tree();
	var upload_tree = flower_tree.get_upload_tree();
	
	if (!download_tree.share_excess) {
		var children = download_tree.children;

		for (var i = 0; i < children.length; ++i) {
			if (!children[i].normprop) {
				show_share_excess_disabled_warning();
				return;
			}
		}
	}

	if (!upload_tree.share_excess) {
		var children = upload_tree.children;

		for (var i = 0; i < children.length; ++i) {
			if (!children[i].normprop) {
				show_share_excess_disabled_warning();
			}
		}
	}
}

loadSavedSettings();

Q.spread([
  qos.get_flower_tree(),
  long_rpc_promise(qos.getPackageId(), "get_hierarchy_algo", [])
], function (_flower_tree, allocationAlgorithm) {
  flower_tree = _flower_tree;

  var uploadAlgorithm = allocationAlgorithm[0];
  var downloadAlgorithm = allocationAlgorithm[1];
  var message_bus = qos.message_bus;

  setShareExcess(
    flower_tree.get_upload_tree(),
    flower_tree.get_download_tree(),
    flower_tree.get_domain_list()
  );

  setAllocationAlgorithm(uploadAlgorithm,downloadAlgorithm);

  function extract_flower_data(tree) {
    var flower_nodes = $("#device-flower",context)[0].data;

    for (var i = 0; i < flower_nodes.length; ++i) {
      var node = flower_nodes[i];
      var id = node.data.id;
      var normprop = node.mag * 0.01;

      for (var j = 0; j < tree.children.length; ++j) {
        var child = tree.children[i];

        if (child.id === id) {
          child.normprop = normprop;
          break;
        }
      }
    }
  }

  // returns the checkbox status for share excess of the currently visible flower (upload or download)  
  function update_distribution() {
    var share_excess_up = $("#share-excess-up",context)[0];
    var share_excess_down = $("#share-excess-down",context)[0];

    flower_tree.get_download_tree().share_excess = share_excess_down.checked;
    if(share_excess_up)
      flower_tree.get_upload_tree().share_excess = share_excess_up.checked;

    if (getSelectedDirection() === "download") {
      extract_flower_data(flower_tree.get_download_tree());
    } else {
      extract_flower_data(flower_tree.get_upload_tree());
    }
  }

  var device_panel = null;
  var device_panel_is_loading = false;
  
  $("#device-tree", context).on("help", function (e) {
    var services = $(top.document).find("#services-info")[0];
    if(services) services.open();
  });

  $("#device-tree", context).on("select", function (e) {
    // Works only if we aren't pinned to the dashboard
    if (!flowerPanel.desktop) {
      var data = e.detail.data.data;

      data.direction = getSelectedDirection();

      /*
        close an open device panel if,
          - The user clicks on "Applications" or "Devices" depending on the domain
          - We have an open panel that isn't in the middle of loading
      */
      if ((data.domain === "appcat" || data.domain === "devices") && device_panel && !device_panel_is_loading) {
        qos.removePanel(device_panel);
        qos.updatePanel(flowerPanel,{width: 12});
        
        device_panel = null;

        return;
      }

      if (data.id === undefined || device_panel_is_loading) {
        return;
      }

      if (device_panel) {
        qos.removePanel(device_panel);
        device_panel = null;
      }

      device_panel_is_loading = true;

      qos.updatePanel(flowerPanel,{width: 8});
      qos.addPanel("device.html",data,{
        x: 8,
        y: 7,
        width: 4,
        height: 20,

        initialisationCallback: function(panel) {
          device_panel_is_loading = false;
          device_panel = panel;

          $(device_panel).one("closeClick",function() {
            qos.updatePanel(flowerPanel,{width: 12});
            device_panel = null;
          });
        }
      });
    }
  });

  $("#device-flower", context).on("nodechange", function () {
    onNodeChange();
    update_distribution();
  });

  $(flowerPanel).on("node-change-request", function () {
    onNodeChange();
  });

  $(flowerPanel).on("device-distribution-update",
    function (e, data) {
      var id = data.id;
      var proportion = data.value;
      var direction = data.direction;
      var flag = data.flag;

      updateNode(id, proportion, direction, flag);
      update_distribution();

      if (direction !== getSelectedDirection()) {
        //var tree = direction === "download" ? downloadTree: uploadTree;
        //var nodes = generateDistributionFlower(tree, get_domain_list(tree.domain));
        //$("#device-flower", context)[0].changeNodeMagnitude(id,proportion,nodes);

        switch (direction) {
          case "download":
            //downloadTree = flowerDistributionConversion(nodes);
	    extract_flower_data(flower_tree.get_download_tree());
          break;
          
	  case "upload":
            //uploadTree = flowerDistributionConversion(nodes);
            extract_flower_data(flower_tree.get_upload_tree());
          break;
        }
      }
    }
  );

  $("#update-button",context).click(function() {
    update_distribution();
    flower_tree.save(loaderDialog).done(function() { check_if_device_restricted(flower_tree); });
  });

  $("#reset-button", context).click(function () {
    resetFlower();
    flower_tree.reset();
    update_distribution();
    flower_tree.save(loaderDialog,true).done(function() { check_if_device_restricted(flower_tree); });
  });

  var last_flower_domain = flower_tree.get_domain();

	$("#flower_mode",context)[0].selected = last_flower_domain;
	$("#flower_mode",context).click(function() {
  		var domain = this.selected;

  		if (domain === last_flower_domain) {
  			return;		
  		}

  		last_flower_domain = domain;
      		flower_tree.set_domain(domain);

      		$(".qos-device-panel").trigger("flower_panel_domain_change",[domain]);

  		setShareExcess(
  	   	   	flower_tree.get_upload_tree(),
  	 	     	flower_tree.get_download_tree(),
        		flower_tree.get_domain_list()
      		);
	
	     	if (device_panel) {
		        qos.removePanel(device_panel);
	        	qos.updatePanel(flowerPanel,{width: 12});
	        	device_panel_is_loading = false;
	        	device_panel = null;
      		}
  	}
  );

	$("#share-excess-down",context).click(function() {
		var checked = this.checked;
		
		update_distribution();
		flower_tree.save(loaderDialog).done(function() {
			if (checked) {
				show_share_excess_enabled_warning();
			} else {
				check_if_device_restricted(flower_tree);
			}
		});
	});

	$("#share-excess-up",context).click(function() {
		var checked = this.checked;
		
		update_distribution();
		flower_tree.save(loaderDialog).done(function() {
			if (checked) {
				show_share_excess_enabled_warning();
			} else {
				check_if_device_restricted(flower_tree);
			}
		});
	});

  $("#allocation-algorithm", context).on("iron-select", function () {
    switch (getSelectedDirection()) {
      case "upload":
        uploadAlgorithm = $("#allocation-algorithm", context).prop("selected");
        break;
      case "download":
        downloadAlgorithm = $("#allocation-algorithm", context).prop("selected");
        break;
    }

    saveAllocationAlgorithm(uploadAlgorithm, downloadAlgorithm);
  });

  setPanelHeader(getSelectedDirection());

  <% if showUpload then %>
  $("#direction-radio", context).on("iron-select", function () {
    var direction = getSelectedDirection();
    duma.storage(qos.getPackageId(), "direction", direction);

    setShareExcess(
      flower_tree.get_upload_tree(),
      flower_tree.get_download_tree(),
      flower_tree.get_domain_list()
    );

    setAllocationAlgorithm(uploadAlgorithm, downloadAlgorithm);
    setPanelHeader(getSelectedDirection());
  });
  <% end %>

  flowerPanel.loaded = true;
}).done();

})(this);

//# sourceURL=flower.js
