  $(function() {
    $('select').chosen({
      disable_search_threshold : 100000,
      allow_single_deselect : true
    });
	$('.call-log-btn-delete').prop('disabled',true);
  });
function getDuration(connectTime, endTime) {
     var regExpTime = /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/;
     var dateArrayConnectTime = regExpTime.exec(connectTime);
     var dateObjectConnectTime = new Date((+dateArrayConnectTime[1]),(+dateArrayConnectTime[2])-1,(+dateArrayConnectTime[3]),(+dateArrayConnectTime[4]),(+dateArrayConnectTime[5]),(+dateArrayConnectTime[6]));
     var dateArrayEndTime = regExpTime.exec(endTime);
     var dateObjectEndTime = new Date(
              (+dateArrayEndTime[1]),
              (+dateArrayEndTime[2])-1,
              (+dateArrayEndTime[3]),
              (+dateArrayEndTime[4]),
              (+dateArrayEndTime[5]),
              (+dateArrayEndTime[6])
            );
      var timeStart = new Date(dateObjectConnectTime).getTime();
      var timeEnd = new Date(dateObjectEndTime).getTime();
      var hourDiff = timeEnd - timeStart; //in ms
      var hours   = Math.floor(hourDiff / (3600*1000));
      var minutes = Math.floor(((hourDiff/1000)- (hours * 3600)) / 60);
      var seconds = (hourDiff/1000) - (hours * 3600) - (minutes * 60);
      if (seconds < 10) {seconds = "0"+ seconds; }
      if (minutes < 10) {minutes = "0" + minutes; }
      if (hours < 10) {hours = "0" + hours; }
         duration = (hours) + ":" + (minutes) + ":" + (seconds);
         return  duration;
         }

  var callLogData = [];
  function getTodayAndYestDate() {
    var date = new Date();
    var getDate = date.getDate();
    var getMonth = date.getMonth() + 1;
    var getYear = date.getFullYear();
    if (getDate < 10)
    {
      getDate = "0" + getDate;
    }
    if (getMonth < 10)
    {
      getMonth = "0" + getMonth;
    }
    var TodaysDate = getDate + "." + getMonth + "." + getYear;
    date.setDate(date.getDate() - 1);
    getDate = date.getDate();
    getMonth = date.getMonth() + 1;
    getYear = date.getFullYear();
    if (getDate < 10)
    {
      getDate = "0" + getDate;
    }
    if (getMonth < 10)
    {
      getMonth = "0" + getMonth;
    }

    var YesterdaysDate = getDate + "." + getMonth + "." + getYear;
    return [TodaysDate, YesterdaysDate]

  }
  var callLogTab = function(callListType,filter)
  {
    $("#call-log-tbl-tbody div").empty();
    $("#call-log-tbl-tbody-mobile").empty();
    getLogData(callListType,filter);
  }

  function getLogData(callListType,filter)
  {
    callLogData=[];
    var getDate = getTodayAndYestDate();

    $.each(callLogInfo, function(index, v) {
      var myno = v.Myphoneno; //My phone no
      if (filter)
      {
        if (filter == myno)
        {
          var date = v.date;
          var paramindex = v.paramindex;
          CallListData={};
          if(date == getDate[0])
          {
            date = T["Today"];
          }
          else if (date == getDate[1])
          {
            date = T["Yesterday"];
          }
          var time = v.startTime; //Time
          var external_no = v.Externalno; //Remote no
          var direction = v.Call_direction;
          var duration;
          if (v["Connected_time"] && v["Connected_time"] != "0" && v["End_time"] && v["End_time"] != "0") {
            connectTime = v.Connected_time;
            endTime = v.End_time;
          } else {
            connectTime = 0;
            endTime = 0;
          }
          if (connectTime == 0 || endTime == 0)
            duration = "00:00:00"; /*For an outgoing call entry with connected time zero(A missed call), the duration will be shown empty*/
          else
          {
            duration = getDuration(connectTime, endTime);
          }
          CallListData.date = date,
          CallListData._time = time,
          CallListData.external_no = external_no,
          CallListData.myno = myno,
          CallListData._index = index,
          CallListData.paramindex = paramindex,
          CallListData.connectTime = connectTime,
          CallListData.endTime = endTime,
          CallListData.callListType = callListType,
          CallListData.direction = direction
          if (direction == 1 && callListType == "missed" && connectTime == 0)
          {

            CallListData.duration = "00:00:00",//For missed call entry, the duration will be shown empty
            callLogData.push(CallListData);
          }
          else if (direction == 2 && callListType == "dialled")
          {
            CallListData.duration = duration,
            callLogData.push(CallListData);
          }
          else if (direction == 1 && callListType == "received" && connectTime !=0)
          {
            CallListData.duration = duration,
            callLogData.push(CallListData);
          }
          else if (callListType == "all")
          {
            CallListData.duration = duration,
            callLogData.push(CallListData);
          }
        }
      }
      else
      {
        var date = v.date;
        var paramindex = v.paramindex;
        CallListData={};
        if(date == getDate[0])
        {
          date = T["Today"];
        }
        else if (date == getDate[1])
        {
          date = T["Yesterday"];
        }
        var time = v.startTime; //Time
        var external_no = v.Externalno; //Remote no
        var direction = v.Call_direction;
        var duration;
        if (v["Connected_time"] && v["Connected_time"] != "0" && v["End_time"] && v["End_time"] != "0") {
          connectTime = v.Connected_time;
          endTime = v.End_time;
        } else {
          connectTime = 0;
          endTime = 0;
        }
        if (connectTime == 0 || endTime == 0)
          duration = "00:00:00"; /*For an outgoing call entry with connected time zero(A missed call), the duration will be shown empty*/
        else
        {
          duration = getDuration(connectTime, endTime);
        }
        CallListData.date = date,
        CallListData._time = time,
        CallListData.external_no = external_no,
        CallListData.myno = myno,
        CallListData._index = index,
        CallListData.paramindex = paramindex,
        CallListData.connectTime = connectTime,
        CallListData.endTime = endTime,
        CallListData.callListType = callListType,
        CallListData.direction = direction
        if (direction == 1 && callListType == "missed" && connectTime == 0)
        {

          CallListData.duration = "00:00:00",//For missed call entry, the duration will be shown empty
          callLogData.push(CallListData);
        }
        else if (direction == 2 && callListType == "dialled")
        {
          CallListData.duration = duration,
          callLogData.push(CallListData);
        }
        else if (direction == 1 && callListType == "received" && connectTime !=0 )
        {
          CallListData.duration = duration,
          callLogData.push(CallListData);
        }
        else if (callListType == "all")
        {
          CallListData.duration = duration,
          callLogData.push(CallListData);
        }
      }
    });
  }

  var MobileViewTable = document.getElementById("call-log-tbl-tbody-mobile1");
  var currentPage = 1;
  var recordsPerPage = 10;
  var Resolution = 767;

  $(function() {
    $("#call-log-chk-select").change(function ()
    {
      $("input:checkbox").prop('checked', $(this).prop("checked"));
      if (this.checked)
      {
        $('.call-log-btn-delete').removeClass("table-button-faded").removeAttr("disabled")
      }
      else
      {
        $('.call-log-btn-delete').addClass("table-button-faded").attr("disabled",true);
      }
      $('.call-log-btn-delete').disabled = this.checked;
    });
    $('#call-log-tbl-tbody').on('change', 'input[type=checkbox]', function(e) {
      if (this.checked)
      {
        $('.call-log-btn-delete').removeClass("table-button-faded").removeAttr("disabled")
      }
      else
      {
        $('.call-log-btn-delete').addClass("table-button-faded").attr('disabled');
      }
      $('.call-log-btn-delete').disabled = !!this.checked;
    });
    $('#call-log-tbl-tbody-mobile').on('change', 'input[type=checkbox]', function(e) {
      if (this.checked)
      {
        $('.call-log-btn-delete').removeClass("table-button-faded").removeAttr("disabled")
      }
      else
      {
        $('.call-log-btn-delete').addClass("table-button-faded").attr('disabled');
      }
      $('.call-log-btn-delete').disabled = !!this.checked;
    });
    callLogTab("all", "");
    $(".tabs-all").addClass('active');

    /*$(".tabs > div").click(function() {
        if(!$(this).hasClass('active'))
        {
              $(".tabs div.active").removeClass("active");
              $(this).addClass("active");
        }
        $("#call-log-chk-select").prop("checked",0)
        $('.call-log-btn-delete').addClass("table-button-faded").attr('disabled');
        var callLogType = $(".tabs div.active").attr("data-id");
        callLogTab(callLogType,"")
        currentPage = 1;
        DesktopView(1);
        if (callLogData.length == 0)
          $('#call-log-chk-select').prop('disabled', true);
        else
         $('#call-log-chk-select').prop('disabled', false);
    });*/

    $(".call-log-btn-delete").click(function(){
      $("#delConfirm").modal('show');
    });
    $("#call-log-btn-refresh").click(function() {
      $("#content").load("/modals/call-log.lp");
    })
    $('#call-log-select-logtype').change(function() {
      var rows;
      var callLogType;
      callLogType = $(".tabs div.active ").attr("data-id");
      var DropdownOption = document.getElementById("call-log-select-logtype");
      var SelectedText = DropdownOption.options[DropdownOption.selectedIndex].text;
      var selectIndex = document.getElementById("call-log-select-logtype").selectedIndex;
      if ($(window).width() <= Resolution) {
        if (selectIndex == "0") {
          callLogTab(callLogType,"")
          MobileView(currentPage);
          rows = $('#call-log-tbl-tbody-mobile tr');
          rows.show(); // initially display all call log
          return;
        }
       else
       {
          callLogTab(callLogType,SelectedText)
          MobileView(currentPage);
          rows = $('#call-log-tbl-tbody-mobile tr');
          $.each(rows, function(index, item) {
            var type = $(this).children('td').eq(1).find("p:eq(0)").text();
            var DropdownOption = document.getElementById("call-log-select-logtype");
            var SelectedText = DropdownOption.options[DropdownOption.selectedIndex].text;
            if (type != SelectedText) {
              $(this).hide();
            }
          });
        }
      }
      else {
        if (selectIndex == "0") {
          callLogTab(callLogType,"")
          DesktopView(currentPage);
          rows = $('#call-log-tbl-tbody');
          rows.show(); // initially display all call log
          return;
        }
        else
        {
          callLogTab(callLogType,SelectedText)
          DesktopView(currentPage);
          rows = $('#call-log-tbl-tbody');
          $.each(rows, function(index, item) {
            var type = $(this).children('div').children('div').eq(4).text();
            if (type != SelectedText) {
              $("#call-log-tbl-tbody").children('div').children('div').eq(4).closest(".table-row")
            }
          });
        }
      }
    });
    $("#call-log-form").on("click","#call-log-btn-popupdelete",function() {
      var deleteList = [];
      var obj = [];
      var target = $("#call-log-form").attr("action");

      if ($(window).width() <= Resolution) {
        $('#call-log-tbl-tbody-mobile input:checkbox:checked').each(function() {
          if ($(this).attr("data-value")) {
            deleteList.push($(this).attr("data-value"));
          }
        })
        $('#call-log-tbl-tbody-mobile tr').filter(':has(:checkbox:checked)').remove();
      }
      else {
        $('#call-log-tbl-tbody input:checkbox:checked').each(function() {
          if ($(this).attr("data-value")) {
            deleteList.push($(this).attr("data-value"));
          }
        })
        $('#call-log-tbl-tbody').filter(':has(:checkbox:checked)').remove();
      }
      deleteList = JSON.stringify(deleteList);
      obj.push(
      {
        name: "delete",
        value: deleteList
      },
      {
        name: "CSRFtoken",
        value : $("[name=CSRFtoken]").val()
      })
      var delTabDesktop;
      var delTabMobile = $("#call-log-select-logtype").val();
      $(".tabs-all").each(function(index){
        if ($(this).hasClass("active")) delTabDesktop = index;
      });
      $("#delConfirm").modal('hide');
      $("#content").load($("#call-log-form").attr("action"),obj, function(){
        $("#myTabs").find("a:eq(" + delTabDesktop + ")").click();
        $("#call-log-select-logtype").val(delTabMobile).trigger("change").trigger("chosen:updated")
      });
    });
  });
  $("#call-log-btn-prev").click(function() {
    if (currentPage > 1) {
      currentPage--;
      DesktopView(currentPage);
    }
  })
  $("#call-log-btn-next").click(function() {
    if (currentPage < numPagesDesktopView()) {
      currentPage++;
      DesktopView(currentPage);
    }
  });
      $('.tabs > div').click(function() {
        if($(this).parent().hasClass('desktop'))
        {
          var id = $(this).attr('data-id');
          var cl = $(this).attr('data-class');
          if(!$(this).hasClass('active'))
        {
              $(".tabs div.active").removeClass("active");
              $(this).addClass("active");
        }
        $("#call-log-chk-select").prop("checked",0)
        $('.call-log-btn-delete').addClass("table-button-faded").attr('disabled');
        var callLogType = $(".tabs div.active").attr("data-id");
        callLogTab(callLogType,"")
        currentPage = 1;
        DesktopView(1);
        if (callLogData.length == 0)
          $('#call-log-chk-select').prop('disabled', true);
        else
         $('#call-log-chk-select').prop('disabled', false);
          $('.tabs').removeClass().addClass('clearfix tabs ' + cl + ' desktop');
          if (id != 'all') {
            $('.call-log.table .table-row:not(.table-row-head)').addClass('hidden');
            $('.' + id).removeClass('hidden');
          } else {
            $('.call-log.table .table-row').removeClass('hidden');
          }
        }
      });
  function DesktopView(page)
  {
    var TableListDesktopView = document.getElementById("call-log-tbl-tbody");
    var pageSpan = document.getElementById("page");
    if (callLogData.length > 0) {
      if (page < 1) page = 1;
      if (page > numPagesDesktopView()) page = numPagesDesktopView();
      TableListDesktopView.innerHTML = "";
        for (var i = (page - 1) * recordsPerPage; i < (page * recordsPerPage) && i < callLogData.length; i++)
        {
          var callLogo, alternate, calltype;

          if (callLogData[i].direction == 1 && callLogData[i].connectTime == 0)
          {
            callLogo = "img/look_4/icons/missedcall.png";
            alternate = "Missedcall";
            calltype = "missed";
          }
          else if (callLogData[i].direction == 1)
          {
            callLogo = "img/look_4/icons/incoming.png";
            alternate = "Incoming";
            calltype = "received";
          }
          else
          {
            callLogo = "img/look_4/icons/outgoing.png";
            alternate = "Outgoing";
            calltype = "dialled";
          }
          TableListDesktopView.innerHTML+='<div class="table-row '+calltype+' co num2 numAll num_office" style="display: table-row;">'+
          '<div class="table-col table-col1"><img src="'+callLogo+'"alt="'+alternate+'"/></div>'+
          '<div class="table-col table-col2"><span>'+callLogData[i].date+'</span></div>'+
          '<div class="table-col table-col3">'+callLogData[i]._time+'</div>'+
          '<div class="table-col divDoubleLine table-col4" style="width: 140px;">'+callLogData[i].external_no+'</div>'+
          '<div class="table-col table-col5" style="width: 135px;"><span>'+callLogData[i].myno+'</span></div>'+
          '<div class="table-col table-col6">'+callLogData[i].duration+'</div>'+
          '<div class="table-col table-col7">&nbsp;</div>'+
          '<div class="table-col table-col8"><input  class="checkbox checkbox-unchecked" type="checkbox" id="ch'+callLogData[i]._index+'" data-value = "'+callLogData[i].paramindex+'">'+
          '<label for="ch'+callLogData[i]._index+'"></label></div></div>'
          if (alternate == "Missedcall")
            $("#ch"+callLogData[i]._index).closest("div").addClass("missed-call-color");
        }
        if (page == 1) {
    $("#call-log-btn-prev").css("opacity","0.3")
          $("#call-log-btn-prev").children().prop('disabled', true);
          $("#call-log-btn-prev").addClass("table-button-faded");
        } else {
          $("#call-log-btn-prev").css("opacity","1")
          $("#call-log-btn-prev").children().prop('disabled', false);
          $("#call-log-btn-prev").removeClass("table-button-faded");
        }
        if (page == numPagesDesktopView()) {
    $("#call-log-btn-next").css("opacity","0.3");
          $("#call-log-btn-next").children().prop('disabled', true);
          $("#call-log-btn-next").addClass('table-button-faded');
        } else {
    $("#call-log-btn-next").css("opacity","1");
          $("#call-log-btn-next").children().prop('disabled', false);
          $("#call-log-btn-next").removeClass('table-button-faded');
        }
      pageSpan.innerHTML = page + "/" + numPagesDesktopView();
    }
    else
    {
      if (page == 1) {
        $("#call-log-btn-prev").children().prop('disabled', true);
        $("#call-log-btn-next").children().prop('disabled', true);
        $("#call-log-btn-prev").addClass("table-button-faded");
        $("#call-log-btn-next").addClass('table-button-faded');
      }
      pageSpan.innerHTML = 0 + "/" + 0;
    }
  }

  function numPagesDesktopView()
  {
    return Math.ceil(callLogData.length / recordsPerPage);
  }

  $(function(){
    if ($(window).width() <= Resolution) {
      MobileView(1);
    }
    else {
      DesktopView(1);
    }
  $("#call-log-btn-mobprev").click(function() {
    if (currentPage > 1) {
      currentPage--;
      MobileView(currentPage);
    }
  })
  $("#call-log-btn-mobnext").click(function() {
    if (currentPage < numPagesMobView()) {
      currentPage++;
      MobileView(currentPage);
    }
  });
});

