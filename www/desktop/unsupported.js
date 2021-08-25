/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
*/

var packageId = "com.netdumasoftware.settings";

function bindWanProtocolChange() {
  $("input[name=protocol]").change(function () {
    $("input[name=protocol]").each(function () {
      if ($(this).is(":checked")) {
        $("#" + $(this).attr("data-content")).removeClass("hidden");
      } else {
        $("#" + $(this).attr("data-content")).addClass("hidden");
      }
    }); 
  });
}

function setProtocol(protocol) {
  $("input[name=protocol]").each(function () {
    if ($(this).val() == protocol) {
      $(this).prop("checked", true);
      $("#" + $(this).attr("data-content")).removeClass("hidden");
    } else {
      $("#" + $(this).attr("data-content")).addClass("hidden");
    }
  }); 
}

function setLanSettings(ip, subnet) {
  $("#lan-ip").val(ip);
  $("#lan-subnet").val(subnet);
}

function setDns(dns) {
  if (dns) {
    $("#custom-dns").prop("checked", true);
    $("#primary-dns").val(dns.primary).prop("disabled", false);
    $("#secondary-dns").val(dns.secondary).prop("disabled", false);
  }

  $("#custom-dns").change(function () {
    $("#primary-dns").prop("disabled", !$(this).is(":checked"));
    $("#secondary-dns").prop("disabled", !$(this).is(":checked"));
  });
}

function setStatic(details) {
  $("#wan-static-ip").val(details.ip);
  $("#wan-static-subnet").val(details.subnet_mask);
  $("#wan-static-gateway").val(details.default_gateway);
}

function setPpoe(details) {
  $("#wan-ppoe-username").val(details.username);
  $("#wan-ppoe-password").val(details.password);
}

function validateIpAddress(ip, parts) {
  if (typeof(parts) == "undefined") {
    parts = [null, null, null, null];
  }

  var ip = ip.split(".");
  if (ip.length != 4) {
    return false;
  }

  for (var i = 0; i < ip.length; i++) {
    if (ip[i] == "" || Number(ip[i]) === NaN
        || ip[i] > 255 || ip[i] < 0 || (parts[i] && parts[i] != ip[i])) {
      return false;
    }
  }

  return true;
}

function getWanProtocol() {
  var wanProtocol;
  $("input[name=protocol]").each(function () {
    if ($(this).is(":checked")) {
      wanProtocol = $(this).val();
    }
  });

  return wanProtocol;
}

function validateForm() {
  var valid = true;
  if (validateIpAddress($("#lan-ip").val(), ["192", "168", null, null])) {
    $("#lan-ip").removeClass("invalid");
  } else {
    $("#lan-ip").addClass("invalid");
    valid = false; 
  }
  
  if (validateIpAddress($("#lan-subnet").val())) {
    $("#lan-subnet").removeClass("invalid");
  } else {
    $("#lan-subnet").addClass("invalid");
    valid = false; 
  }
  
  if (getWanProtocol() == "static") {
    var subnet = $("#lan-ip").val().split(".");
    if (subnet.length == 4) {
      subnet[3] = null;
    } else {
      subnet = [null, null, null, null];
    }

    if (validateIpAddress($("#wan-static-ip").val(), subnet)) {
      $("#wan-static-ip").removeClass("invalid");
    } else {
      $("#wan-static-ip").addClass("invalid");
      valid = false;
    }

    if (validateIpAddress($("#wan-static-subnet").val())) {
      $("#wan-static-subnet").removeClass("invalid");
    } else {
      $("#wan-static-subnet").addClass("invalid");
      valid = false;
    }
    
    if (validateIpAddress($("#wan-static-gateway").val())) {
      $("#wan-static-gateway").removeClass("invalid");
    } else {
      $("#wan-static-gateway").addClass("invalid");
      valid = false;
    }
  }

  if ($("#custom-dns").is(":checked")) {
    if (validateIpAddress($("#primary-dns").val())) {
      $("#primary-dns").removeClass("invalid");
    } else {
      $("#primary-dns").addClass("invalid");
      valid = false;
    }
    
    if (validateIpAddress($("#secondary-dns").val())) {
      $("#secondary-dns").removeClass("invalid");
    } else {
      $("#secondary-dns").addClass("invalid");
      valid = false;
    }
  }

  return valid;
}

function bindSaveSettings() {
  $("#settings-form").submit(function (e) {
    e.preventDefault();
    
    if (!validateForm()) {
      return;    
    }
  
    var promises = [];

    promises.push(long_rpc_promise(
      packageId,
      "set_lan_default_gateway",
      [$("#lan-ip").val()]
    ));
    
    promises.push(long_rpc_promise(
      packageId,
      "set_lan_subnet_mask",
      [$("#lan-subnet").val()]
    ));

    if ($("#custom-dns").is(":checked")) {
      promises.push(long_rpc_promise(
        packageId,
        "set_dns_servers",
        [$("#primary-dns").val(), $("#secondary-dns").val()]
      ));
    } else {
      promises.push(long_rpc_promise(
        packageId,
        "set_dns_servers",
        [null, null]
      ));
    }

    switch (getWanProtocol()) {
      case "dhcp":
        promises.push(long_rpc_promise(
          packageId, "enable_dhcp_wan_protocol", []
        ));
        break;
      case "static":
        promises.push(long_rpc_promise(
          packageId,
          "enable_static_wan_protocol", [
            $("#wan-static-ip").val(),
            $("#wan-static-subnet").val(),
            $("#wan-static-gateway").val(),
          ]
        ));
        break;
      case "ppoe":
        promises.push(long_rpc_promise(
          packageId,
          "enable_ppoe_wan_protocol",
          [$("#wan-ppoe-username").val(), $("#wan-ppoe-password").val()]
        ));
        break;
    }

    Q.spread(promises, function () {
      for (var i = 0; i < arguments.length; i++) {
        if (!arguments[i]) {
          throw Error();
        }
      }
      $("#settings-saving-error").addClass("hidden");
    }).fail(function () {
      $("#settings-saving-error").removeClass("hidden");
    });
  });
}

$(document).ready(function () {
  bindWanProtocolChange();
  Q.spread([
    long_rpc_promise(packageId, "get_lan_default_gateway", []),
    long_rpc_promise(packageId, "get_lan_subnet_mask", []),
    long_rpc_promise(packageId, "get_wan_protocol", []),
    long_rpc_promise(packageId, "get_static_wan_protocol", []),
    long_rpc_promise(packageId, "get_ppoe_wan_protocol", []),
    long_rpc_promise(packageId, "get_dns_servers", [])
  ], function (lanIp, lanSubnet, wanProtocol, staticDetails, ppoeDetails, dns) {
    setLanSettings(lanIp[0], lanSubnet[0]);
    setProtocol(wanProtocol[0]);
    setDns(dns[0]);
    switch (wanProtocol[0]) {
      case "static":
        setStatic(staticDetails[0]);
        break;
      case "ppoe":
        setPpoe(ppoeDetails[0]);
        break;
    }
    bindSaveSettings();
  }).fail(function () {
    $("#settings-content").addClass("hidden");
    $("#settings-error").removeClass("hidden");
  });
});
