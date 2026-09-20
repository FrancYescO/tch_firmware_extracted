  var editedRow;
  var MAX_MOBILE_WIDTH = 767;
  var translatedDays = [T["Mon"], T["Tue"], T["Wed"], T["Thu"], T["Fri"], T["Sat"], T["Sun"]]
  var days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  var oldTODArray = [];
  var daysType = ["Every Day", "Every Workday", "All Weekend"];

  $("#parental-tbl-desktop .parental-row-desktop").each(function(index) {
    oldTODArray.push([]);
    $(this).find(".rule-name, .device-name, .start-time, .stop-time, input[type=hidden]").each(function() {
      oldTODArray[index].push($(this).text() || $(this).val());
    });
  });
  var rownum = 0;

  var elements = {
    ruleName: "[role=dialog].in [id$=RuleName]",
    deviceName: "[role=dialog].in [id$=DeviceName]:visible",
    MACAddress: "[role=dialog].in .max2:visible",
    startTime: "[role=dialog].in [id$=StartTime]:visible",
    endTime: "[role=dialog].in [id$=EndTime]:visible"
  }

  var validations = {
    ruleName: notAnEmptyString,
    deviceName: notAnEmptyString,
    MACAddress: MACOctetRegExp,
    startTime: timeRegExp,
    endTime: function(value) {
      return timeRegExp.test(value) && (formatTime(value) > formatTime($(elements.startTime).val()))
    }
  }

  $(function() {
    if ($(window).width() > MAX_MOBILE_WIDTH) {
      $(".access-header").show();
    }

  $(".mobile-cancel-popup").click(function(){
      $(".modal").modal('hide');
    });

    $("#parental-sel-editDevice").change( function() {
      if ($(this).val() != "newDevice") {
        editNewDevice = false;
        $("#parental-div-editOldMAC").show();
        $("#parental-div-editNewMAC, #parental-div-editNewName").hide();
        $("#parental-info-editOldMAC").text($(this).val().toUpperCase());
      } else {
        editNewDevice = true;
        $("#parental-div-editNewName, #parental-div-editNewMAC").show();
        $("#parental-div-editOldMAC").hide();
      }
    });

    $("#parental-sel-addDevice").change( function() {
      if ($(this).val() != "newDevice") {
        addNewDevice = false;
        $("#parental-div-addOldMAC").show();
        $("#parental-div-addNewMAC, #parental-div-addNewName").hide();
        $("#parental-info-addOldMAC").text($(this).val().toUpperCase());
      } else {
        addNewDevice = true;
        $("#parental-div-addNewName, #parental-div-addNewMAC").show();
        $("#parental-div-addOldMAC").hide();
      }
    });

    $("#parental-sel-editDays").change( function() {
      if (daysType.indexOf($(this).find("option:selected").val()) != -1) {
        $("#parental-div-editIndividualDays").hide();
      } else {
        $("#parental-div-editIndividualDays").show();
      }
    });

    $("#parental-sel-addDays").change( function() {
      if (daysType.indexOf($(this).find("option:selected").val()) != -1) {
        $("#parental-div-addIndividualDays").hide();
      } else {
        $("#parental-div-addIndividualDays").show();
      }
    });

    $(".toggle-content-button").click(function() {
      if (typeof(Storage) !== "undefined") {
        sessionStorage.setItem('apply_changes',"Y");
      }
    });

    $("#parental-btn-editSave").click(function() {
      if (!validateElements(elements, validations)) return false;
      var ruleName = $("#parental-txt-editRuleName").val();
      var selectedDevice = $("#parental-sel-editDevice").val();
      var deviceName, deviceMAC
      if (selectedDevice == "newDevice") {
        deviceName = $("#parental-txt-editNewDeviceName").val();
        deviceMAC = [];
        $(".editMAC").each(function() {
          deviceMAC.push($(this).val());
        });
        deviceMAC = deviceMAC.join(":");
      } else {
        deviceName = $("#parental-sel-editDevice option:selected").text();
        deviceMAC = $("#parental-info-editOldMAC").text();
      }
      var selectedDay = $("#parental-sel-editDays").val();
      var daysOfWeek = [];
      if (daysType.indexOf(selectedDay) == -1) {
        selectedDay = [];
        $("#parental-div-editIndividualDays input").each(function(index) {
          if ($(this).prop("checked")) {
            daysOfWeek.push(translatedDays[index]);
            selectedDay.push(days[index]);
          }
        });
        selectedDay = selectedDay.join(", ");
        daysOfWeek = daysOfWeek.join(", ");
      } else daysOfWeek = $("#parental-sel-editDays option:selected").text();
      var startTime = $("#parental-txt-editStartTime").val();
      var endTime = $("#parental-txt-editEndTime").val();

      var thisRow = $(editedRow).closest(".parental-row-desktop");
      thisRow.find(".rule-name").text(ruleName);
      thisRow.find(".device-name").text(deviceName);
      thisRow.find(".mac").val(deviceMAC)
      thisRow.find(".days").text(daysOfWeek);
      thisRow.find(".dayType").val(selectedDay);
      thisRow.find(".start-time").text(formatTime(startTime));
      thisRow.find(".stop-time").text(formatTime(endTime));

      var thisRowIndex = thisRow.index() - 1;
      var thisMobileRow = $(".parental-row-mobile").eq(thisRowIndex);
      thisMobileRow.find(".rule-name").text(ruleName);
      thisMobileRow.find(".device-name").text(deviceName);
      thisMobileRow.find(".days").text(daysOfWeek);
      thisMobileRow.find(".start-time").text(formatTime(startTime));
      thisMobileRow.find(".stop-time").text(formatTime(endTime));
    });

    $("#parental-tbl-desktop").on("click", ".toggle-row-enable", function() {
      var parentRow = $(this).closest('.parental-row-desktop');
      var rowIndex = parentRow.find(".row-index");
      if ($(this).hasClass('button-off')) {
        $(this).closest(".parental-row-desktop").find("input[type=hidden]:eq(1)").val("1");
      } else {
        $(this).closest(".parental-row-desktop").find("input[type=hidden]:eq(1)").val("0");
      }
      $(this).toggleClass('button-on button-off');
      if (rowIndex.val() != "new" && vdfVariant == "NZ") {
        detectToggleChanges($(this));
      }
      $(this).closest('.parental-row-desktop').toggleClass("op40");
    });

    $("#tod-btn-enable").click(function() {
      $("#global-enable").val($(this).hasClass("button-on") ? "1" : "0");
    });

    $('#parental-tbl-desktop').on("click", ".button-delete", function() {
      var parentRow = $(this).closest('.parental-row-desktop');
      var rowIndex = parentRow.find(".row-index");
      if (rowIndex.val() == "new") {
        if (vdfVariant == "NZ") {
          // To avoid navigation restriction when new unsaved rule is deleted
          sessionStorage.setItem("delete_bypass", "true");
        }
        parentRow.remove();
      } else {
        rowIndex.val("del" + rowIndex.val());
        parentRow.hide();
      }
    });

    $('#parental-tbl-desktop').on("click", ".button-edit", function() {
      var parentEditRow = $(this).closest('.parental-row-desktop');
      var editedRowIndex = parentEditRow.find(".row-index");
      if (editedRowIndex.val() == "new" && vdfVariant == "NZ") {
        // Used to restrict page navigation on selecting Cancel within a new rule that is edited
        sessionStorage.setItem("newRule_edit", "true");
      }
    });

    $("#parental-tbl-mobile").on("click", ".toggle-row-enable", function() {
      $(this).toggleClass("button-on button-off").closest('.parental-row-mobile').toggleClass("op50");
      var thisIndex = $("#parental-tbl-mobile .toggle-row-enable").index(this);
      $("#parental-tbl-desktop .toggle-row-enable").eq(thisIndex).trigger("click");
    });

    $('#parental-tbl-mobile').on("click", ".button-delete", function() {
      var thisIndex = $("#parental-tbl-mobile .button-delete").index(this);
      var desktopRow = $("#parental-tbl-desktop .parental-row-desktop").eq(thisIndex);
      var deletedRowIndex = desktopRow.find(".row-index");
      if (deletedRowIndex.val() == "new") {
        if (vdfVariant == "NZ") {
          // To avoid navigation restriction when new unsaved rule is deleted
          sessionStorage.setItem("delete_bypass", "true");
        }
        desktopRow.remove();
      } else {
        deletedRowIndex.val("del" + deletedRowIndex.val());
        desktopRow.hide();
      }
      $(this).closest(".parental-row-mobile").hide();
    });

    $("#parental-img-mobileAdd").click(function() {
      $("#parental-img-add").trigger("click");
    });

    $('#parental-tbl-mobile').on("click", ".button-edit", function() {
      var thisIndex = $("#parental-tbl-mobile .button-edit").index(this);
      $("#parental-tbl-desktop .button-edit").eq(thisIndex).trigger("click");
    });

    $("#tod-btn-enable").click(function() {
      $(this).hasClass("button-off") ? $("#tod_table").slideUp("fast") : $("#tod_table").slideDown("fast");
    });

    $("#parental-img-add").click(function() {
      addNewDevice = true;
      $("#parental-sel-addDays option:first").prop("selected", true);
      $("#parental-sel-addDays").trigger("chosen:updated");
      $("#addAccessControlModal").find("input[type=text], input[type=hidden]").val("");
      $("#parental-sel-addDevice").val("newDevice").trigger("chosen:updated");
      $("#parental-div-addIndividualDays").hide();
      $("#parental-div-addNewMAC").show();
      $("#parental-div-addOldMAC").hide();
      $("#parental-div-addNewName").show();
      $("[role=dialog] .input-error").removeClass("input-error");
    });

    $("#parental-btn-newSave").click(function() {
      if (!validateElements(elements, validations)) return false;
      var ruleName = $("#parental-txt-AddRuleName").val();
      var deviceName = ""
      var MACAddress = [];

      if (addNewDevice) {
        deviceName = $("#parental-txt-addNewDeviceName").val();
        $(".newmac").each(function() {
          MACAddress.push($(this).val());
        });
        MACAddress = MACAddress.join(":");
      } else {
        deviceName = $("#parental-sel-addDevice option:selected").text();
        MACAddress = $("#parental-info-addOldMAC").text();
      }

      var daysOfWeek = [];
      var selectedDay = $("#parental-sel-addDays").val();
      if (daysType.indexOf(selectedDay) == -1) {
        selectedDay = [];
        $("#parental-div-addIndividualDays input").each(function(index) {
          if ($(this).prop("checked")) {
            daysOfWeek.push(translatedDays[index]);
            selectedDay.push(days[index]);
          }
        });
        selectedDay = selectedDay.join(", ");
        daysOfWeek = daysOfWeek.join(", ");
      } else daysOfWeek = $("#parental-sel-addDays option:selected").text();
      var startTime = $("#parental-txt-addStartTime").val();
      var endTime = $("#parental-txt-addEndTime").val();

      ++rownum;
      $("<div class=\"table-row parental-row-desktop\">\
            <input type=\"hidden\" class=\"row-index\" value=\"new\">\
            <input type=\"hidden\" class=\"enable\" value=\"1\">\
            <div class=\"table-col\">\
              <span class=\"rule-name\">" + ruleName + "</span>\
            </div>\
            <div class=\"table-col\">\
              <input type=\"hidden\" class=\"mac\" value=\"" + MACAddress + "\">\
              <span class=\"device-name\">" + deviceName + "</span>\
            </div>\
            <div class=\"table-col\">\
              <input type=\"hidden\" class=\"dayType\" value=\"" + selectedDay + "\">\
              <span class=\"days\">" + daysOfWeek + "</span>\
            </div>\
            <div class=\"table-col\">\
              <span class=\"start-time\">" + formatTime(startTime) + "</span>\
            </div>\
            <div class=\"table-col\">\
              <span class=\"stop-time\">" + formatTime(endTime) + "</span>\
            </div>\
            <div class=\"table-col\">\
              <input class=\"button button-edit\" type=\"button\" onclick=\"copyData(this)\" data-toggle=\"modal\" data-target=\"#parental-popup-edit\">\
            </div>\
            <div class=\"table-col\">\
              <input class=\"button button-delete\" type=\"button\">\
            </div>\
            <div class=\"table-col fR tR\">\
              <div class=\"toggle-row-enable button button-on\"></div>\
            </div>\
          </div>\
        ").insertBefore("#parental-row-Desktoplast");

      $("<div class=\"mobile-entry parental-row-mobile\">\
          <div class=\"on-off-wrap\">\
            <div class=\"toggle-row-enable button button-on\">\
            </div>\
          </div>\
          <div class=\"mobile-table-big-content\">\
            <div class=\"mobile-subtitle\">\
              <span>" + T["Rule Name"] + "</span>\
            </div>\
            <div class=\"mobile-content\">\
              <span class=\"rule-name\">" + ruleName + "</span>\
            </div>\
            <div class=\"mobile-subtitle\">\
              <span>" + T["Device"] + "</span>\
            </div>\
            <div class=\"mobile-content\">\
              <span class=\"device-name\">" + deviceName + "</span>\
            </div>\
            <div class=\"mobile-subtitle\">\
              <span>" + T["Days Of Week"] + "</span>\
            </div>\
            <div class=\"mobile-content\">\
              <span class=\"days\">" + daysOfWeek + "</span>\
            </div>\
            <div class=\"mobile-subtitle\">\
              <span>" + T["From"] + "</span>\
            </div>\
            <div class=\"mobile-content\">\
              <span class=\"start-time\">" + formatTime(startTime) + "</span>\
            </div>\
            <div class=\"mobile-subtitle\">\
              <span>" + T["To"] + "</span>\
            </div>\
            <div class=\"mobile-content\">\
              <span class=\"stop-time\">" + formatTime(endTime) + "</span>\
            </div>\
          </div>\
          <div class=\"buttons-wrap-edit-delete\">\
            <input class=\"button button-edit\" type=\"button\">\
            <input class=\"button button-delete\" type=\"button\">\
          </div>\
        </div>\
      ").insertBefore("#parental-row-mobileLast")

    })
  });

  $("#global-apply, #modal-apply").click(function() {
    var newTODArray = [];
    var newRow = false;
    var isIndexPushed = false;
    var totalRows = 0;

    $("#parental-tbl-desktop .parental-row-desktop").each(function(index) {
      totalRows++;
      newTODArray.push([]);
      $(this).find(".rule-name, .device-name, .start-time, .stop-time, input[type=hidden]").each(function() {
          newTODArray[index].push($(this).text() || $(this).val());
      });
      if (JSON.stringify(oldTODArray[index]) === JSON.stringify(newTODArray[index]))
        newTODArray[newTODArray.length-1][0] = ""; // No changes in this row. So, remove it's index.
    });

    var postObj = [
      { name : "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content") },
      { name : "global_enable", value : $("#global-enable").val() },
      { name : "todObj", value : JSON.stringify(newTODArray) },
      { name : "total_rows", value : totalRows }
    ];
    postHandler("/modals/internet/parentalControl.lp", postObj, true);
  });

  function formatTime(time) {
    if (!(/^\d+:\d+$/).test(time)) return time;
    var regExp = /^\d+|\d+$/g;
    function padZero(value) {
      return ("0" + value).slice(-2);
    }
    return time.replace(regExp, padZero);
  }

  function copyData(element) {
    editedRow = element;
    var thisRow = $(editedRow).closest(".parental-row-desktop");
    var ruleName = thisRow.find(".rule-name").text();
    var deviceName = thisRow.find(".device-name").text();
    var MACAddress = thisRow.find(".mac").val();
    var selectedDay = thisRow.find(".dayType").val();
    var startTime = thisRow.find(".start-time").text();
    var endTime = thisRow.find(".stop-time").text();
    $("#parental-txt-editRuleName").val(ruleName);
    if (connectedDevices.indexOf(MACAddress) == -1) {     // NEW DEVICE
      $("#parental-sel-editDevice").val("newDevice").trigger("chosen:updated");
      $("#parental-div-editOldMAC").hide();
      $("#parental-div-editNewName, #parental-div-editNewMAC").show();
      $("#parental-txt-editNewDeviceName").val(deviceName);
      assignMAC("parental-txt-editMAC", MACAddress);
    } else {                                              // CONNECTED DEVICE
      $("#parental-sel-editDevice").val(MACAddress).trigger("chosen:updated");
      $("#parental-div-editOldMAC").show();
      $("#parental-div-editNewName, #parental-div-editNewMAC").hide();
      $("#parental-info-editOldMAC").text(MACAddress);
    }
    $("#parental-div-editIndividualDays input").prop("checked", 0);
    if (daysType.indexOf(selectedDay) == -1) {
      selectedDay = selectedDay.split(", ")
      for (i = 0; i < selectedDay.length; i++) {
        if ( days.indexOf(selectedDay[i] != -1) ) {
          $("#parental-div-editIndividualDays input:eq(" + days.indexOf(selectedDay[i]) + ")").prop("checked", 1);
        }
      }
      $("#parental-sel-editDays").val("Individual Days").trigger("chosen:updated")
      $("#parental-div-editIndividualDays").show();
    } else {
      $("#parental-sel-editDays").val(selectedDay).trigger("chosen:updated")
      $("#parental-div-editIndividualDays").hide();
    }
    $("#parental-txt-editStartTime").val(formatTime(startTime));
    $("#parental-txt-editEndTime").val(formatTime(endTime));
    $("[role=dialog] .input-error").removeClass("input-error");
  }

  function assignMAC(id,macAddr) {
    if (!macAddr) return;
    var splitMAC = macAddr.split(":");
    for(var i=1;i<=6;i++) {
      document.getElementById(id+i).value = splitMAC[i-1].toUpperCase();
    }
  }
  $("#resetR, .resetR").click(function(){
    $(".button-delete:visible").click();
  });
