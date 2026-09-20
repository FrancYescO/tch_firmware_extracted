var maxMobileWidth = 480
var screenWidth = screen.width;
var mobileEditIndex
var todRegExp = /([0-1][0-9]|2[0-3]|[1-9])[:\s]*([0-5][0-9])?[\s]*?/gi;

var validStatus = {
  "on" : T["enabled"],
  "off" : T["disabled"],
}

var profileTable = {
  "All" : T["All"],
}
var days = [T["Mon"], T["Tue"], T["Wed"], T["Thu"], T["Fri"], T["Sat"], T["Sun"]]

var dayindex = {
  "Mon" :  {text : T["Mon"] , index : 1 } ,
  "Tue" :  {text : T["Tue"] , index : 2 } ,
  "Wed" :  {text : T["Wed"] , index : 3 },
  "Thu" :  {text : T["Thu"] , index : 4 } ,
  "Fri" :  {text : T["Fri"] , index : 5 } ,
  "Sat" :  {text : T["Sat"] , index : 6 } ,
  "Sun" :  {text : T["Sun"] , index : 7 } ,
 }

var dayTable = {
  "Mon, Tue, Wed, Thu, Fri, Sat, Sun" : "Every Day",
  "Mon, Tue, Wed, Thu, Fri"           : "Every Workday",
  "Sat, Sun"                          : "All Weekend",
}

/* function noRuleMessage(){
  var rowLength = $("#schedule-table").find("tr").length;
  if (rowLength == 3 ){
    $("#des-no-rule").css("display","");
    $("#mob-no-rule").css("display","");
  }else {
    $("#des-no-rule").css("display","none");
    $("#mob-no-rule").css("display","none");
  }
}

function formatTime(time){
  if (!(/^\d+:\d+$/).test(time)) return time;
    var regExp = /^\d+|\d+$/g;
    function padZero(value) {
      return ("0" + value).slice(-2);
    }
    return time.replace(regExp, padZero);
 }*/
var elements = {
  startTime: "[role=dialog].in [id$=start]",
  endTime: "[role=dialog].in [id$=stop]"
}

var validations = {
  startTime: timeRegExp,
  endTime: timeRegExp
}

