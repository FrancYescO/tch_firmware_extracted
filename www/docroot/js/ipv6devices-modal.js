if (featureFlag) {
    var priority_toggle;
    $("#ipv6Devices thead" ).find("th:nth-child(11)").addClass("hide");
    $("#ipv6Devices tbody tr").each(function (key, val) {
    var obj = $(this)
    if(obj.children("td").find("div").hasClass("off")){
      obj.children("td:nth-child(11), td:nth-child(12)").html("");
    }
    priority_toggle = obj.children("td:nth-child(11)").text();
    if(priority_toggle != ""){
      obj.children("td:nth-child(11)").text((priority_toggle=="1")?"ON" : "OFF");
    }
    if(obj.hasClass("line-edit")){
      obj.children("td:nth-child(11)").addClass("hide");
    }
    else {
      obj.children("td:nth-child(12)").addClass("hide");
    }
    });
  }
else{
    $("#ipv6Devices thead" ).find("th:nth-child(11)").addClass("hide");
    $("#ipv6Devices thead" ).find("th:nth-child(12)").addClass("hide");
    $("#ipv6Devices tbody tr").children("td:nth-child(11)").addClass("hide");
    $("#ipv6Devices tbody tr").children("td:nth-child(12)").addClass("hide");
}
