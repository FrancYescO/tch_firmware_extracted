var screenWidth = screen.width;
var mobileEditIndex;
var maxMobileWidth = 767;
var todRegExp = /([0-1][0-9]|2[0-3]|[1-9])[:\s]*([0-5][0-9])?[\s]*?/gi;
var daysType = ["Every Day", "Every Workday", "All Weekend"];
var days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
var translatedDays = [T[days[0]], T[days[1]], T[days[2]], T[days[3]], T[days[4]], T[days[5]], T[days[6]]];
var isEdit = false;
var maxRowIndex = 0;

//The daysOrderInGUI array contains arrangement of days (checkboxes) as shown in GUI
//The daysOrderInGUI array is later used to sync up the arrangement of days with the above days array
//eg: When user selects checkbox for Saturday, it will be shown in right order in main schedule table by referring days array
var daysOrderInGUI = ["Mon", "Sat", "Tue", "Sun", "Wed", "Thu", "Fri"];

var dayTable = {
  "Mon, Tue, Wed, Thu, Fri, Sat, Sun" : "Every Day",
  "Mon, Tue, Wed, Thu, Fri"           : "Every Workday",
  "Sat, Sun"                          : "All Weekend",
}

var daySplit = {
  "Every Day"    : {value : "Mon, Tue, Wed, Thu, Fri, Sat, Sun", status: "true"},
  "Every Workday": {value :"Mon, Tue, Wed, Thu, Fri", status: "true"},
  "All Weekend"  : {value :"Sat, Sun", status: "true"}
}

var elements = {
  ruleName: "[role=dialog].in [id$=name]:visible",
  startTime: "[role=dialog].in [id$=start]:visible",
  endTime: "[role=dialog].in [id$=stop]:visible"
}

var validations = {
  ruleName: function(value) { return validateStringLength(1, 63)(value) && isASCII(value)},
  startTime: timeRegExp,
  endTime: function(value) {
    return timeRegExp.test(value) && (formatTime(value) > formatTime($(elements.startTime).val()))
  }
}


//@function populateDaysMobile
//@param id : Checkbox element id in mobile view
//@param daysOfWeek : Empty array
//@param selectedDay : Empty array
//returns daysOfWeek(will have days strings in english) and selectedDay(will have its translated text)
function populateDaysMobile(id, daysOfWeek, selectedDay) {
  $("#" + id + " input").each(function(index) {
    if ($(this).prop("checked")) {
      daysOfWeek.push(translatedDays[index]);
      selectedDay.push(days[index]);
    }
  });
  return daysOfWeek, selectedDay;
}

//@function getUntranslated
//@param status (enabled/disabled) : contains text(Spanish if translated) as shown in the table
//returns the value(Corresponding untranslated text for the status)
function getUntranslated(status) {
  for (var key in T) {
    if (T[key] === status)
    {
      return key;
    }
  }
}

