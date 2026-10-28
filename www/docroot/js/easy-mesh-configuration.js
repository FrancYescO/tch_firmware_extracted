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
    confirmationDialogue("EasyMesh is disabled.<br> You can safely enable Bandsteering, if needed", "Disable EasyMesh");
    $(document).on("click", ".Disable", function() {
      $("#agentEnable").val("0")
      $("#controllerEnable").val("0")
      $("#wificonductorEnable").val("0")
      $("#wifibandsteerEnable").val("0")
      labelHide.closest(".control-group").hide();
    });
    $("#cancel").click(function() {
      $(".switch").addClass("switchOn");
      $(".switcher").addClass("switcherOn");
      $("#easyMeshEnable").val("1");
    });
  } else if($("#easyMeshEnable").val() == "0") {
    confirmationDialogue("EasyMesh is enabled.<br> This action will disable Bandsteering", "Enable EasyMesh");
    $(document).on("click", ".Enable", function() {
      $("#agentEnable").val("1")
      $("#controllerEnable").val("1")
      $("#wificonductorEnable").val("1")
      $("#wifibandsteerEnable").val("0")
      labelHide.closest(".control-group").show();
    });
    $("#cancel").click(function() {
      $(".switch").removeClass("switchOn");
      $(".switcher").removeClass("switcherOn");
      $("#easyMeshEnable").val("0");
    });
  }
});
