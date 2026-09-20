$(function () {
  $('select').chosen({
    disable_search_threshold: 100000,
    allow_single_deselect: true
  });

  // Elements that has to be validated
  var elements = {
    ipOctet    : ".modal.in .max3:visible",
    port       : ".modal.in .max4:visible",
    service    : ".modal.in [id$=ServiceName]",
  }

  /*
  * Validations for each elements defined above
  * ipOctet - each octet between 0 and 255
  * port - Can be Empty or between 1 and 65535
  * service - Can be a string of length between 1 and 63
  */
  var validations = {
    ipOctet    : validateNumberRange(0, 255),
    port       : function(value) { return value == "" || validateNumberRange(1, 65535)(value) },
    service    : validateStringLength(1, 63),
  }

  $("#tvSettings-btn-editSave").click(function() {
    if(!validateElements(elements, validations)) return false;
    editedRow.find(".service").text($("#tvSettings-txt-editServiceName").val());
    var ip = [];
    $(".modal.in .max3").each(function() {
      $(this).val() && ip.push($(this).val());
    });
    ip = ip.join(".");
    editedRow.find(".ip").text(ip);
    // editedRow.find(".proto").text("$("#tvSettings-sel-editProtocol option:selected").text()");
    editedRow.find(".proto").text("TCP/UDP"); // Hardcoded because of no lower layer support
    var lanPort = [], wanPort = [];
    $("[id*=EditLANPort]:visible").each(function() {
      $(this).val() && lanPort.push($(this).val())
    })
    lanPort = lanPort.join("-")
    $("[id*=EditWANPort]:visible").each(function() {
      $(this).val() && wanPort.push($(this).val())
    })
    wanPort = wanPort.join("-")
    editedRow.find(".lan_port").text(lanPort);
    editedRow.find(".wan_port").text(wanPort);
    editedRow.find(".EditRow").val("1");
  });

  $("#tvSettings-btn-addSave").click(function() {
    if (!validateElements(elements, validations)) return false;
    var addServiceName = $("#tvSettings-txt-addServiceName").val();
    // var addProtocol = $("#tvSettings-sel-addProtocol option:selected").text();
    var addProtocol = "TCP/UDP" // Hardcoded because of no lower layer support
    var rows = $(".table-row:not(:first):not(:last):visible").length + 1;

    var addLanIp = [], addLanPort = [], addPublicPort = [];
    $(".modal.in .max3").each(function() {
      $(this).val() && addLanIp.push($(this).val());
    });
    addLanIp = addLanIp.join(".");
    $("[id*=AddLANPort]:visible").each(function() {
      $(this).val() && addLanPort.push($(this).val())
    })
    addLanPort = addLanPort.join("-")
    $("[id*=AddWANPort]:visible").each(function() {
      $(this).val() && addPublicPort.push($(this).val())
    })
    addPublicPort = addPublicPort.join("-")

  $('<div class="table-row">\
    <div class="table-col service">'+addServiceName+'</div>\
    <div class="table-col ip">'+addLanIp+'</div>\
    <div class="table-col proto">'+addProtocol+'</div>\
    <div class="table-col lan_port">'+addLanPort+'</div>\
    <div class="table-col wan_port">'+addPublicPort+'</div>\
    <div class="table-col"><input class="button button-edit editbutton" id="tvSettings-btn-edit_'+ rows +'" type="button" data-toggle="modal" data-target="#tv-popup-edit" onclick="copyData(this)"></div>\
    <div class="table-col ">\<input class="button button-delete deletebutton" id="tvSettings-btn-delete_'+ rows +'" type="button">\</div>\
        <div class="table-col fR tR">\
        <div class="button toggle-row-enable button-on" id="tvSettings-btn-enable_'+ rows +'" >\
          <input type="hidden" class="index" value="new"/>\
          <input type="hidden" class="enabled" value="1"/>\
          <input type="hidden" class="EditRow" value="1"/>\
        </div>\
      </div>\
  </div>').insertBefore("#tvSettings-row-last");
  });

  $(".tvSettings-table").on("click", ".button-add", function() {
    $("#addTVSettingsModal input[type=text], #addTVSettingsModal input[type=number]").val("");
    $("#tvSettings-sel-addDevice").val("noDevice").trigger("chosen:updated");
    $("#tvSettings-sel-addProtocol option:first").attr('selected','selected');
    $("[role=dialog] .input-error").removeClass("input-error");
    $("#tvSettings-radio-addSingle").trigger("click");
    $(".singleEditWAN, .singleEditLAN, .singleAddWAN, .singleAddLAN").show();
    $(".rangeEditWAN, .rangeEditLAN, .rangeAddWAN, .rangeAddLAN").hide();
  });

  $(".tvSettings-table").on("click", ".button-delete", function(){
    var deleteRow = $(this).closest(".table-row");
    var rowIndex = deleteRow.find(".index");
    rowIndex.val("del"+rowIndex.val());
    deleteRow.hide();
  });

  $("#tvSettings-table").on("click", ".toggle-row-enable", function() {
    if ($(this).hasClass('button-off')){
      $(this).closest("div").parent().parent().find(".tvSettingsRow").removeClass("op40").addClass("op60");
      $(this).find(".EditRow").val("1");
      $(this).removeClass('button-off').addClass('button-on');
    } else {
      $(this).closest("div").parent().parent().find(".tvSettingsRow").removeClass("op60").addClass("op40");
      $(this).find(".EditRow").val("0");
      $(this).removeClass('button-on').addClass('button-off');
    }
  });

  $("#global-apply").click(function() {
    // DHCP Related Values in the page
    elements = {
      ip : "[id$=IP4]",
      opt12: "#tv-txt-opt12"
    }
    // Validations for DHCP Related Values in the page
    // This needs separate validation as it is outside the popup
    validations = {
      ip : validateNumberRange(0, 255),
      opt12: validateStringLength(1, 63)
    }
    if(!validateElements(elements, validations)) return false;
    var totalRows = 0;
    var target = $("#tvSettings-form").attr("action");
    var tvSettingsObj = [];
    var startAddress = [];
    var endAddress = [];
    $("[id^=tv-txt-startIP]").each(function() {
      startAddress.push($(this).val());
    });
    $("[id^=tv-txt-endIP]").each(function() {
      endAddress.push($(this).val());
    });
    $('.tvSettings-table').find(".table-row:not(:first):not(:last)").each(function(index) {
      totalRows++;
      tvSettingsObj.push({
        index    : $(this).find(".index").val(),
        name     : $(this).find(".service").text(),
        ip       : $(this).find(".ip").text(),
        proto    : $(this).find(".proto").text().toLowerCase().replace("/",""),
        lan_port : $(this).find(".lan_port").text().replace("-",":"),
        wan_port : $(this).find(".wan_port").text().replace("-",":"),
        enabled  : $(this).find(".enabled").val() === "1",
        EditRow  : $(this).find(".EditRow").val(),
      });
    });
    var dhcpParams = {
      startIP: $("#tv-txt-startIP4").val(),
      endIP: $("#tv-txt-endIP4").val() - $("#tv-txt-startIP4").val() + 1,
      opt12: "12," + $("#tv-txt-opt12").val()
    }
    var postObj = {
      tvSettingsTable : JSON.stringify(tvSettingsObj),
      dhcpParams : JSON.stringify(dhcpParams),
      startAddress : startAddress.join("."),
      endAddress : endAddress.join("."),
      CSRFtoken : $('meta[name=CSRFtoken]').attr("content"),
      rows : totalRows
    };
    postHandler(target, postObj, true);
  });

  $("#global-cancel").click(function() {
    $("#content").load("/modals/settings/tvSettings.lp");
  });

  $("input[name=portRadioAdd], input[name=portRadioEdit]").change(function() {
    if ($(this).val() == "0") {
      $(".singleEditWAN, .singleEditLAN, .singleAddWAN, .singleAddLAN").show()
      $(".rangeEditWAN, .rangeEditLAN, .rangeAddWAN, .rangeAddLAN").hide();
    } else {
      $(".singleEditWAN, .singleEditLAN, .singleAddWAN, .singleAddLAN").hide()
      $(".rangeEditWAN, .rangeEditLAN, .rangeAddWAN, .rangeAddLAN").show();
    }
  })
});

