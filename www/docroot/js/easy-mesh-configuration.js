var labelHide = $("[id='controllermac'], [id='agentmac']");

$(document).on("click", "#ok, #cancel", function() {
  tch.removeProgress();
});

if ($("#easyMeshEnable").val() == "1") {
  $("#agentEnable").val("1")
  $("#controllerEnable").val("1")
  $("#wificonductorEnable").val("1")
  $("#wifibandsteerEnable").val("0")
  $("[id='Extender Info'], [id='Agent List'], [id='WiFi Devices']").show()
  labelHide.closest(".control-group").show();
} else if ($("#easyMeshEnable").val() == "0") {
    $("#agentEnable").val("0")
    $("#controllerEnable").val("0")
    $("#wificonductorEnable").val("0")
    $("#wifibandsteerEnable").val("0")
    $("[id='Extender Info'], [id='Agent List'], [id='WiFi Devices']").hide()
    labelHide.closest(".control-group").hide();
}

$(".switch").click(function() {
  if ($("#easyMeshEnable").val() == "1") {
    $("#agentEnable").val("0")
    $("#controllerEnable").val("0")
    $("#wificonductorEnable").val("0")
    $("#wifibandsteerEnable").val("0")
    labelHide.closest(".control-group").hide();
  } else if($("#easyMeshEnable").val() == "0") {
      $("#agentEnable").val("1")
      $("#controllerEnable").val("1")
      $("#wificonductorEnable").val("1")
      $("#wifibandsteerEnable").val("0")
      labelHide.closest(".control-group").show();
  }
});