$("#call-log-form").ready(function() {
   $('.tabs-arrow.next').click(function() {
    var $current = $('.tabs-current');
    $next = $('.tabs-next');
    $prev = $('.tabs-prev');
    $('.table-row').hide();
    if(!$('.tabs-missed').hasClass('tabs-current')) {
    $('.tabs-arrow.prev').show();
    $prev.removeClass('tabs-prev');
    $('.tabs-current').removeClass('active');
    $('.tabs-next').addClass('active');
    $current.removeClass('tabs-current').addClass('tabs-prev');
    $('.tabs-next').next('div:not(.tabs-arrow)').addClass('tabs-next');
    $next.removeClass('tabs-next').addClass('tabs-current');
    $('.' +  $('.tabs-current').data('id')).show();
    }
    $('.tabs-arrow.next').removeClass('active');
    var callType=$('div.tabs-current').attr("data-id");
    callLogTab(callType,"");
    MobileView(1);
    $('.tabs-arrow.next').remove('active');
    if (callLogData.length == 0)
      $('#call-log-chk-select').prop('disabled', true);
    else
      $('#call-log-chk-select').prop('disabled', false);
  });

  $('.tabs-arrow.prev').click(function() {
    var $current = $('.tabs-current');
    $next = $('.tabs-next');
    $prev = $('.tabs-prev');
    $('.table-row').hide();
    if($('.tabs').find('.tabs-prev').length >= 1) {
    $('.tabs-prev').prev('div:not(.tabs-arrow)').addClass('tabs-prev');
    $prev.removeClass('tabs-prev').addClass('tabs-current');
    $current.removeClass('tabs-current').addClass('tabs-next');
    $next.removeClass('tabs-next');
    $('.tabs-current').addClass('active');
    $('.tabs-next').removeClass('active');
    $('.' +  $('.tabs-current').data('id')).show();
    if($('.tabs').find('.tabs-current').prev().attr('class') == 'tabs-arrow prev') {
    $('.tabs-arrow.prev').hide();
    }
    }
    $('.tabs-arrow.prev').removeClass('active');
    var callType=$('div.tabs-current').attr("data-id");
    callLogTab(callType,"");
    MobileView(1);
    if (callLogData.length == 0)
      $('#call-log-chk-select').prop('disabled', true);
    else
      $('#call-log-chk-select').prop('disabled', false);
  });
});