$(function() {
    if ($("#rngshd-btn-todstatus").hasClass("button-on")) {
        $("#rngshd-btn-todstatus").closest("div.h3-content").next("div.hide-all").slideDown();
    } else if ($("#rngshd-btn-todstatus").hasClass("button-off")) {
        $("#rngshd-btn-todstatus").closest("div.h3-content").next("div.hide-all").hide();
    }
    noRuleMessage("schedule-table")
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
      //m_InputManager.update();

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
    $("#rngshd-btn-todstatus").click(function(){
    if ($(this).hasClass("button-on")){
       $(this).removeClass("button-on").addClass("button-off");
       $("#rngshd-hid-todstatus").val("0");
       $(this).closest(".h3-content").next(".hide-all").slideUp();
    }else {
        $(this).removeClass("button-off").addClass("button-on");
        $(this).closest(".h3-content").next(".hide-all").slideDown();
        $("#rngshd-hid-todstatus").val("1");
    }
    });

    $("#rngshd-select-day").change(function(){
      if ($(this).val() == "Individual Days"){
        $(".rngshd-div-inddays").css("display", "table-row");
        if (screenWidth <= maxMobileWidth){ $("#rngshd-div-mobinddays").removeClass("hide").addClass("show"); }
      } else {
        $(".rngshd-div-inddays").css("display", "none");
        if (screenWidth <= maxMobileWidth){ $("#rngshd-div-mobinddays").removeClass("show").addClass("hide"); }
      }
    });

  $("#rngshd-btn-add, #rngshd-btn-mobadd").click(function(){
    $("#rngshd-select-day").val(T["Every Workday"]).trigger("chosen:updated");
    $("#rngshd-txt-start, #rngshd-txt-stop").val("00:00");
    $(".rngshd-div-inddays").css("display", "none");
    $(".rngshd-div-inddays input[type='checkbox']").each(function() {
      $(this).prop("checked", false);
    });
    $("#rngshd-div-mobinddays input[type='checkbox']").each(function() {
      $(this).prop("checked", false);
    });
    $("#rngshd-div-mobinddays").removeClass("show").addClass("hide");
    $("#rngshd-txt-mobstart, #rngshd-txt-mobstop").val("00:00");
});
  $("#rngshd-btn-addsave").click(function(){
    if (!validateElements(elements, validations)) return false;
    $("#ringing-schedule-popup-add").modal("hide");
    var profileName = $("#rngshd-select-profile").val();
    var currentProfile = profileName
    if (profileName == "All"){
      profileName = profileTable[profileName]
    } 
    var start = $("#rngshd-txt-start").val();
    var stop = $("#rngshd-txt-stop").val();
    if (screenWidth <= maxMobileWidth){
      start =  $("#rngshd-txt-mobstart").val();
      stop = $("#rngshd-txt-mobstop").val();
    }
    var selectedDay = $("#rngshd-select-day").val();
    var daysOfWeek = [];
    var daysOfWeekEng = [];
    if (selectedDay == "Individual Days") {
        $(".rngshd-div-inddays input[type=\"checkbox\"]").each(function(index) {
            if ($(this).prop("checked")) {
              daysOfWeek.push(days[$(this).data("index")-1]);
              daysOfWeekEng.push($(this).attr("id"));
            }
        });
        $("#rngshd-div-mobinddays input[type=\"checkbox\"]").each(function(index) {
            if ($(this).prop("checked")) {
              daysOfWeek.push(days[$(this).data("index")-1]);
              daysOfWeekEng.push($(this).attr("id").slice(3,6));
            }
        });
        daysOfWeekEng.sort(function(a, b) { return dayindex[a].index - dayindex[b].index });
        daysOfWeek = daysOfWeek.join(", ");
        daysOfWeekEng = daysOfWeekEng.join(", ");
    } else { daysOfWeek = $("#rngshd-select-day option:selected").text();
      daysOfWeekEng = dayTypesTable[selectedDay].join(", ");
    }
    $('<tr  class="cloned" data-type="add">\
                    <td>\
                      <input type="hidden" class="dayType" value="' + selectedDay + '">\
                      <input type="hidden" class="days" value="' + daysOfWeekEng + '">\
                      <span class="weekday">' + daysOfWeek + '</span>\
                    </td>\
                    <td class = "time"><span>' + T["from"] + '&nbsp;</span>' + formatTime($.trim(start)) + '<span>&nbsp;' + T["to"] + '&nbsp;</span>' + formatTime($.trim(stop)) + '</td>\
                    <td class = "profile" data-profile='+ currentProfile +' ><span>' + profileName + '</span></td>\
                    <td>\
                        <div class="schedule-on status"><span>'+serviceClass+'</span></div>\
                    </td>\
                    <td><input class="button button-edit" value="" type="button" data-toggle="modal"\ data-target="#ringing-schedule-popup-edit" onclick="copyEditableFields(this)" ></td>\
                    <td><input class="button button-delete" value="" type="button"></td>\
                </tr>').insertBefore("#last-row")
        $(' <div class="mobile-table-row">\
            <div class="vdf-row mobile-row-half">\
                <div class="left time">\
                    <span>'+T["from"]+'&nbsp;</span>'+formatTime(start)+'<span>&nbsp;'+T["to"]+'&nbsp;</span>'+formatTime(stop)+'</div>\
                <div class="right status">\
                    <div class="schedule-on"><span>'+serviceClass+'</span></div>\
                </div>\
            </div>\
            <div class="vdf-row">\
                <div class="left weekday">\
                  <input type="hidden" class="dayType" value="' + selectedDay + '">\
                  <input type="hidden" class="days" value="' + daysOfWeekEng + '">\
                  <span class="weekday">' + daysOfWeek + '</span>\
                </div>\
            </div>\
            <div class="vdf-row number-row">\
                <div class="left profile">\
                    <span>'+profileName+'</span></div>\
            </div>\
            <div class="vdf-row mobile-row-half mobile-button-row">\
                <div class="left">\
                    <input class="button button-edit" value="" type="button">\
                </div>\
                <div class="right">\
                    <input class="button button-delete" value="" type="button">\
                </div>\
            </div>\
        </div>').insertBefore("#mob-last-row")
     noRuleMessage("schedule-table")
  });
  function copyEditableFields(element){
    editedRow = element;
    $(".rngshd-div-editinddays input").each(function(){$(this).prop("checked",0)});
    var thisRow = $(editedRow).closest("tr");
    var dayType = thisRow.find(".dayType").val();
    var selectedDays = thisRow.find(".days").val();
    var profile = thisRow.find(".profile").attr("data-profile");
    var time = thisRow.find(".time").text().trim();
    var timeArray = time.match(todRegExp);
    var startTime = timeArray[0];
    var stopTime = timeArray[1];
    $("#rngshd-select-editprofile").val(profile).trigger("chosen:updated")
    var daysOfWeek;
    $("#rngshd-txt-editstart, #rngshd-txt-mobeditstart").val(startTime);
    $("#rngshd-txt-editstop, #rngshd-txt-mobeditstop").val(stopTime);
    $(".rngshd-div-editinddays").css("display","none");
    if (screenWidth <= maxMobileWidth) $("#rngshd-div-mobeditinddays").removeClass("show").addClass("hide");
    $("#rngshd-select-editday").val(dayType).trigger("chosen:updated")
    if (dayType == "Individual Days") {
      selectedDays = selectedDays.split(", ")
      $(".rngshd-div-editinddays").css("display", "table-row");
      if (screenWidth <= maxMobileWidth) $("#rngshd-div-mobeditinddays").removeClass("hide").addClass("show");
      $("#rngshd-select-editday").val("Individual Days").trigger("chosen:updated")
      for (i = 0; i < selectedDays.length; i++) {
        if (days.indexOf(selectedDays[i] != -1)) {
          $("#rngshd-div-mobeditinddays input").each(function() {
            $("#editMob" + $.trim(selectedDays[i])).prop("checked", 1)
          })
          $(".rngshd-div-editinddays input").each(function() {
            $("#edit" + $.trim(selectedDays[i])).prop("checked", 1)
          })
        }
      }
    }
  }

$("#rngshd-select-editday").change(function() {
    if ($(this).val() == "Individual Days") {
        $(".rngshd-div-editinddays").css("display", "table-row");
        if (screenWidth <= maxMobileWidth) {
            $("#rngshd-div-mobeditinddays").removeClass("hide").addClass("show");
        }
    } else {
        $(".rngshd-div-editinddays").css("display", "none");
        if (screenWidth <= maxMobileWidth) {
            $("#rngshd-div-mobeditinddays").removeClass("show").addClass("hide");
        }
    }
  });
  $("#rngshd-btn-editsave").click(function(){
    if (!validateElements(elements, validations)) return false;
    $("#ringing-schedule-popup-edit").modal("hide");
    var selectedDay = $("#rngshd-select-editday").val();
    var profile = $("#rngshd-select-editprofile").val();
    var currentEditProfile = profile
    if (profile == "All"){
      profile = profileTable[profile]
    }
    var daysOfWeek = [];
    var daysOfWeekEng = [];
    if (selectedDay == "Individual Days") {
        if (screenWidth >= maxMobileWidth) {
            $(".rngshd-div-editinddays input[type=\"checkbox\"]").each(function(index) {
                if ($(this).prop("checked")) {
                    daysOfWeek.push(days[$(this).data("index")-1])
                    daysOfWeekEng.push($(this).attr("id").slice(4))
                };
            });
        } else {
            $("#rngshd-div-mobeditinddays input[type=\"checkbox\"]").each(function(index) {
                if ($(this).prop("checked")) {
                    daysOfWeek.push(days[$(this).data("index")-1])
                    daysOfWeekEng.push($(this).attr("id").slice(7))
                };
            });
        }
        daysOfWeekEng.sort(function(a, b) { return dayindex[a].index - dayindex[b].index })
        daysOfWeek = daysOfWeek.join(", ");
        daysOfWeekEng = daysOfWeekEng.join(", ");
    } else {
        daysOfWeek = $("#rngshd-select-editday option:selected").text();
        daysOfWeekEng = dayTypesTable[selectedDay].join(", ");
    }
    var startTime = $("#rngshd-txt-editstart").val();
    var endTime = $("#rngshd-txt-editstop").val();
    if (screenWidth <= maxMobileWidth) {
        startTime = $("#rngshd-txt-mobeditstart").val();
        endTime = $("#rngshd-txt-mobeditstop").val();
    }
    var thisRow = $(editedRow).closest("tr");
    if (thisRow.attr("data-type") != "add") {
        thisRow.attr("data-type", "edit");
    }
    var mobRow = $("#rngshd-tbl-mobschedule .button-edit").eq(mobileEditIndex).closest(".mobile-table-row")
    mobRow.find(".time").html("<span>" + T["from"] + "&nbsp;</span>" + formatTime(startTime) + "<span>&nbsp;" + T["to"] + "&nbsp;</span>" + formatTime(endTime));
    mobRow.find(".profile").html("<span>" + profile + "</span>");
    mobRow.find(".weekday").text(daysOfWeek);  
    mobRow.find(".profile").attr("data-profile", currentEditProfile);
    thisRow.find(".days").val(daysOfWeekEng);
    thisRow.find(".weekday").text(daysOfWeek);
    thisRow.find(".dayType").val(selectedDay);
    thisRow.find(".time").html("<span>" + T["from"] + "&nbsp;</span>" + formatTime(startTime) + "<span>&nbsp;" + T["to"] + "&nbsp;</span>" + formatTime(endTime));
    thisRow.find(".profile").text(profile);
    thisRow.find(".profile").attr("data-profile", currentEditProfile);
});

var delData = [];
$("#schedule-table").on("click", ".button-delete", function() {
    if ($(this).attr("data-value")) {
        delData.push({ "index": $(this).attr("data-value") });
    }
    $(this).closest("tr").remove();
    noRuleMessage("schedule-table");
});

$("#global-apply").click(function() {
    var tableData = {};
    var addData = [];
    var updateData = [];
    var params = [];
    var isDuplicate = false;
    var isError = false
    var profileStatus = $("#rngshd-select-status").val();
    var todStatus
    if ($("#rngshd-btn-todstatus").hasClass("button-on")) {
        todStatus = 1;
    } else { todStatus = 0; }
    $(".cloned").each(function(index1) {
        name1 = $(this).find(".name").text();
        profile1 = $(this).find(".profile").text();
        time1 = $(this).find(".time").text();
        status1 = $(this).find(".status").text();
        day1 = $(this).find(".day").text();
		day11 = $(this).find(".days").val();
		dayArray = day11.split(",")
        var timeArray = time1.match(todRegExp);
        start1 = timeArray[0];
        stop1 = timeArray[1];
        if (start1 == "00:00" && stop1 == "00:00") { isError = true; return false; }
        if (start1 == stop1) { isError = true; return false; }
        $(".cloned").each(function(index2) {
            if (index2 > index1) {
                isDuplicate = false;
                isError = false;
                name2 = $(this).find(".name").text();
                profile2 = $(this).find(".profile").text();
                time2 = $(this).find(".time").text();
                status2 = $(this).find(".status").text();
                day2 = $(this).find(".day").text();
				day22 = $(this).find(".days").val();
		        dayArray2 = day22.split(",");
                var timeArr = time2.match(todRegExp);
                start2 = timeArr[0];
                stop2 = timeArr[1];

                 dayMatch = false
				 $.each(dayArray2, function(index, value){
					 if ($.inArray(value, dayArray) != -1){
						 dayMatch = true
					 }
				 });
                if ( dayMatch && (profile1 == profile2) && (name1 == name2) && (status1 == status2) && (start1 == start2) && (stop1 == stop2)) {
                    isDuplicate = true;
                    return false;
                }
                if ((start1 >= stop1 && (start1 == "00:00" || stop1 == "00:00")) || (start2 >= stop2 && (start2 == "00:00" || stop2 == "00:00"))) {
                    isError = true;
                    return false;
                }
                if (start1 == stop1 || start2 == stop2) { isError = true; return false; }
            }
        });
		
        if (isDuplicate || isError) return false;
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
        if ($(this).attr("data-type") == "add") {
            var day = $(this).find(".dayType").val();
            if (day == "Individual Days") {
                day = $(this).find(".days").val();
            }
            var profile = $(this).find(".profile").attr("data-profile");
            var time = $(this).find(".time").text();
            var timeArray = time.match(todRegExp);
            var starttime = timeArray[0];
            var stoptime = timeArray[1];
            addData.push({ "days": day, "starttime": starttime, "stoptime": stoptime, "profile": profile });
        }
        if ($(this).attr("data-type") == "edit") {
            var day = $(this).find(".dayType").val();
            if (day == "Individual Days") {
                day = $(this).find(".days").val();
            }
            var name = $(this).find(".name").text();
            var profile = $(this).find(".profile").attr("data-profile");
            var time = $(this).find(".time").text();
            var timeArray = time.match(todRegExp);
            var starttime = timeArray[0];
            var stoptime = timeArray[1];
            var index = $(this).find(".button-edit").attr("data-value");
            updateData.push({ "index": index, "days": day, "starttime": starttime, "stoptime": stoptime, "profile": profile });
        }
    });
   tableData["ADD"] = addData;
   tableData["UPDATE"] = updateData;
   tableData["DELETE"] = delData;
   tableData = JSON.stringify(tableData);
   params.push({name: "tableRequest",
                value: tableData
                },{
                name: "profileStatus",
                value: profileStatus
                },{
                name: "todStatus",
                value: todStatus
                },{
                name: "action",
                value: "SAVE"
                },{
                name: "CSRFtoken",
                value:$("[name=CSRFtoken]").val() })
   postHandler("modals/ringing-schedule.lp", params, true);
});

$("#rngshd-tbl-mobschedule").on("click",".button-edit",function(){
    var thisIndex = $("#rngshd-tbl-mobschedule .button-edit").index(this);
    $("#schedule-table .button-edit").eq(thisIndex).trigger("click");
    mobileEditIndex = thisIndex;
});

$("#rngshd-tbl-mobschedule").on("click",".button-delete",function(){
    var thisIndex = $("#rngshd-tbl-mobschedule .button-delete").index(this);
    $(this).closest(".mobile-table-row").remove();
    $("#schedule-table .button-delete").eq(thisIndex).trigger("click");
    noRuleMessage("schedule-table");
});

$("#rngshd-select-status").change(function(){
   $(".status").html("<span>"+validStatus[$(this).val()]+"</span>")
   serviceClass = validStatus[$(this).val()];
});

$("#global-cancel").click(function(){
  $("#content").load("/modals/ringing-schedule.lp");
 });
$("#resetR, .resetR").click(function(){
  $("#rngshd-btn-todstatus").val(resetringschedule_ringinsschedule_enable);
  if (resetringschedule_ringinsschedule_enable == "1") {
    $('#rngshd-btn-todstatus').addClass('button-on').removeClass('button-off');
    $('#rngshd-hid-todstatus').val("1");
    $('.hide-all').show();
    }
    else
    {
    $('#rngshd-btn-todstatus').addClass('button-off').removeClass('button-on');
    $('#rngshd-hid-todstatus').val("0");
    $('.hide-all').hide();
    }
  $('#rngshd-select-status').val(resetringschedule_duringthistime).trigger("chosen:updated");
  $('.button-delete').click();
});
