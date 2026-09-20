  var elements = {
    ipOctet      : ".modal.in .ip",
    port         : ".modal.in .max5:visible",
    service      : ".modal.in [id$=Service]",
    wanPortRange : ".modal.in .wanrange:visible",
    lanPortRange : ".modal.in .lanrange:visible"
  }

  var validations = {
    ipOctet    : function(value) {
      var count = 0;
      $(elements.ipOctet).each(function() {
        if($(this).hasClass("op40")){
          count++;
        }
      });
       return count == 4 || validateNumberRange(0, 255)(value);
     },
    port         : validateNumberRange(1, 65535),
    service      : validateStringLength(1, 63),
    wanPortRange : function(value) { return validatePortRanges(value, "WanPortRange", "WanPort1", "WanPort2")},
    lanPortRange : function(value) { return validatePortRanges(value, "LanPortRange", "LanPort1", "LanPort2")},
  }

  function validatePortRanges(value, portRId, portStartId, portEndId) {
    if ($("[id$=" + portRId + "]").is(":visible")) {
      var port1 = $("[id$=" + portStartId + "]:visible").val(),
          port2 = $("[id$=" + portEndId + "]:visible").val();
    if (portRId == "LanPortRange")
    {
      var wanPort1 = $("[id$=WanPort1]:visible").val(),
          wanPort2 = $("[id$=WanPort2]:visible").val();
      if ((port1 != wanPort1) || (port2 != wanPort2))
        return false;
    }
    else if (portRId == "WanPortRange")
    {
      var lanPort1 = $("[id$=LanPort1]:visible").val(),
          lanPort2 = $("[id$=LanPort2]:visible").val();
      if ((port1 != lanPort1) || (port2 != lanPort2))
        return false;
    }
    if (parseInt(port1) > parseInt(port2))
      return false;
    }
    return validateNumberRange(1, 65535)(value);
  }

  $(function () {
    $('select').chosen({
      disable_search_threshold: 100000,
      allow_single_deselect: true
    });
    $(".mobile-cancel-popup").click(function(){
      $(".modal").modal('hide');
    });

    var ipField = {
      ipOctet: ".modal.in .ip:focus"
    }
    var ipValid = {
      ipOctet: validateNumberRange(0, 255)
    }
    $("[id^=portmap-popup]").on("blur", ".ip", function() {
      if (!validateNumberRange(0, 255)($(this).val())) $(this).addClass('input-error');
      else $(this).removeClass('input-error');
    });

    var oldPortMapObject = [];
    $("#portmap-tbl-desktop .portmap-rule").each(function(index) {
      if ($(this).find("input[type=hidden]").length > 0) {
        oldPortMapObject.push({
          index : $(this).find("input[type=hidden]").val(),
          service : $(this).find(".service").text(),
          proto : $(this).find(".proto").text().toLowerCase().replace("/",""),
          ip : $(this).find(".ip").text(),
          lan_port : $(this).find(".lan_port").text().replace("-",":"),
          wan_port : $(this).find(".wan_port").text().replace("-",":")
        });
      }
    });

    // When page loads in Mobile view and there is no row, hide the first row whose header is visible in Desktop view
    var allRows = $(".row .port-mapping-row:not(:last)");
    if ( screenSize <= MAX_MOBILE_WIDTH && allRows.find("input[type=hidden]").length == 0 ) {
      allRows.hide();
    }

    // If a device is selected from drop down, update the IP field
    $("#portmap-sel-addDevices, #portmap-sel-editDevices").change(function(){
      var IP = $(this).find("option:selected").val().split(".");
      var ipField = $(this).closest(".vdf-row").next().find(".max3");
      ipField.removeClass("op40");
      if (IP.length < 4) {
        ipField.val("");
      } else {
        ipField.each(function(index){
          var octet = IP[index];
          $(this).val(octet);
        });
      }
    });

    // If port type radio button is clicked, change the fields accordingly
    $("input[name='edit-port-radio']").change(function() {
      $("#portmap-err-edit").hide();
      if($(this).val() == "1") {
        $("#portmap-lbl-editPort1").text(T["Public Port"]);
        $("#portmap-div-editWanPort").show();
        $("#portmap-div-editLanPort").show();
        $("#portmap-div-editLanPortRange").hide();
        $("#portmap-div-editWanPortRange").hide();
        $("#portmap-lbl-editPort2").text(T["Local Port"]);
      } else {
        $("#portmap-lbl-editPort1").text(T["Public Port Range"]);
        $("#portmap-div-editWanPort").hide();
        $("#portmap-div-editLanPort").hide();
        $("#portmap-div-editWanPortRange").show();
        $("#portmap-div-editLanPortRange").show();
        $("#portmap-lbl-editPort2").text(T["LAN Port Range"]);
      }
    });

    // If port type radio button is clicked, change the fields accordingly
    $("input[name='add-port-radio']").change(function(){
      $("#portmap-err-add").hide();
      if($(this).val() == "1") {
        $("#portmap-lbl-addPort1").text(T["Public Port"]);
        $("#portmap-div-addWanPort").show();
        $("#portmap-div-addLanPort").show();
        $("#portmap-div-addWanPortRange").hide();
        $("#portmap-div-addLanPortRange").hide();
        $("#portmap-lbl-addPort2").text(T["Local Port"]);
      } else {
        $("#portmap-lbl-addPort1").text(T["Public Port Range"]);
        $("#portmap-div-addWanPort").hide();
        $("#portmap-div-addLanPort").hide();
        $("#portmap-div-addWanPortRange").show();
        $("#portmap-div-addLanPortRange").show();
        $("#portmap-lbl-addPort2").text(T["LAN Port Range"]);
      }
    });

    /*
     * When delete button is clicked, remove the row if it is newly added
     * Hide the row, if it was already added.
     * In desktop view, if it is first row, hide only the values not the header
     * In mobile view, if it is first row, hide the entire row
     */
    $("#portmap-tbl-desktop").on("click", ".button-delete", function() {
      var thisRow = $(this).closest("tr");
      var index = $( ".button-delete" ).index(this);
      var rowIndex = thisRow.find("input[type=hidden]");
      rowIndex.val("del"+rowIndex.val());
      if (index > 0) {
        if (thisRow.find("input[type=hidden]").val() == "new") {
          thisRow.remove();
        } else {
          thisRow.hide();
        }
      } else {
          if (thisRow.find("input[type=hidden]").val() == "new") {
            thisRow.remove();
          } else {
            thisRow.hide();
          }
      }

      if ($("#portmap-tbl-desktop .portmap-rule:visible").length == 0) {
        $(".noRulesSet").show();
      } else {
        $(".noRulesSet").hide();
      }

      var thisIndex = $("#portmap-tbl-desktop .button-delete").index($(this));
      $("#portmap-tbl-mobile .portmap-mobile-row").eq(thisIndex).hide();

    });

    // When Add button is clicked, Clear all the previously entered entries
    $("#portmap-btn-add").click(function() {
      $("[role=dialog] .input-error").removeClass("input-error");
      $("#portmap-popup-add input[id*='portmap-txt']").val("");
      $("#portmap-sel-addProtocol").val("tcp").trigger("chosen:updated");
      $("#portmap-sel-addDevices").val("noDevice").trigger("chosen:updated");
      $(".addIP").val("");
      $("#portmap-rad-addPortS").trigger("click");
    });

    // Wire Mobile Add button with Desktop Add button
    $("#portmap-btn-mobileAdd").click(function() {
      $("#portmap-btn-add").trigger("click");
    });

    // Wire Mobile Edit button with Desktop Edit button
    $("#portmap-tbl-mobile").on("click", ".button-edit", function() {
      var thisIndex = $("#portmap-tbl-mobile .button-edit").index($(this));
      $("#portmap-tbl-desktop .button-edit").eq(thisIndex).trigger("click");
    });

    // Wire Mobile Delete button with Desktop Delete button
    $("#portmap-tbl-mobile").on("click", ".button-delete", function() {
      var thisIndex = $("#portmap-tbl-mobile .button-delete").index($(this));
      $("#portmap-tbl-desktop .button-delete").eq(thisIndex).trigger("click");
      $(this).closest('.portmap-mobile-row').hide();
    });

    // When Save button from Edit Popup is clicked, Update the edited row
    $("#portmap-btn-editSave").click(function() {
      $("[id$=editWanPort]:visible").removeClass('input-error');
      $("[id$=editWanPort1]:visible").removeClass('input-error');
      $("[id$=editWanPort2]:visible").removeClass('input-error');
      $("#portmap-err-edit").hide();
      if(!validateElements(elements, validations)) return false;
      var service = $("#portmap-txt-editService").val();
      var ip = [];
      var count = 0;
      $(".editIP").each(function() {
        ip.push($(this).val());
        if($(this).hasClass("op40")){
          count++;
        }
      });
      var protocol = $("#portmap-sel-editProtocol option:selected").text();
      var protocolValue = $("#portmap-sel-editProtocol option:selected").val();
      var wanPort;
      var wanPortStart, wanPortEnd;
      var notRange = false;
      if ( $("input[name='edit-port-radio']:checked").val() == "1" )
      {
        wanPortStart = $("#portmap-txt-editWanPort").val();
        wanPortEnd = $("#portmap-txt-editWanPort").val();
      }
      else
      {
        wanPortStart = $("#portmap-txt-editWanPort1").val();
        wanPortEnd = $("#portmap-txt-editWanPort2").val();
        notRange = true;
      }
      for (var i in reservedPorts)
      {
        if (reservedPorts[i].proto == protocolValue || protocolValue == "tcpudp")
        {
          if (reservedPorts[i].port >= wanPortStart && reservedPorts[i].port <= wanPortEnd)
          {
            if (notRange === false)
            {
              $("#portmap-txt-editWanPort").addClass('input-error');
            }
            else
            {
              $("#portmap-txt-editWanPort1").addClass('input-error');
              $("#portmap-txt-editWanPort2").addClass('input-error');
            }
            $("#portmap-err-edit").show();
            return false;
          }
        }
      }
      wanPort = ( $("input[name='edit-port-radio']:checked").val() == "1" ) ? $("#portmap-txt-editWanPort").val() : $("#portmap-txt-editWanPort1").val() + "-" + $("#portmap-txt-editWanPort2").val();
      var lanPort = ($("input[name='edit-port-radio']:checked").val() == "1" ) ? $("#portmap-txt-editLanPort").val() : $("#portmap-txt-editLanPort1").val() + "-" + $("#portmap-txt-editLanPort2").val();
      selectedRow.find(".service").text(service);
      count != 4 && selectedRow.find(".ip").text(ip.join("."));
      selectedRow.find(".proto").text(protocol);
      selectedRow.find(".lan_port").text(lanPort);
      selectedRow.find(".wan_port").text(wanPort);

      var selectedRowIndex = selectedRow.index() - 1;
      var selectedMobileRow = $(".portmap-mobile-row").eq(selectedRowIndex);

      selectedMobileRow.find(".service").text(service);
      count != 4 && selectedMobileRow.find(".ip").text(ip.join("."));
      selectedMobileRow.find(".proto").text(protocol);
      selectedMobileRow.find(".lan_port").text(lanPort);
      selectedMobileRow.find(".wan_port").text(wanPort);

    });

    // When Save button from Add Popup is clicked, Append a row before Last row of the table
    $("#portmap-btn-addSave").click(function() {
      $("[id$=addWanPort]:visible").removeClass('input-error');
      $("[id$=addWanPort1]:visible").removeClass('input-error');
      $("[id$=addWanPort2]:visible").removeClass('input-error');
      $("#portmap-err-add").hide();
      if(!validateElements(elements, validations)) return false;
      var service = $("#portmap-txt-addService").val();
      var ip = [];
      $(".addIP").each(function() {
        ip.push($(this).val());
      });
      ip = ip.join(".");
      var protocol = $("#portmap-sel-addProtocol option:selected").text();
      var protocolValue = $("#portmap-sel-addProtocol option:selected").val();
      var wanPort = "";
      var lanPort = "";
      var notRange = false;
      var wanPortStart, wanPortEnd;
      if ( $("input[name='add-port-radio']:checked").val() == "1" )
      {
        wanPortStart = $("#portmap-txt-addWanPort").val();
        wanPortEnd = $("#portmap-txt-addWanPort").val();
      }
      else
      {
        wanPortStart = $("#portmap-txt-addWanPort1").val();
        wanPortEnd = $("#portmap-txt-addWanPort2").val();
        notRange = true;
      }
      for (var i in reservedPorts)
      {
        if (reservedPorts[i].proto == protocolValue || protocolValue == "tcpudp")
        {
          if (reservedPorts[i].port >= wanPortStart && reservedPorts[i].port <= wanPortEnd)
          {
            if (notRange === false)
            {
              $("#portmap-txt-addWanPort").addClass('input-error');
            }
            else
            {
              $("#portmap-txt-addWanPort1").addClass('input-error');
              $("#portmap-txt-addWanPort2").addClass('input-error');
            }
            $("#portmap-err-add").show();
            return false;
          }
        }
      }
      ( $("input[name='add-port-radio']:checked").val() == "1" ) ? wanPort = $("#portmap-txt-addWanPort").val() : wanPort = $("#portmap-txt-addWanPort1").val() + "-" + $("#portmap-txt-addWanPort2").val();
      ( $("input[name='add-port-radio']:checked").val() == "1" ) ? lanPort = $("#portmap-txt-addLanPort").val() : lanPort = $("#portmap-txt-addLanPort1").val() + "-" + $("#portmap-txt-addLanPort2").val();
      var rows = $(".portmap-rule:visible").length + 1;
      $("<tr class=\"portmap-rule\">\
           <input type=\"hidden\" value=\"new\">\
           <td class=\"ipv6-font-size service\">" + service + "</td>\
           <td class=\"ipv6-font-size ip\">" + ip + "</td>\
           <td class=\"ipv6-font-size proto\">" + protocol + "</td>\
           <td class=\"ipv6-font-size lan_port\">" + lanPort + "</td>\
           <td class=\"ipv6-font-size wan_port\">" + wanPort + "</td>\
           <td>\
             <input class=\"button button-edit mapping\" type=\"button\" onclick=\"copyData(this)\" data-toggle=\"modal\" data-target=\"#portmap-popup-edit\" id=\"portmap-btn-edit" + rows + "\" />\
           </td>\
           <td>\
             <input class=\"button button-delete\" type=\"button\" id=\"portmap-btn-delete" + rows + "\" />\
           </td>\
         </tr>").insertBefore("#portmap-row-last");

      var newMobileRow = $("<div class=\"mobile-entry portmap-rule portmap-mobile-row\">\
                              <div class=\"table-mobile-title\">\
                                <span>" + T["Service"] + "</span>\
                              </div>\
                              <div class=\"table-mobile-content service\">" + service + "</div>\
                              <div class=\"table-mobile-title\">\
                                <span>" +T["Local IP Address"] + "</span>\
                              </div>\
                              <div class=\"table-mobile-content ip\">" + ip + "</div>\
                              <div class=\"table-mobile-title\">\
                                <span>" +T["Protocol"] + "</span>\
                              </div>\
                              <div class=\"table-mobile-content proto\">" + protocol + "</div>\
                              <div class=\"table-mobile-title\">\
                                <span>" +T["LAN Port"] + "</span>\
                              </div>\
                              <div class=\"table-mobile-content lan_port\">" + lanPort + "</div>\
                              <div class=\"table-mobile-title\">\
                                <span>" +T["Public Port"]+ "</span>\
                              </div>\
                              <div class=\"table-mobile-content wan_port\">" + wanPort + "</div>\
                              <div class=\"btn-wrap\">\
                                <input class=\"button button-edit mapping\" type=\"button\">\
                                <input class=\"button button-delete\" type=\"button\">\
                              </div>\
                            </div>");
      $(newMobileRow).insertBefore("#mobileAddBtn");
      $(".noRulesSet").hide();
    });

    $("#portmp-algs").on("click", ".button-alg", function() {
      $(this).find(".status").val($(this).hasClass('button-on')?"1":"0");
    });

    $("#home-sel-mobmode").bind("change", function(e) {
      e.preventDefault();
    });
    $("#global-apply").click(function() {
      var totalRows = 0;
      var portmapObj = [];
      var algObj = [];
      $("#portmap-tbl-desktop .portmap-rule").each(function(index) {
        if ($(this).find("input[type=hidden]").length > 0) {
          totalRows++;
          portmapObj.push({
            index : $(this).find("input[type=hidden]").val(),
            service : $(this).find(".service").text(),
            proto : $(this).find(".proto").text().toLowerCase().replace("/",""),
            ip : $(this).find(".ip").text(),
            lan_port : $(this).find(".lan_port").text().replace("-",":"),
            wan_port : $(this).find(".wan_port").text().replace("-",":")
          });
          if (JSON.stringify(oldPortMapObject[portmapObj.length-1]) === JSON.stringify(portmapObj[portmapObj.length-1])) {
            portmapObj[portmapObj.length-1].index = "";
          }
        }
      });

      $("#portmp-algs .alghelp").each(function() {
        algObj.push({
          name: $(this).find(".name").val(),
          status: $(this).find(".status").val() || "1",
          index: $(this).find(".index").val(),
        });
      });
      var postObj = [];
      postObj.push({ name : "portmapTable", value : JSON.stringify(portmapObj) });
      postObj.push({ name : "ALGTable", value : JSON.stringify(algObj) });
      postObj.push({ name : "CSRFtoken", value : $("[name=CSRFtoken]").val() });
      postObj.push({ name : "rows", value : totalRows });
      var NATStatus = $("#portmapping-btn-nat").hasClass("button-on") ? "true" : "false";
      postObj.push({ name : "NATStatus", value : NATStatus === "true" });
      postHandler("/modals/port-mapping.lp", postObj, true);
    });
  });

  $("#global-cancel").click(function() {
    $("#content").load("/modals/port-mapping.lp");
  });

  // Function to copy data from the row in which user clicked the edit button to Edit Pop-up
  // element is the edit button of the row in which user clicked the edit button
  function copyData(element) {
    $("[role=dialog] .input-error").removeClass("input-error");
    selectedRow = $(element).closest("tr")
    var service = selectedRow.find(".service").text();
    var ip = selectedRow.find(".ip").text();
    var protocol = selectedRow.find(".proto").text().toLowerCase().replace("/","");
    var lan_port = selectedRow.find(".lan_port").text();
    var wan_port = selectedRow.find(".wan_port").text();
    $("#portmap-popup-edit input[id*='portmap-txt']").val("");
    $("#portmap-sel-editProtocol").val(protocol).trigger("chosen:updated");
    (devices.indexOf(ip) != -1) ? $("#portmap-sel-editDevices").val(ip) : $("#portmap-sel-editDevices").val("noDevice");
    $("#portmap-sel-editDevices").trigger("chosen:updated");
    ip = ip.split(".");
    $(".editIP").each(function(index) {
      if(ip.length != 4) {
        $(this).addClass("op40");
        $(this).val("");
      } else {
        $(this).removeClass("op40");
        $(this).val(ip[index]);
      }
    });
    if (wan_port.indexOf("-") != -1) {
      $("#portmap-rad-editPortR").trigger("click");
      wan_port = wan_port.split("-");
      lan_port = lan_port.split("-");
      $("#portmap-txt-editWanPort1").val(wan_port[0]);
      $("#portmap-txt-editWanPort2").val(wan_port[1]);
      $("#portmap-txt-editLanPort1").val(lan_port[0]);
      $("#portmap-txt-editLanPort2").val(lan_port[1]);
    } else {
      $("#portmap-rad-editPortS").trigger("click");
      $("#portmap-txt-editWanPort").val(wan_port);
      $("#portmap-txt-editLanPort").val(lan_port);
    }
    $("#portmap-txt-editService").val(service);
  }
  $("#resetR, .resetR").click(function(){
    $(".button-delete").click();

    function resetButton(button, value) {
      if ( value == "1") {
        $(button).addClass('button-on').removeClass('button-off');
      } else {
        $(button).removeClass('button-on').addClass('button-off');
      }
      $(button).find(".status").val(value);
    }

    resetButton("#portmapping-btn-alg_RTSP", resetPortmapping.reset_rtsp);
    resetButton("#portmapping-btn-alg_TFTP", resetPortmapping.reset_tftp);
    resetButton("#portmapping-btn-alg_IRC", resetPortmapping.reset_irc);
    resetButton("#portmapping-btn-alg_PPTP", resetPortmapping.reset_pptp);
    resetButton("#portmapping-btn-alg_AMANDA", resetPortmapping.reset_amanda);
    resetButton("#portmapping-btn-alg_SIP", resetPortmapping.reset_sip);
    resetButton("#portmapping-btn-alg_FTP", resetPortmapping.reset_ftp);
    resetButton("#portmapping-btn-alg_SNMP", resetPortmapping.reset_snmp);
    resetButton("#portmapping-btn-alg_H323", resetPortmapping.reset_h323);
    resetButton("#portmapping-btn-alg_IPSEC", resetPortmapping.reset_ipsec);
    resetButton("#portmapping-btn-alg_L2TP", resetPortmapping.reset_l2tp);
    resetButton("#portmapping-btn-alg_Q931", resetPortmapping.reset_q931);
    resetButton("#portmapping-btn-alg_RAS", resetPortmapping.reset_ras);

    $("#portmapping-btn-nat").val(resetPortmapping.reset_nat_traversal);
      if (resetPortmapping.reset_nat_traversal == "1") {
        $('#portmapping-btn-nat').addClass('button-on').removeClass('button-off');
      }
      else
      {
        $('#portmapping-btn-nat').addClass('button-off').removeClass('button-on');
      }
  });
