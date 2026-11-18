function cancel_button(data) {
  noOfRows--;
  $("#sip_error").addClass("hide");
  $(data).parent().parent().attr("style","display: none;");
  $(data).parent().children('input').val($(data).hasClass("btn-table-dlt") ? 1 : 0);
  $('#modal-no-change').fadeOut(300);
  $('#modal-changes').delay(350).fadeIn(300);
}

function addNewRow() {
  noOfRows = $("#sipProfileTable tr").length;
  var EnableSW        = '<div class="control-group"><div class="switch switchOn" data-placement="right"><div class="switcher switcherOn" texton="ON" textoff="OFF" valon="1" valoff="0"></div><input value="1" name="enable.'+noOfRows+'" type="hidden"></input></div></div>';
  var UserName        = '<input class="edit-input  span1" type="text" name="username.'+noOfRows+'" value=""></input>';
  var uri             = '<input class="edit-input  span1" type="text" name="uri.'+noOfRows+'" value=""></input>';
  var Password        = '<input class="edit-input  span1" type="password" name="password.'+noOfRows+'" value=""></input>';
  var DisplayName     = '<input class="edit-input  span1" type="text" name="displayName.'+noOfRows+'" value=""></input>';
  CancelBtn           = '<div id="cancel_btn_'+noOfRows+'" onclick="cancel_button(this);" class="btn btn-mini btn-danger tooltip-on" data-placement="top" data-original-title="Cancel"><i class="icon-remove"></i></div>' +'<input value="1" name="isRowAdded.'+noOfRows+'" type="hidden">';
  var NetWork = '<div class="control-group"><select class="span2" name="network.'+noOfRows+'"><option value="'+value1+'">'+value2+'</option></select></div>';

  $('#sipProfileTable').append('<tr><td>'+EnableSW+'</td><td></td><td>'+UserName+'</td><td>'+uri+'</td><td>'+Password+'</td><td>'+DisplayName+'</td><td>'+NetWork+'</td><td></td><td></td><td>'+CancelBtn+'</td></tr>');
  //Enabling tool tip for newly added row
  $('.tooltip-on').tooltip();
}

$(document).ready(function() {
  $("#sipProfileTable  th:nth-child(3), th:nth-child(5), th:nth-child(7), th:nth-child(10)").addClass("advanced hide");
  $("#sipProfileTable  td:nth-child(3), td:nth-child(5), td:nth-child(10), td:nth-child(7)").addClass("advanced hide");

  function readonly_row(key) {
    $('#sipProfileTable tr').each(function() {
      $(this).find('td').each(function() {
      $(this).css("pointer-events", key);
      $(this).find(".switch input text").css("cursor",key == "none"?"not-allowed": "auto");
    });
  });
}

$(".btn-table-dlt").click(function(){cancel_button(this);});

$("#dtmf").addClass("select");
  if (sessionStorage.getItem("showAdvancedMode") == "false") {
    readonly_row("none");
  }
  else {
    readonly_row("auto");
  }
  $("#Show_Advanced_id").click(function(){
    sessionStorage.setItem("showAdvancedMode", true);
    readonly_row("auto");
  });
  $("#Hide_Advanced_id").click(function(){
   sessionStorage.setItem("showAdvancedMode", false);
   readonly_row("auto");
  });

  $("#dig_enable").val() == 0 ? $('#dig_string').hide() : $('#dig_string').show();
  $('.switch, input[type="text"], input[type="password"]').change(function(){
    $("#dig_enable").val() == 0 ? $('#dig_string').hide() : $('#dig_string').show();
    $('#modal-no-change').fadeOut(300);
    $('#modal-changes').delay(350).fadeIn(300);
  });

// To empty password field for duplicate URI
  $("#sipProfileTable tbody tr").each(function(){
    if (($(this).children("td:nth-child(4)").find("div").hasClass("error")) && ($(this).children("td:nth-child(2)").text() == "")) {
      $(this).children("td:nth-child(5)").find(".edit-input").val("");
    }
  });
  $('.select').change(function(){
    $('#modal-no-change').fadeOut(300);
    $('#modal-changes').delay(350).fadeIn(300);
  });
  $('.btn-table-addrow').click(function(){
    if (noOfRows<16) {
      addNewRow();
      $("#sip_error").addClass("hide");
      $('#modal-no-change').fadeOut(300);
      $('#modal-changes').delay(350).fadeIn(300);
    }
    else {
      $("#sip_error").removeClass("hide");
    }
  });
  $("#Hide_Advanced_id , #Show_Advanced_id ").click(function(){
    this.id == "Hide_Advanced_id" ? readonly_row("none"):readonly_row("auto");
  });
  $(document).off("change")
});

$(function(){
  $("<div id='sip_error' class='alert alert-error hide'>"+T["errMsg"]+"</div>").insertAfter("#sipProfileTable");
  $('#sipProfileTable tbody tr').each (function() {
    var regstate_column = 7, callstate_column = 8;
    //Toolbox for column Registered
    var reg = $(this).find("td").eq(regstate_column).find("div");
    var reg_class = reg.attr("class");
    var reg_hint = "Unregistered";
    if (reg_class == "light green") {
      reg_hint = "Registered";
    }
    else if (reg_class == "light orange") {
      reg_hint = "Registering";
    }
    reg.attr({"class": "someInfos " + reg_class, "rel": "tooltip", "data-placement": "top", "data-original-title": reg_hint});

    //Toolbox for column State
    var call = $(this).find("td").eq(callstate_column).find("div");
    var call_class = call.attr("class");
    var call_hint = "Can't be used";
    if (call_class == "light green") {
      call_hint = "Can be used";
    }
    call.attr({"class": "someInfos " + call_class,"rel": "tooltip", "data-placement": "top", "data-original-title": call_hint});
  })
  $('.someInfos').tooltip();
});
