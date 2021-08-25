if ($("#Hide_Advanced_id").hasClass("hide") && sessionStorage.getItem("showAdvancedMode") == "false") {
  $('.btn-table-edit, .btn-table-delete, .btn-table-new, .dropdown-toggle').css({"display":"none"});
}
else {
  $('.btn-table-edit, .btn-table-delete, .btn-table-new, .dropdown-toggle').css({"display":"inline"});
}

$("#Hide_Advanced_id , #Show_Advanced_id").click(function(){
  var _id = this.id == "Show_Advanced_id" ? true : false ;
  sessionStorage.setItem("showAdvancedMode", _id);
  $('.btn-table-edit, .btn-table-delete, .btn-table-new, .dropdown-toggle').css({"display":_id ? "inline" : "none"});
});

$("#portforwarding").find("th:eq(5)").addClass("advanced hide");
$("#portforwarding tbody tr").find("td:eq(5)").addClass("advanced hide");
$("#fwrules_v6").find("th:eq(4)").addClass("advanced hide");
$("#fwrules_v6 tbody tr").find("td:eq(4)").addClass("advanced hide");
$("#upnpportforwarding").find("th:eq(3)").addClass("advanced hide");
$("#upnpportforwarding tbody tr").find("td:eq(3)").addClass("advanced hide");

if (sourceIPValue == 1) {
    $("#portforwarding").find("th:eq(5)").remove();
    $("#portforwarding tbody tr").find("td:eq(5)").remove();
    $("#fwrules_v6").find("th:eq(4)").remove();
    $("#fwrules_v6 tbody tr").find("td:eq(4)").remove();
    $("#upnpportforwarding").find("th:eq(3)").remove();
    $("#upnpportforwarding tbody tr").find("td:eq(3)").remove();
}

function ddns_display() {
  var ddns_status = $("#ddns_enabled").val();
  if (ddns_status == 1) {
    $("#ddns_service_name, #ddns_domain, #ddns_username, #ddns_password").parent().parent().removeClass("hide");
  }
  else {
    $("#ddns_service_name, #ddns_domain, #ddns_username, #ddns_password").parent().parent().addClass("hide");
  }
}
ddns_display();
$("#ddns_enabled").change(function() {
  ddns_display();
});

$("#portforwarding tbody tr").find("td:eq(3)").keypress(function() {
  $("#portRange4").removeClass("hide").addClass("show");
});

$("#portforwarding tbody tr").find("td:eq(4)").keypress(function() {
  $("#portRange4").removeClass("hide").addClass("show");
});

$("#fwrules_v6 tbody tr").find("td:eq(3)").keypress(function() {
  $("#portRange6").removeClass("hide").addClass("show");
});
