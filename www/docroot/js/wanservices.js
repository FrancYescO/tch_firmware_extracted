if ($("#Hide_Advanced_id").hasClass("hide") && sessionStorage.getItem("showAdvancedMode") == "false") {
  $('.btn-table-edit, .btn-table-delete, .btn-table-new, .dropdown-toggle').hide();
}
else {
  $('.btn-table-edit, .btn-table-delete, .btn-table-new, .dropdown-toggle').show();
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

if (IPv6Port) {
  var protocol = $("#protocol").val();
  if (protocol == "icmpv6" || protocol == "all"){
    $("#wanportInput").attr("readonly", "readonly");
  }
  $("#protocol").change(function(){
    if (($(this).val() == "icmpv6") || ($(this).val() == "all")){
      $("#wanport").attr("disabled", "disabled");
      $("#wanportInput").attr("readonly", "readonly");
      $("#wanportInput").val('');
    }
    else {
      $("#wanport").removeAttr("disabled");
      $("#wanportInput").removeAttr("readonly");
    }
  });
}

if (sourceIPValue == 1) {
    $("#portforwarding").find("th:eq(5)").remove();
    $("#portforwarding tbody tr").find("td:eq(5)").remove();
    $("#fwrules_v6").find("th:eq(4)").remove();
    $("#fwrules_v6 tbody tr").find("td:eq(4)").remove();
    $("#upnpportforwarding").find("th:eq(3)").remove();
    $("#upnpportforwarding tbody tr").find("td:eq(3)").remove();
}

$("#ddns_enabled , #ddnsv6_enabled").change(function() {
  var val = $(this).attr("id") == "ddns_enabled" ? "" : "v6";
  $("#ddns"+val+"_service_name, #ddns"+val+"_domain, #ddns"+val+"_username, #ddns"+val+"_password").parent().parent().toggleClass("hide");
});

if ($("#ddns_enabled").val() == "0") {
  $("#ddns_service_name, #ddns_domain, #ddns_username, #ddns_password").parent().parent().addClass("hide");
}

if ($("#ddnsv6_enabled").val() == "0") {
  $("#ddnsv6_service_name, #ddnsv6_domain, #ddnsv6_username, #ddnsv6_password").parent().parent().addClass("hide");
}

$("#portforwarding tbody tr").find("td:eq(3)").keypress(function() {
  $("#portRange4").removeClass("hide").addClass("show");
});

$("#portforwarding tbody tr").find("td:eq(4)").keypress(function() {
  $("#portRange4").removeClass("hide").addClass("show");
});

$("#fwrules_v6 tbody tr").find("td:eq(3)").keypress(function() {
  $("#portRange6").removeClass("hide").addClass("show");
});

if ($("#dest_ip_v6").val() == "custom") {
  $("#dest_ip_v6").replaceWith($('<input/>',{'type':'text', 'name':'dest_ip_v6','id' : 'dest_ip_v6Input', 'class':'span2'}));
}


function portchange(portName,portId){
  $("[name = " + portName + "]").change(function () {
    if (((this.value) == "custom") && (portName == "dest_ip_v6" || portName == "destinationip")) {
      $(this).replaceWith($('<input/>',{'type':'text', 'name':portName, 'id':portId, 'class':'span2'}));
    }
    if ((this.value) == "custom") {
      $(this).replaceWith($('<input/>',{'type':'text', 'name':portName, 'id':portId, 'class':'span1'}));
    }
  });
}
portchange('wanport','wanportInput');
portchange('lanport','lanportInput');
portchange('destinationip','destinationipInput');
portchange('dest_ip_v6','dest_ip_v6Input');
portchange('ddns_service_name', 'ddns_service_nameInput');
portchange('ddnsv6_service_name', 'ddnsv6_service_nameInput');

$(".dropdown-menu").height(100).css("overflow-y","scroll");