function copyEditableFields(element) {
  $("#psm-text-editname").removeClass("input-error");
  $("#psm-txt-editstart, #psm-txt-mobeditstart").removeClass("input-error");
  $("#psm-txt-editstop, #psm-txt-mobeditstop").removeClass("input-error");
  $(".duplicateedit-msg").css("display","none")
  $(".daySelectEdit-msg").css("display", "none")
  isEdit = true;
  editedRow = element;
  var modifiedRow = $(editedRow).closest("tr").find('.RowIndex').val();
  var dayIndex;
  $(".psm-sel-deseditinddays input").each(function() {$(this).prop("checked",0)})
  $("#psm-sel-mobeditinddays input").each(function() {$(this).prop("checked",0)})
  var thisRow = $(editedRow).closest("tr");
  var ruleName = thisRow.find(".name").text();
  var selectedDay = thisRow.find(".dayType").val();
  var status = thisRow.find(".status").text();
  status = getUntranslated(status);
  var time = thisRow.find(".time").text().trim();
  var timeArray = time.match(todRegExp);
  var startTime = timeArray[0];
  var stopTime = timeArray[1];
  var daysOfWeek;
  $("#psm-sel-editservice").val($.trim(status)).trigger("chosen:updated");
  $("#psm-text-editname").val(ruleName);
  $("#psm-txt-editstart, #psm-txt-mobeditstart").val(formatTime(startTime));
  $("#psm-txt-editstop, #psm-txt-mobeditstop").val(formatTime(stopTime));
  $(".psm-sel-deseditinddays").css("display", "none");
  $("#psm-sel-editdays").val(selectedDay).trigger("chosen:updated");
  if (modifiedRow == "new") {
    // Used to restrict page navigation on selecting Cancel within a new rule that is edited
    sessionStorage.setItem("newRule_edit", "true");
  }
  if (screenWidth <= maxMobileWidth)
  {
    $("#psm-sel-mobeditinddays").removeClass("show").addClass("hide");
  }
  if (daysType.indexOf(selectedDay) === -1) {
    selectedDay = selectedDay.split(", ");
    $(".psm-sel-deseditinddays").removeClass("hide").css("display", "table-row");
    if (screenWidth <= maxMobileWidth)
    {
      $("#psm-sel-mobeditinddays").removeClass("hide").addClass("show");
    }
    $("#psm-sel-editdays").val("Individual Days").trigger("chosen:updated")
    for (i = 0; i < selectedDay.length; i++) {
      if (days.indexOf(selectedDay[i] !== -1)) {
        if (screenWidth > maxMobileWidth) {
          dayIndex = daysOrderInGUI.indexOf(selectedDay[i]);
          $(".psm-sel-deseditinddays input:eq(" + dayIndex +")").prop("checked", 1);
        }
        $("#psm-sel-mobeditinddays input:eq(" + days.indexOf(selectedDay[i]) +")").prop("checked", 1);
      }
    }
  } else {
    $("#psm-sel-editdays").val(selectedDay).trigger("chosen:updated")
  }
}
function duplicateCheck(selectedDay, startVal, stopVal, classname){
  var isduplicateFound = false
  var dayArray
  var selectedArray
  $(".cloned").each(function(){
    dayValue = $(this).find(".day").text();
    if (daySplit[dayValue] && daySplit[dayValue].status){
      dayValue = daySplit[dayValue].value
    }
    dayArray = dayValue.split(",");
    for (i = 0; i < dayArray.length; i++){
      dayArray[i] = dayArray[i].trim();
    }

    if (daySplit[selectedDay] && daySplit[selectedDay].status){
      selectedDay = daySplit[selectedDay].value
    }
    selectedArray = selectedDay.split(",");
    for (i = 0; i < selectedArray.length; i++){
      selectedArray[i] = selectedArray[i].trim();
    }
    timeValue = $(this).find(".time").text();
    var timeArrayval = timeValue.match(todRegExp);
    var startValue = timeArrayval[0];
    var stopValue = timeArrayval[1];
    var RowIndex = $(this).find('.RowIndex').val();
    if (Number(RowIndex) > Number(maxRowIndex)){
      maxRowIndex = RowIndex;
    }
    var editedRowIndex = 0;
    if (isEdit) {
      editedRowIndex = $(editedRow).closest("tr").closest("tr").find('.RowIndex').val();
    }
    if (RowIndex != editedRowIndex){
      for (i = 0; i < selectedArray.length; i++) {
        if (dayArray.indexOf(selectedArray[i]) !== -1){
          if ((startValue == startVal && stopValue == stopVal) || (startVal <= stopValue && stopVal >= startValue)) {
            isduplicateFound = true;
            $(classname).css("display","")
            break;
          }
        }
      }
    }
  });
  return isduplicateFound;
}
$(function() {
  noRuleMessage("psm-tbl-desschedule");
  $('select').chosen({
    disable_search_threshold: 100000,
    allow_single_deselect: true
  });
  if ($("#psm-btn-enablestatus").hasClass("button-on")) {
    $("#psm-btn-enablestatus").closest(".h3-content").next(".scheduleOnOff").show();
  } else {
    $("#psm-btn-enablestatus").closest(".h3-content").next(".scheduleOnOff").hide();
  }
  $("#psm-btn-enablestatus").click(function() {
    detectToggleChanges($(this));
    if ($(this).hasClass("button-on")) {
      $(this).removeClass("button-on").addClass("button-off");
      $(this).closest(".h3-content").next(".scheduleOnOff").slideUp();
    } else {
      $(this).removeClass("button-off").addClass("button-on");
      $(this).closest(".h3-content").next(".scheduleOnOff").slideDown();
    }
  });
  $("#psm-sel-editdays").change(function() {
    if ($(this).val() === "Individual Days") {
      $("#psm-div-desaddays").removeClass("hide").addClass("show");
      $(".psm-sel-deseditinddays").removeClass("hide").css("display","table-row");
      if (screenWidth <= maxMobileWidth) {
        $("#psm-sel-mobeditinddays").removeClass("hide").addClass("show");
      }
    } else {
      $(".psm-sel-deseditinddays").css("display", "none").addClass("hide");
      if (screenWidth <= maxMobileWidth) {
        $("#psm-sel-mobeditinddays").removeClass("show").addClass("hide");
      }
    }
  });
  $("#psm-btn-add, #psm-btn-mobadd").click(function() {
    if ($("#psm_sel_day_chosen .result-selected").html() == "Individual Days") {
      $("#psm-div-desaddays").removeClass("hide").addClass("show");
      $(".psm-div-desaddinddays").removeClass("hide").css("display","table-row");
      if (screenWidth <= maxMobileWidth) {
        $("#psm-div-mobaddinddays").removeClass("hide").addClass("show");
      }
    } else {
      $("#psm-div-desaddays").removeClass("show").addClass("hide");
      $(".psm-div-desaddinddays").css("display", "none").addClass("hide");
      if (screenWidth <= maxMobileWidth) {
        $("#psm-div-mobaddinddays").removeClass("show").addClass("hide");
      }
    }
    $("#psm-txt-rulename").removeClass("input-error");
    $("#psm-txt-start").removeClass("input-error");
    $("#psm-txt-stop").removeClass("input-error");
    $(".duplicate-msg").css("display", "none")
    $(".daySelect-msg").css("display", "none")
    isEdit = false;
    $("#psm-sel-day").val("Every Workday").trigger("chosen:updated");
    $("#psm-txt-start").val("00:00");
    $("#psm-txt-stop").val("00:00");
    $("#psm-sel-service").val("enabled").trigger("chosen:updated");
    $("#psm-txt-rulename").val("");
    $(".psm-div-desaddinddays").removeClass("hide").css("display", "table-row");
    $(".psm-div-desaddinddays input[type=\"checkbox\"]").each(function() {
      $(this).prop("checked", false);
    });
    $("#psm-div-mobaddinddays input[type=\"checkbox\"]").each(function() {
      $(this).prop("checked", false);
    });
    $("#psm-div-mobaddinddays").removeClass("hide").addClass("show");
    $("#psm-txt-mobstart, #psm-txt-mobstop").val("00:00");
  });

  $("#psm-btn-save").click(function() {
    if (!validateElements(elements, validations)) {
      return false;
    }
    var ruleName = $("#psm-txt-rulename").val();
    var start = $("#psm-txt-start").val()
    var stop = $("#psm-txt-stop").val()
    if ($("#psm-txt-start").val() === "00:00" && $("#psm-txt-stop").val() === "00:00") {
      start =  $("#psm-txt-mobstart").val();
      stop = $("#psm-txt-mobstop").val();
    }
    var serviceEnabled = $("#psm-sel-service").val();
    serviceEnabled = T[serviceEnabled];
    var daysOfWeek = [];
    var selectedDay = $("#psm-sel-day").val();
    if (daysType.indexOf(selectedDay) === -1) {
      selectedDay = [];
      if (screenWidth <= maxMobileWidth) {
        daysOfWeek, selectedDay = populateDaysMobile("psm-div-mobaddinddays", daysOfWeek, selectedDay);
      } else {
      var dayIndex;
      $("#psm-div-desaddays .psm-div-desaddinddays input").each(function(index) {
        if ($(this).prop("checked")) {
          dayIndex = days.indexOf(daysOrderInGUI[index]);
          daysOfWeek.push(translatedDays[dayIndex]);
          selectedDay.push(days[dayIndex]);
          daysOfWeek.sort(function(a, b) { return translatedDays.indexOf(a) > translatedDays.indexOf(b); });
          selectedDay.sort(function sortByDay(a, b) {
            return days.indexOf(a) > days.indexOf(b);
          });
        }
      });
    }

    //The selectedDay contains values (days) which need to be seperated by comma because multiple values need to be set for the same param in transformer
    //Since values seperated by space will not be accepted by transformer
    selectedDay = selectedDay.join(", ");
    //The daysOfWeek contains (days) which will be in text format that need to be shown in GUI
    daysOfWeek = daysOfWeek.join(", ");
    } else {
      daysOfWeek = $("#psm-sel-day option:selected").text();
    }
    if(daysOfWeek == ""){
      $(".daySelect-msg").css("display","")
      return false;
    }
    if(!duplicateCheck(selectedDay, start, stop, ".duplicate-msg")){
      $("#psm-div-addmodal").modal("hide");
      var newRowCount = Number(maxRowIndex) + 1;
      $('<tr class=\"cloned\" id=\"schedule-table-list\" style=\"display: table-row;\" data-type=\"add\">\
      <input type=\"hidden\" class=\"RowIndex\" value=\"new\">\
      <input type=\"hidden\" class=\"dayType\" value=\"' + selectedDay + '\">\
          <td class=\"day\"><span>'+daysOfWeek+'</span></td>\
          <td class=\"time\"><span>'+T["from"]+'&nbsp;</span>'+formatTime($.trim(start))+'<span>&nbsp;'+T["to"]+'&nbsp;</span>'+formatTime($.trim(stop))+'</td>\
          <td class=\"enable status\" style=""><span>'+serviceEnabled+'</span></td>\
          <td class=\"name\" >'+ruleName+'</td>\
          <td class=\"tL\"><input class=\"button button-edit\" value="" type=\"button\" data-toggle=\"modal\" data-target=\"#psm-editPopup\"  onclick=\"copyEditableFields(this)\" ></td>\
          <td class=\"tL\" style=\"text-align:right\"><input class=\"button button-delete\" value="" type=\"button\"></td>\
      </tr>').insertBefore("#tod-row-last");
      $('<tr class=\"mob-cloned\">\
        <td> <table class= \"mobile-table\"> <tbody><tr class=\"template-row-1 row-1\" >\
        <td class =\"time\"><span>'+T["from"]+'&nbsp;</span>'+formatTime(start)+'<span>&nbsp;'+T["to"]+'&nbsp;</span>'+formatTime(stop)+'</td>\
        <td class=\"enable right-td status\" style=""><span>'+serviceEnabled+'</span>\
        </td>\
      </tr>\
      <tr class=\"template-row-2 row-2\" >\
        <td class = \"day\"><span>'+daysOfWeek+'</span>\
        </td>\
      </tr>\
      <tr class=\"template-row-3 name-row row-3\" >\
        <td class= \"name\">'+ruleName+'</td>\
      </tr>\
      <tr class=\"template-row-4 edit-row row-4\">\
        <td class=\"tL\">\
            <input class=\"button button-edit\" type=\"button\" value="">\
        </td>\
        <td class=\"tL right-td\">\
            <input class=\"button button-delete\" type=\"button\" value="">\
        </td>\
      </tr>\ </tbody></table></td></tr>').insertBefore("#tod-row-moblast")
      noRuleMessage("psm-tbl-desschedule")
    }
  });
  $("#psm-btn-editsave").click(function() {
    if (!validateElements(elements, validations)) return false;
    var ruleName = $("#psm-text-editname").val();
    var selectedDay = $("#psm-sel-editdays").val();
    var serviceEnabled = $("#psm-sel-editservice").val();
    serviceEnabled = T[serviceEnabled];
    var daysOfWeek = [];
    if (daysType.indexOf(selectedDay) === -1) {
      selectedDay = [];
      if (screenWidth <= maxMobileWidth) {
        daysOfWeek, selectedDay = populateDaysMobile("psm-sel-mobeditinddays", daysOfWeek, selectedDay);
      } else {
        $("#psm-sel-deseditdays .psm-sel-deseditinddays input").each(function(index) {
          if ($(this).prop("checked")) {
            dayIndex = days.indexOf(daysOrderInGUI[index]);
            daysOfWeek.push(translatedDays[dayIndex]);
            selectedDay.push(days[dayIndex]);
            selectedDay.sort(function sortByDay(a, b) {
              return days.indexOf(a) > days.indexOf(b);
            });
            daysOfWeek.sort(function(a, b) { return translatedDays.indexOf(a) > translatedDays.indexOf(b); });
          }
        });
      }
      daysOfWeek = daysOfWeek.join(", ");
      selectedDay = selectedDay.join(", ");
      if (dayTable[daysOfWeek]) {
        daysOfWeek = dayTable[daysOfWeek]
      }
    } else {
      daysOfWeek = $("#psm-sel-editdays option:selected").text();
    }
    if(daysOfWeek == ""){
      $(".daySelectEdit-msg").css("display","")
      return false;
    }
    var startTime = $("#psm-txt-editstart").val();
    var endTime = $("#psm-txt-editstop").val();
    if (screenWidth <= maxMobileWidth) {
      startTime = $("#psm-txt-mobeditstart").val();
      endTime = $("#psm-txt-mobeditstop").val();
    }
    var thisRow = $(editedRow).closest("tr");
    if ((thisRow.attr("data-type"))!== "add") {
      thisRow.attr("data-type","edit");
    }
    if(!duplicateCheck(selectedDay, startTime, endTime, ".duplicateedit-msg")){
      $("#psm-editPopup").modal("hide");
      var mobRow = $("#psm-tbl-mobschedule .button-edit").eq(mobileEditIndex).closest(".mob-cloned");
      mobRow.find(".name").text(ruleName);
      mobRow.find(".day").text(daysOfWeek);
      mobRow.find(".time").html("<span>"+T["from"]+"&nbsp;</span>"+formatTime(startTime)+"<span>&nbsp;"+T["to"]+"&nbsp;</span>"+formatTime(endTime));
      mobRow.find(".status").text(serviceEnabled);
      thisRow.find(".name").text(ruleName);
      thisRow.find(".day").text(daysOfWeek);
      thisRow.find(".dayType").val(selectedDay);
      thisRow.find(".time").html("<span>"+T["from"]+"&nbsp;</span>"+formatTime(startTime)+"<span>&nbsp;"+T["to"]+"&nbsp;</span>"+formatTime(endTime));
      thisRow.find(".status").text(serviceEnabled);
    }
  });

  $("#psm-sel-day").change(function() {
    if ($(this).val() === "Individual Days") {
      $("#psm-div-desaddays").removeClass("hide").addClass("show");
      $(".psm-div-desaddinddays").removeClass("hide").css("display","table-row");
      if (screenWidth <= maxMobileWidth) {
        $("#psm-div-mobaddinddays").removeClass("hide").addClass("show");
      }
    } else {
      $(".psm-div-desaddinddays").css("display", "none").addClass("hide");
      if (screenWidth <= maxMobileWidth) {
        $("#psm-div-mobaddinddays").removeClass("show").addClass("hide");
      }
    }
  });
  var delData =[];
  $("#psm-tbl-desschedule").on("click", ".button-delete", function() {
    var RowIndex = $(this).closest("tr").find('.RowIndex').val();
    if (RowIndex == "new" && vdfVariant == "NZ") {
      // To avoid navigation restriction when new unsaved rule is deleted
      sessionStorage.setItem("delete_bypass", "true");
    }
    if ($(this).attr("data-value")) {
      var status = $(this).closest("tr").find(".status").text();
      delData.push({"index":$(this).attr("data-value"), "status":status, "rowIndex":RowIndex});
    }
    $(this).closest("tr").remove();
    noRuleMessage("psm-tbl-desschedule")
  });
  $("#global-apply, #modal-apply").click(function() {
    $("#global-apply").prop("disabled", true);
    var tableData = {} ;
    var addData = [];
    var updateData = [];
    var params = [];
    var isDuplicate = false;
    var isError = false;
    $(".cloned").each(function(index1) {
      name1 = $(this).find(".name").text();
      time1 = $(this).find(".time").text();
      status1 = $(this).find(".status").text();
      day1 = $(this).find(".day").text();
      var timeArray1 = time1.match(todRegExp);
      var start1 = timeArray1[0];
      var stop1 = timeArray1[1];
      $(".cloned").each(function(index2) {
        if (index2 > index1) {
          isDuplicate = false;
          isError = false;
          name2 = $(this).find(".name").text();
          time2 = $(this).find(".time").text();
          status2 = $(this).find(".status").text();
          day2 = $(this).find(".day").text();
          timeArray2 = time2.match(todRegExp);
          start2 = timeArray2[0];
          stop2 = timeArray2[1];
          if (name1 === name2) {
            isDuplicate = true;
            return false;
          }
          if ((name1 === name2) && (status1 === status2) && (start1 === start2) && (stop1 === stop2)) {
            isDuplicate = true;
            return false;
          }
        }
      });
      if (isDuplicate || isError) {
        return false;
      }
    });
    if (isDuplicate || isError) {
      $("#global-apply").prop("disabled", false)
      $(".articlediv > .msg-error").removeClass("hide").addClass("show");
      $(".articlediv > .msg-warning").removeClass("show").addClass("hide");
      $(".articlediv > .message-arrowbox-applied").removeClass("show").addClass("hide");
      $(".articlediv").removeClass("hide").addClass("show");
      setTimeout(function() { $(".articlediv").removeClass("show").addClass("hide") }, 3000);
      return false;
    }
    $(".cloned").each(function() {
      if ($(this).attr("data-type") === "add") {
        var day = $(this).find(".dayType").val();
        var name = $(this).find(".name").text();
        var status = $(this).find(".status").text();
        status = getUntranslated(status);
        var time = $(this).find(".time").text();
        var timeArray3 = time.match(todRegExp);
        var starttime = timeArray3[0];
        var stoptime = timeArray3[1];
        addData.push({"name":name, "days":day, "starttime":starttime, "stoptime":stoptime, "status":status});
      }
      if ( $(this).attr("data-type") === "edit") {
        var day = $(this).find(".dayType").val();
        var name = $(this).find(".name").text();
        var status = $(this).find(".status").text();
        status = getUntranslated(status);
        var time = $(this).find(".time").text();
        var timeArray4 = time.match(todRegExp);
        var starttime = timeArray4[0];
        var stoptime = timeArray4[1];
        var index = $(this).find(".button-edit").attr("data-value");
        updateData.push({"index":index, "name":name, "days":day, "starttime":starttime, "stoptime":stoptime, "status":status});
      }
    });
    tableData["ADD"] = addData;
    tableData["UPDATE"] = updateData;
    if (delData.length !== 0) {
      delData.sort(function(a, b) {return b["rowIndex"]-a["rowIndex"]});
    }
    tableData["DELETE"] = delData;
    tableData = JSON.stringify(tableData);
    var statusButton = $("#psm-btn-enablestatus").hasClass("button-on") ? "1" : "0";
    params.push({name: "tableRequest", value:tableData}, {name: "status", value: statusButton}, {name: "CSRFtoken", value:$("meta[name=CSRFtoken]").attr("content") })
    postHandle("modals/wifi/powerSaving.lp", params, true);
  });
  $("#psm-tbl-mobschedule").on("click", ".button-edit", function() {
    var thisIndex = $("#psm-tbl-mobschedule .button-edit").index(this);
    $("#psm-tbl-desschedule .button-edit").eq(thisIndex).trigger("click");
    mobileEditIndex = thisIndex;
  });
  $("#psm-tbl-mobschedule").on("click", ".button-delete", function() {
    var thisIndex = $("#psm-tbl-mobschedule .button-delete").index(this);
    $(this).closest(".mob-cloned").remove();
    var desktopRow = $("#psm-tbl-desschedule .cloned").eq(thisIndex);
    var deletedRow = desktopRow.find(".RowIndex").val();
    if (deletedRow == "new" && vdfVariant == "NZ") {
      // To avoid navigation restriction when new unsaved rule is deleted
      sessionStorage.setItem("delete_bypass", "true");
    }
    if ($(this).attr("data-value")) {
      var status = desktopRow.find(".status").text();
      delData.push({"index":$(this).attr("data-value"), "status":status, "rowIndex":deletedRow});
    }
    desktopRow.remove();
    noRuleMessage("psm-tbl-desschedule");
  });
  $("#global-cancel").click(function() {
    $("#content").load("/modals/wifi/powerSaving.lp");
  });
  $("#resetR, .resetR").click(function() {
    $("#psm-btn-enablestatus").val("0");
    $("#psm-btn-enablestatus").closest(".h3-content").next(".scheduleOnOff").slideUp();
    $("#psm-btn-enablestatus").removeClass("button-on").addClass("button-off");
    $(".button-delete").click();
  });
});