function MobileView(page)
{
  var monthNames = [T["JANUARY"], T["FEBRUARY"], T["MARCH"], T["APRIL"], T["MAY"], T["JUNE"], T["JULY"], T["AUGUST"], T["SEPTEMBER"], T["OCTOBER"], T["NOVEMBER"], T["DECEMBER"]];
  var TableListMobileView = document.getElementById("call-log-tbl-tbody-mobile");
  var TableList = document.getElementById("call-log-tbl-tbody-mobile1");
  var mobilePage = document.getElementById("mob-page");
  if (callLogData.length > 0)
  {
    TableListMobileView.innerHTML = "";
    TableList.innerHTML = "";
      var dateVal = [];
      $.each(callLogData, function(index, value) {
        if ($.inArray(value.date, dateVal) === -1) {
          dateVal.push(value.date);
        }
      });
      $.each(dateVal, function(index, dateValue) {
        var dateHeader = dateValue;
        if (dateHeader!="Today" && dateHeader !="Yesterday") {
          var dateArr = dateHeader.split(".");
          dateArr[2] = dateArr[2].toString().substr(2,2);
          dateArr[1] = monthNames[Number(dateArr[1])-1];
          dateHeader = dateArr[0] +" "+ dateArr[1] +","+" "+dateArr[2];
        }
        TableList.innerHTML +='<tr><td colspan="4" class="padding-top-lg mobile-calllog-header">'+dateHeader+'</td></tr>'
        $.each(callLogData, function(index, val) {
          if(dateValue == val.date) {
            var callLogo, alternate;
            if (val.direction == 1 && val.connectTime == 0)
            {
              callLogo = "img/look_4/responsive/icon_missing_call.png";
              alternate = "Missedcall";
            }
            else if (val.direction == 1)
            {
              callLogo = "img/look_4/responsive/icon_incoming_call.png";
              alternate = "Incoming";
            }
            else
            {
              callLogo = "img/look_4/responsive/icon_outgoing_call.png";
              alternate = "Outgoing";
            }
            TableList.innerHTML +='<tr><td><input type="checkbox" class="checkbox checkbox-unchecked" id="ch'+val._index+'" data-value = "'+val.paramindex+'"/><label for="ch'+val._index+'"></label></td><td><p><img src='+callLogo+' alt='+alternate+' class="call-log-indication"/>'+val.myno+'</p><p class="mobile-padding-top-5">'+val.external_no+'</p></td><td colspan="2"><p class="text-right call-log-duration">Duration <span>'+val.duration+'</span></p><p class="text-right mobile-padding-top-5">'+val._time+'</p></td></tr>'
          }
        });
      });
      for (var i = (page - 1) * recordsPerPage; i < (page * recordsPerPage) && i < MobileViewTable .rows.length; i++)
      {
        TableListMobileView.innerHTML +='<tr>'+MobileViewTable.rows[i].innerHTML+'</tr>';
      }
      if (page == 1) {
        $("#call-log-btn-mobprev").prop('disabled', true);
        $("#call-log-btn-mobprev").addClass("table-button-faded");
      } else {
        $("#call-log-btn-mobprev").prop('disabled', false);
        $("#call-log-btn-mobprev").removeClass("table-button-faded");
      }
      if (page == numPagesMobView()) {
        $("#call-log-btn-mobnext").prop('disabled', true);
        $("#call-log-btn-mobnext").addClass('table-button-faded');
      } else {
        $("#call-log-btn-mobnext").prop('disabled', false);
        $("#call-log-btn-mobnext").removeClass('table-button-faded');
      }
    mobilePage.innerHTML = page + "/" + numPagesMobView();
  }
  else
    { if (page == 1) {
        $("#call-log-btn-mobprev").prop('disabled', true);
        $("#call-log-btn-mobnext").prop('disabled', true);
        $("#call-log-btn-mobprev").addClass("table-button-faded");
        $("#call-log-btn-mobnext").addClass('table-button-faded');
      }
      mobilePage.innerHTML = 0 + "/" + 0;
    }
}

function numPagesMobView()
{
  return Math.ceil(MobileViewTable.rows.length / recordsPerPage);
}
if (callLogData.length == 0)
  $('#call-log-chk-select').prop('disabled', true);
else
  $('#call-log-chk-select').prop('disabled', false);
