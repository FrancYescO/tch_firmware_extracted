var maxMobileWidth = 767;
var screenWidth = screen.width;
var mobileEditIndex;

var validStatus = {
  "on" : T["enabled"],
  "off" : T["disabled"],
}

var daysType = ["Every Day", "Every Workday", "All Weekend"];

//The days array contains days in right order and this order of arrangement is taken as reference
var days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat" ,"Sun"];

//The daysOrderInGUI array contains arrangement of days (checkboxes) as shown in GUI
//The daysOrderInGUI array is later used to sync up the arrangement of days with the above days array
//eg: When user selects checkbox for Saturday, it will be shown in right order in main schedule table by referring days array
var daysOrderInGUI = ["Mon", "Sat", "Tue", "Sun", "Wed", "Thu", "Fri"];
var translatedDays = [T[days[0]], T[days[1]], T[days[2]], T[days[3]], T[days[4]], T[days[5]], T[days[6]]];

var daysInSorted = {
  "Mon": 1,
  "Tue": 2,
  "Wed": 3,
  "Thu": 4,
  "Fri": 5,
  "Sat": 6,
  "Sun": 7
}

var dayTable = {
  "Mon, Tue, Wed, Thu, Fri, Sat, Sun" : "Every Day",
  "Mon, Tue, Wed, Thu, Fri"           : "Every Workday",
  "Sat, Sun"                          : "All Weekend",
}
var elements = {
  startTime: "[role=dialog].in [id$=start]:visible",
  endTime: "[role=dialog].in [id$=stop]:visible"
}

var validations = {
  startTime: timeRegExp,
  endTime: function(value) {
    return timeRegExp.test(value) && (formatTime(value) > formatTime($(elements.startTime).val()))
  }
}
$(function () {
  noRuleMessage("schedule-table");
  $('select').chosen({
    disable_search_threshold: 100000,
    allow_single_deselect: true
  });
});
$('.assign-add22').click(function() {
  var rC = $('.vdf-row.assign-row22').clone();
  rC.show();
  rC.removeClass('assign-row22').addClass('cloned');
  rC.insertAfter('.assign-row22');
  rC.find('select').removeClass('not-chosen');

  if ($('.cloned').length > 0) {
    $('.button-delete.op40').removeClass('op40');
    $('.cloned .button-delete').click(function() {
      $(this).closest('.vdf-row.cloned').remove();
      if ($('.cloned').length <= 0) {
        $('.assign-add22').parents('#ringing-schedule-popup-add').find('.button-delete').addClass('op40');
      }
    });
  } else {
    $('.assign-row .button-delete').addClass('op40');
  }
});

function populateDaysMobile(id, daysOfWeek, selectedDay) {
  $("#" + id + " input").each(function(index) {
    if ($(this).prop("checked")) {
      daysOfWeek.push(translatedDays[index]);
      selectedDay.push(days[index]);
    }
  });
  return daysOfWeek, selectedDay;
}