/*Seperate function to handle post request for giving control to the page once the request(success/error) from server is obtained*/
/*This prevents the user from manipulating the page in between a post request*/
function postHandle(target, params) {
  applyCancelPopupHide();
  $.post(target, params, function(responseText, status) {
     $("#psm-btn-add").prop("disabled", true);
     $(".cloned #psm-btn-edit").prop("disabled", true);
     $(".cloned #psm-btn-delete").prop("disabled", true);
     $("#psm-btn-mobadd").prop("disabled", true);
     $("#psm-btn-mobedit").prop("disabled", true);
     $("#psm-btn-mobdelete").prop("disabled", true);
    if (responseText.status === "success") {
      $(".articlediv > .msg-error").removeClass("show").addClass("hide");
      $(".articlediv > .msg-warning").removeClass("show").addClass("hide");
      $(".articlediv > .message-arrowbox-applied").removeClass("hide").addClass("show");
      if (vdfVariant == "NZ") {
        if (typeof(Storage) !== "undefined") {
          // Save data to sessionStorage
          sessionStorage.setItem('user_interacted', "pristine");
        }
      }
    } else if (responseText.status === "error") {
      $(".articlediv > .msg-error").removeClass("hide").addClass("show");
      $(".articlediv > .msg-warning").removeClass("show").addClass("hide");
      $(".articlediv > .message-arrowbox-applied").removeClass("show").addClass("hide");
    }
    $(".articlediv").removeClass("hide").addClass("show");
    setTimeout(function(){ $(".articlediv").removeClass("show").addClass("hide")}, 3000);
    if (responseText.status === "success") {
      setTimeout(function(){
      $("#content").load("/modals/wifi/powerSaving.lp");}, 3000);
    } else {
      $("#psm-btn-add").prop("disabled", false);
      $(".cloned #psm-btn-edit").prop("disabled", false);
      $(".cloned #psm-btn-delete").prop("disabled", false);
      $("#psm-btn-mobadd").prop("disabled", false);
      $("#psm-btn-mobedit").prop("disabled", false);
      $("#psm-btn-mobdelete").prop("disabled", false);
      $("#global-apply").prop("disabled", false).removeClass("op 40");
    }
  });
}