// If a device is selected from drop down, update the IP field
$("#tvSettings-sel-addDevice, #tvSettings-sel-editDevice").change(function(){
  var IP = $(this).find("option:selected").val().split(".")
  var ipField = $(this).closest(".vdf-row").next().find(".max3")
  if (IP.length < 4) {
    ipField.val("");
  } else {
    ipField.each(function(index){
      var octet = IP[index];
      $(this).val(octet);
    });
  }
});

// Function to copy data from the row in which user clicked the edit button to Edit Pop-up
// element is the edit button of the row in which user clicked the edit button
function copyData(element) {
  $("[role=dialog] .input-error").removeClass("input-error");
  editedRow = $(element).closest(".table-row")
  var service = editedRow.find(".service").text();
  var ip = editedRow.find(".ip").text();
  var protocol = editedRow.find(".proto").text().toLowerCase();
  var lan_port = editedRow.find(".lan_port").text();
  var wan_port = editedRow.find(".wan_port").text();
  $("#tv-popup-edit :input[type=text]").val("");
  $("#tvSettings-sel-editProtocol").val(protocol).trigger("chosen:updated");
  (devices.indexOf(ip) != -1) ? $("#tvSettings-sel-editDevice").val(ip) : $("#tvSettings-sel-editDevice").val("noDevice");
  $("#tvSettings-sel-editDevice").trigger("chosen:updated");
  ip = ip.split(".");
  $("#tv-popup-edit .max3").each(function(index) {
    $(this).val(ip[index]);
  });
  if (wan_port.indexOf("-") != -1 || lan_port.indexOf("-") != -1) {
    $(".singleEditWAN, .singleEditLAN, .singleAddWAN, .singleAddLAN").hide()
    $(".rangeEditWAN, .rangeEditLAN, .rangeAddWAN, .rangeAddLAN").show();
    $("#tvSettings-radio-editRange").prop("checked", true)
  } else {
    $(".singleEditWAN, .singleEditLAN, .singleAddWAN, .singleAddLAN").show()
    $(".rangeEditWAN, .rangeEditLAN, .rangeAddWAN, .rangeAddLAN").hide();
    $("#tvSettings-radio-editSingle").prop("checked", true);
  }
  if (wan_port.indexOf("-") != -1) {
    wan_port = wan_port.split("-");
    $("#tv-txt-EditWANPort1").val(wan_port[0]);
    $("#tv-txt-EditWANPort2").val(wan_port[1]);
  } else {
    $("#tv-txt-EditWANPort").val(wan_port);
  }
  if (lan_port.indexOf("-") != -1) {
    lan_port = lan_port.split("-");
    $("#tv-txt-EditLANPort1").val(lan_port[0]);
    $("#tv-txt-EditLANPort2").val(lan_port[1]);
  } else {
    $("#tv-txt-EditLANPort").val(lan_port);
  }
  $("#tvSettings-txt-editServiceName").val(service);
}