$("#rngshd-btn-todstatus").click(function() {
  if ($(this).hasClass("button-on")) {
    $("#ringing-schedule-Errmsg").removeClass("show").addClass("hide");
    $(this).removeClass("button-on").addClass("button-off");
    $("#rngshd-hid-todstatus").val("0");
    $(this).closest(".h3-content").next(".hide-all").slideUp();
  } else {
    $(this).removeClass("button-off").addClass("button-on");
    $(this).closest(".h3-content").next(".hide-all").slideDown();
    $("#rngshd-hid-todstatus").val("1");
    var lengthValue = $("tbody").find("tr").length;
    if ( lengthValue <= 2) {
      $("#ringing-schedule-Errmsg").removeClass("hide").addClass("show");
      $("#ringing-schedule-Errmsg span").text(warningInfo[$("#rngshd-select-status").val()]);
    }
  }
  if ($(this).hasClass('changed')) {
    $(this).removeClass('changed');
    sessionStorage.setItem("user_interacted", "pristine");
  } else if(vdfVariant == "NZ") {
    $(this).addClass('changed');
    checkForUserEvent();
  }
});
$("#rngshd-select-day").change(function() {
  if ($(this).val() === "Individual Days") {
    $(".rngshd-div-inddays").css("display", "table-row");
    if (screenWidth <= maxMobileWidth) { $("#rngshd-div-mobinddays").removeClass("hide").addClass("show"); }
  } else {
    $(".rngshd-div-inddays").css("display", "none");
    if (screenWidth <= maxMobileWidth) { $("#rngshd-div-mobinddays").removeClass("show").addClass("hide"); }
  }
});
$("#rngshd-btn-add, #rngshd-btn-mobadd").click(function() {
  $("#rngshd-select-day").val("Every Workday").trigger("chosen:updated");
  $("#rngshd-txt-start, #rngshd-txt-stop").val("00:00");
  $(".rngshd-div-inddays").css("display", "none");
  $(".rngshd-div-inddays input[type=\"checkbox\"]").each(function(){$(this).prop("checked", false);});
  $("#rngshd-div-mobinddays input[type=\"checkbox\"]").each(function(){$(this).prop("checked", false);});
  $("#rngshd-div-mobinddays").removeClass("show").addClass("hide");
  $("#rngshd-txt-mobstart, #rngshd-txt-mobstop").val("00:00");
});
$("#rngshd-btn-addsave").click(function() {
  if (!validateElements(elements, validations)) return false;
  $("#ringing-schedule-popup-add").modal("hide");
  var profileName = $("#rngshd-select-profile").text();
  var profileValue = $("#rngshd-select-profile").val();
  if (profileValue === "All") {
    profileName = T["All"];
  }  else {
    profileName = profileValue;
  }
  var start = $("#rngshd-txt-start").val();
  var stop = $("#rngshd-txt-stop").val();
  if (screenWidth <= maxMobileWidth){
    start =  $("#rngshd-txt-mobstart").val();
    stop = $("#rngshd-txt-mobstop").val();
  }
  var selectedDay = $("#rngshd-select-day").val();
  var daysOfWeek = [];
  if (daysType.indexOf(selectedDay) === -1) {
    selectedDay = [];
    if (screenWidth <= maxMobileWidth) {
      daysOfWeek, selectedDay = populateDaysMobile("rngshd-div-mobinddays", daysOfWeek, selectedDay);
    } else {
      var dayIndex;
      $("#rngshd-div-adddays .rngshd-div-inddays input").each(function(index) {
        if ($(this).prop("checked")) {
          dayIndex = days.indexOf(daysOrderInGUI[index]);
          daysOfWeek.push(translatedDays[dayIndex]);
          selectedDay.push(days[dayIndex]);
          daysOfWeek.sort(function(a, b) { return translatedDays.indexOf(a) > translatedDays.indexOf(b); });
          selectedDay.sort(function sortByDay(a, b) {
            return daysInSorted[a] > daysInSorted[b];
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
      daysOfWeek = $("#rngshd-select-day option:selected").text();
    }
    $('<tr class=\"cloned\" data-type=\"add\">\
        <input type=\"hidden\" class=\"dayType\" value=\"' + selectedDay + '\">\
        <input type=\"hidden\" class=\"profileValue\" value=\"' + profileValue + '\">\
        <input type=\"hidden\" class=\"MobprofileValue\" value=\"' + profileValue + '\">\
        <input type=\"hidden\" class=\"row-index\" value=\"new\">\
          <td class = \"weekday\">\
            <span>'+daysOfWeek+'</span></td>\
          <td class = \"time\"><span>'+T["from"]+'&nbsp;</span>'+formatTime($.trim(start))+'<span>&nbsp;'+T["to"]+'&nbsp;</span>'+formatTime($.trim(stop))+'</td>\
          <td class = \"profile\"><span>'+profileName+'</span></td>\
          <td>\
            <div class=\"schedule-on status\"><span>'+serviceClass+'</span></div>\
          </td>\
          <td><input class=\"button button-edit\" value="" type=\"button\" data-toggle=\"modal\" data-target=\"#ringing-schedule-popup-edit\" onclick=\"copyEditableFields(this)\" ></td>\
          <td><input class=\"button button-delete\" value="" type=\"button\"></td>\
          </tr>').insertBefore("#last-row")
          $('<div class=\"mobile-table-row\">\
              <input type=\"hidden\" class=\"row-index\" value=\"new\">\
              <div class=\"vdf-row mobile-row-half\">\
                <div class=\"left time\">\
                  <span>'+T["from"]+'&nbsp;</span>'+formatTime(start)+'<span>&nbsp;'+T["to"]+'&nbsp;</span>'+formatTime(stop)+'</div>\
                <div class=\"right status\">\
                  <div class=\"schedule-on\"><span>'+serviceClass+'</span></div>\
                </div>\
              </div>\
              <div class=\"vdf-row\">\
                <div class=\"left weekdays\">\
                  <span>'+daysOfWeek+'</span></div>\
              </div>\
              <div class=\"vdf-row number-row\">\
                <div class=\"left profile\">\
                  <span>'+profileName+'</span></div>\
              </div>\
              <div class=\"vdf-row mobile-row-half mobile-button-row\">\
                <div class=\"left\">\
                  <input class=\"button button-edit\" value="" type=\"button\">\
                </div>\
                <div class="right">\
                  <input class=\"button button-delete\" value="" type=\"button\">\
                </div>\
              </div>\
            </div>').insertBefore("#mob-last-row")
  noRuleMessage("schedule-table")
  var lengthValue = $("tbody").find("tr").length;
  if (lengthValue > 2) {
    $("#ringing-schedule-Errmsg").removeClass("show").addClass("hide");
  }
});
function copyEditableFields(element) {
  editedRow = element;
  modifiedRow = $(element).closest(".cloned");
  var editedRowIndex = modifiedRow.find(".row-index");
  if (editedRowIndex.val() == "new" && vdfVariant == "NZ") {
    // Used to restrict page navigation on selecting Cancel within a new rule that is edited
    sessionStorage.setItem("newRule_edit", "true");
  }
  var dayIndex;
  $(".rngshd-div-editinddays input").each(function() {$(this).prop("checked", 0)});
  var thisRow = $(editedRow).closest("tr");
  var selectedDay = thisRow.find(".dayType").val();
  var profile;
  if (screenWidth <= maxMobileWidth) {
    profile = thisRow.find(".MobprofileValue").val();
  } else {
    profile = thisRow.find(".profileValue").val();
  }
  var time = thisRow.find(".time").text().trim();
  var regExp = /([0-1][0-9]|2[0-3]|[1-9])[:\s]*([0-5][0-9])?[\s]*?/gi;
  var timeArray = time.match(regExp);
  var startTime = timeArray[0];
  var stopTime = timeArray[1];
  $("#rngshd-txt-popupeditstart, #rngshd-txt-mobeditstart").val(startTime);
  $("#rngshd-txt-popupeditstop, #rngshd-txt-mobeditstop").val(stopTime);
  $("#rngshd-select-editprofile").val(profile).trigger("chosen:updated")
  $(".rngshd-div-editinddays").css("display", "none");
  if (screenWidth <= maxMobileWidth) { $("#rngshd-div-mobeditinddays").removeClass("show").addClass("hide"); }
  if (daysType.indexOf(selectedDay) === -1) {
    selectedDay = selectedDay.split(", ")
    $(".rngshd-div-editinddays").css("display", "table-row");
    if (screenWidth <= maxMobileWidth) $("#rngshd-div-mobeditinddays").removeClass("hide").addClass("show");
    $("#rngshd-select-editday").val("Individual Days").trigger("chosen:updated")
    for (i = 0; i < selectedDay.length; i++) {
      if (days.indexOf(selectedDay[i] !== -1)) {
        if (screenWidth > maxMobileWidth) {
          dayIndex = daysOrderInGUI.indexOf(selectedDay[i]);
          $(".rngshd-div-editinddays input:eq(" + dayIndex +")").prop("checked", 1);
        }
        $("#rngshd-div-mobeditinddays input:eq(" + days.indexOf(selectedDay[i]) +")").prop("checked", 1);
      }
    }
  } else {
    $("#rngshd-select-editday").val(selectedDay).trigger("chosen:updated")
  }
}
$("#rngshd-select-editday").change(function() {
  if ($(this).val() === "Individual Days") {
    $(".rngshd-div-editinddays").css("display", "table-row");
    if (screenWidth <= maxMobileWidth) { $("#rngshd-div-mobeditinddays").removeClass("hide").addClass("show"); }
  } else {
    $(".rngshd-div-editinddays").css("display", "none");
    if (screenWidth <= maxMobileWidth){ $("#rngshd-div-mobeditinddays").removeClass("show").addClass("hide"); }
  }
});
$("#rngshd-btn-editsave").click(function() {
  if (!validateElements(elements, validations)) return false;
  $("#ringing-schedule-popup-edit").modal("hide");
  var selectedDay = $("#rngshd-select-editday").val();
  var profile = $("#rngshd-select-editprofile").val();
  var daysOfWeek = [];
  if (daysType.indexOf(selectedDay) === -1) {
    selectedDay = [];
    if (screenWidth <= maxMobileWidth) {
      daysOfWeek, selectedDay = populateDaysMobile("rngshd-div-mobeditinddays", daysOfWeek, selectedDay);
    } else {
      $("#rngshd-div-editdays .rngshd-div-editinddays input").each(function(index) {
        if ($(this).prop("checked")) {
          dayIndex = days.indexOf(daysOrderInGUI[index]);
          daysOfWeek.push(translatedDays[dayIndex]);
          selectedDay.push(days[dayIndex]);
          selectedDay.sort(function sortByDay(a, b) {
            return daysInSorted[a] > daysInSorted[b];
          });
          daysOfWeek.sort(function(a, b) { return translatedDays.indexOf(a) > translatedDays.indexOf(b); });
        }
      });
    }
    daysOfWeek = daysOfWeek.join(", ");
    selectedDay = selectedDay.join(", ");
    if (dayTable[daysOfWeek]) {
      daysOfWeek = dayTable[daysOfWeek];
    }
  } else {
    daysOfWeek = $("#rngshd-select-editday option:selected").text();
  }
  var startTime = $("#rngshd-txt-popupeditstart").val();
  var endTime = $("#rngshd-txt-popupeditstop").val();
  if (screenWidth <= maxMobileWidth) {
    startTime = $("#rngshd-txt-mobeditstart").val();
    endTime = $("#rngshd-txt-mobeditstop").val();
  }
  var thisRow = $(editedRow).closest("tr");
  if ((thisRow.attr("data-type"))!== "add") {
    thisRow.attr("data-type", "edit");
  }
  var mobRow = $("#rngshd-tbl-mobschedule .button-edit").eq(mobileEditIndex).closest(".mobile-table-row")
  mobRow.find(".weekday").html("<span>"+daysOfWeek+"</span>");
  mobRow.find(".time").html("<span>"+T["from"]+"&nbsp;</span>"+formatTime(startTime)+"<span>&nbsp;"+T["to"]+"&nbsp;</span>"+formatTime(endTime));
  if (profile === "All")
  {
    mobRow.find(".profile").html("<span>"+T["All"]+"</span>");
  } else {
    mobRow.find(".profile").html("<span>"+profile+"</span>");
  }  
  mobRow.find(".MobprofileValue").val(profile);
  thisRow.find(".weekday").text(daysOfWeek);
  thisRow.find(".dayType").val(selectedDay);
  thisRow.find(".time").html("<span>"+T["from"]+"&nbsp;</span>"+formatTime(startTime)+"<span>&nbsp;"+T["to"]+"&nbsp;</span>"+formatTime(endTime));
  if (profile === "All")
  {
    thisRow.find(".profile").text(T["All"]);
  } else {
    thisRow.find(".profile").text(profile);
  }
  thisRow.find(".profileValue").val(profile);
});

var delData = [];
$("#schedule-table").on("click", ".button-delete", function() {
  var currentRow = $(this).closest("tr");
  var rowIndex = currentRow.find(".row-index");
  if (rowIndex.val() == "new" && vdfVariant == "NZ") {
    // To avoid navigation restriction when new unsaved rule is deleted
    sessionStorage.setItem("delete_bypass", "true");
  }
  if ($(this).attr("data-value")) {
    delData.push({"index":$(this).attr("data-value")});
  }
  $(this).closest("tr").remove();
  noRuleMessage("schedule-table");
  var lengthValue = $("tbody").find("tr").length;
  if (lengthValue <= 2) {
    $("#ringing-schedule-Errmsg").removeClass("hide").addClass("show");
    $("#ringing-schedule-Errmsg span").text(warningInfo[$("#rngshd-select-status").val()]);
  }
});

function commonApply(todStatus){
  var tableData = {};
  var addData = [];
  var updateData = [];
  var params = [];
  var actionModified = false;
  var isDuplicate = false;
  var isError = false;
  var regExp = /([0-1][0-9]|2[0-3]|[1-9])[:\s]*([0-5][0-9])?[\s]*?/gi;
  var profileStatus = $("#rngshd-select-status").val();
  $(".cloned").each(function(index1){
    name1 = $(this).find(".name").text();
    profile1 = $(this).find(".profile").text();
    time1 = $(this).find(".time").text();
    status1 = $(this).find(".status").text();
    day1 = $(this).find(".day").text();
    var timeArray1 = time1.match(regExp);
    var start1 = timeArray1[0];
    var stop1 = timeArray1[1];
    if (start1 === stop1) {
      isError = true;
      return false;
    }
    $(".cloned").each(function(index2) {
      if (index2 > index1) {
        isDuplicate = false;
        isError = false;
        name2 = $(this).find(".name").text();
        profile2 = $(this).find(".profile").text();
        time2 = $(this).find(".time").text();
        status2 = $(this).find(".status").text();
        day2 = $(this).find(".day").text();
        timeArray2 = time2.match(regExp);
        start2 = timeArray2[0];
        stop2 = timeArray2[1];

        if ((profile1 === profile2)&& (name1 === name2) && (status1 === status2) && (start1 === start2) && (stop1 === stop2)) {
          isDuplicate = true;
          return false;
        }
        if ((start1 >= stop1 && (start1 === "00:00" || stop1 === "00:00" )) || (start2 >= stop2  && (start2 === "00:00" || stop2 === "00:00" ))) {
          isError = true;
          return false;
        }
        if (start1 === stop1 || start2 === stop2 ) {
          isError = true; return false;
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
    if($(this).attr("data-type") === "add") {
      var day = $(this).find(".dayType").val();
      var profile;
      if (screenWidth <= maxMobileWidth) {
        profile = $(this).find(".MobprofileValue").val();
      } else {
        profile = $(this).find(".profileValue").val();
      }
      var time = $(this).find(".time").text();
      var timeArray3 = time.match(regExp);
      var starttime = timeArray3[0];
      var stoptime = timeArray3[1];
      addData.push({"days":day, "starttime":starttime, "stoptime":stoptime, "profile":profile});
    }
    if($(this).attr("data-type") === "edit") {
      var day = $(this).find(".dayType").val();
      var profile;
      if (screenWidth <= maxMobileWidth) {
        profile = $(this).find(".MobprofileValue").val();
      } else {
        profile = $(this).find(".profileValue").val();
      }
      var time = $(this).find(".time").text();
      var timeArray4 = time.match(regExp);
      var starttime = timeArray4[0];
      var stoptime = timeArray4[1];
      var index = $(this).find(".button-edit").attr("data-value");
      updateData.push({"index":index, "days":day, "starttime":starttime, "stoptime":stoptime, "profile":profile});
    }
  });
  tableData["ADD"] = addData;
  tableData["UPDATE"] = updateData;
  tableData["DELETE"] = delData;
  tableData = JSON.stringify(tableData);
  if ((status !== profileStatus) || (oldTodStatus !== todStatus)) {
    actionModified = true;
  }
  params.push({
    name: "tableRequest",
    value: tableData
  }, {
    name: "profileStatus",
    value: profileStatus
  }, {
    name: "todStatus",
    value: todStatus
  }, {
    name: "actionModified",
    value: actionModified
  }, {
    name: "action",
    value: "SAVE"
  }, {
    name: "CSRFtoken",
    value: $('meta[name=CSRFtoken]').attr("content")
  })
  postHandle("modals/phone/ringingSchedule.lp", params, true);
}

$("#rngshd-tbl-mobschedule").on("click", ".button-edit", function() {
  var thisIndex = $("#rngshd-tbl-mobschedule .button-edit").index(this);
  $("#schedule-table .button-edit").eq(thisIndex).trigger("click");
  mobileEditIndex = thisIndex;
});

$("#rngshd-tbl-mobschedule").on("click", ".button-delete", function() {
  var thisIndex = $("#rngshd-tbl-mobschedule .button-delete").index(this);
  $(this).closest(".mobile-table-row").remove();
  var desktopRow = $("#schedule-table .cloned").eq(thisIndex);
  var deletedRowIndex = desktopRow.find(".row-index");
  if (deletedRowIndex.val() == "new" && vdfVariant == "NZ") {
    // To avoid navigation restriction when new unsaved rule is deleted
    sessionStorage.setItem("delete_bypass", "true");
  }
  desktopRow.remove();
  if (desktopRow.attr("data-value")) {
    delData.push({"index":desktopRow.attr("data-value")});
  }
  noRuleMessage("schedule-table");
  var lengthValue = $("tbody").find("tr").length;
  if (lengthValue <= 2) {
    $("#ringing-schedule-Errmsg").removeClass("hide").addClass("show");
    $("#ringing-schedule-Errmsg span").text(warningInfo[$("#rngshd-select-status").val()]);
  }
});

$("#rngshd-select-status").change(function() {
  $(".status").html("<span>"+validStatus[$(this).val()]+"</span>")
  serviceClass = validStatus[$(this).val()];
  $("#ringing-schedule-Errmsg span").text(warningInfo[$("#rngshd-select-status").val()]);
});

$("#global-cancel").click(function() {
  $("#content").load("/modals/phone/ringingSchedule.lp");
});
$("#resetR, .resetR").click(function() {
  $("#rngshd-btn-todstatus").val(resetringschedule_ringinsschedule_enable);
  if (resetringschedule_ringinsschedule_enable === "1") {
    $('#rngshd-btn-todstatus').addClass('button-on').removeClass('button-off');
    $('#rngshd-hid-todstatus').val("1");
    $('.hide-all').show();
  } else {
    $('#rngshd-btn-todstatus').addClass('button-off').removeClass('button-on');
    $('#rngshd-hid-todstatus').val("0");
    $('.hide-all').hide();
  }
  $('#rngshd-select-status').val(resetringschedule_duringthistime).trigger("chosen:updated");
  $('.button-delete').click();
});

/*Seperate function to handle post request for giving control to the page once the request(success/error) from server is obtained*/
/*This prevents the user from manipulating the page in between a post request*/
function postHandle(target, params) {
  applyCancelPopupHide();
  $.post(target, params, function(responseText, status) {
     $("#rngshd-btn-add").prop("disabled", true);
     $(".cloned #rngshd-btn-edit").prop("disabled", true);
     $(".cloned #rngshd-btn-delete").prop("disabled", true);
     $("#rngshd-btn-mobadd").prop("disabled", true);
     $("#rngshd-btn-mobedit").prop("disabled", true);
     $("#rngshd-btn-mobdelete").prop("disabled", true);
    if (responseText.status === "success") {
      $(".articlediv > .msg-error").removeClass("show").addClass("hide");
      $(".articlediv > .msg-warning").removeClass("show").addClass("hide");
      $(".articlediv > .message-arrowbox-applied").removeClass("hide").addClass("show");
      }
    else if(responseText.status === "error") {
      $(".articlediv > .msg-error").removeClass("hide").addClass("show");
      $(".articlediv > .msg-warning").removeClass("show").addClass("hide");
      $(".articlediv > .message-arrowbox-applied").removeClass("show").addClass("hide");
    }
    $(".articlediv").removeClass("hide").addClass("show");
    setTimeout(function(){ $(".articlediv").removeClass("show").addClass("hide")}, 3000);
    if (responseText.status === "success") {
      setTimeout(function(){
      $("#content").load("/modals/phone/ringingSchedule.lp");}, 3000);
    }
    else
    {
     $("#rngshd-btn-add").prop("disabled", false);
     $("#rngshd-btn-edit").prop("disabled", false);
     $("#rngshd-btn-delete").prop("disabled", false);
     $("#rngshd-btn-mobadd").prop("disabled", false);
     $("#rngshd-btn-mobedit").prop("disabled", false);
     $("#rngshd-btn-mobdelete").prop("disabled", false);
    }
  });
}
$("#global-apply, #modal-apply").click(function(){
  var todStatus
  if ( $("#rngshd-btn-todstatus").hasClass("button-on")){
    todStatus = 1;
  }else {todStatus = 0;}
  var lengthValue = $("tbody").find("tr").length
  if ( lengthValue <= 2 && todStatus == 1) {
    $("#ringing-schedule-Errmsg").removeClass("hide").addClass("show");
    $("#ringing-schedule-Errmsg span").text(warningInfo[$("#rngshd-select-status").val()]);
  }
  if (vdfVariant == "NZ"){
    // Save data to sessionStorage
    if (typeof(Storage) !== "undefined") {
      sessionStorage.setItem("user_interacted", "pristine");
    }
  } else {
    console.log("Sorry! No Web Storage support..");
  }
  commonApply(todStatus);
});
