var labelHide = $("[id='controllermac'], [id='agentmac']");
var stateBlock = $("[id='state@cred0'], [id='state@cred1'],[id='state@cred2']");
var fronthaulBlock = $("[id='fronthaul@cred0'], [id='fronthaul@cred1'],[id='fronthaul@cred2']");
var backhaulBlock = $("[id='backhaul@cred0'], [id='backhaul@cred1'],[id='backhaul@cred2']");

$(document).on("click", "#ok, #cancel", function() {
  tch.removeProgress();
});

if (multiapAgent == "1" && multiapContr == "1"){
  stateBlock.closest(".control-group .controls").css({"pointer-events":"none","opacity":"0.5"});
  fronthaulBlock.closest(".control-group .controls").css({"pointer-events":"none","opacity":"0.5"});
  backhaulBlock.closest(".control-group .controls").css({"pointer-events":"none","opacity":"0.5"});
}

function easyMeshEnable() {
  $("#agentEnable").val("1")
  $("#controllerEnable").val("1")
  $("#wificonductorEnable").val("1")
  $("#wifibandsteerEnable").val("0")
  labelHide.closest(".control-group").show();
}

function easyMeshDisable() {
  $("#agentEnable").val("0")
  $("#controllerEnable").val("0")
  $("#wificonductorEnable").val("0")
  $("#wifibandsteerEnable").val("0")
  labelHide.closest(".control-group").hide();
}

if ($("#easyMeshEnable").val() == "1") {
  easyMeshEnable()
  $("[id='Extender Info'], [id='Agent List'], [id='WiFi Devices']").show()
} else if ($("#easyMeshEnable").val() == "0") {
  easyMeshDisable()
  $("[id='Extender Info'], [id='Agent List'], [id='WiFi Devices']").hide()
}

$(".switch").click(function() {
  if ($("#easyMeshEnable").val() == "1") {
    if (confirmPopup == "true") {
      confirmationDialogue("EasyMesh is disabled.<br> You can safely enable Bandsteering, if needed", "Disable EasyMesh");
      $(document).on("click", ".Disable", function() {
        easyMeshDisable()
      });
    } else {
      easyMeshDisable()
    }
  } else if($("#easyMeshEnable").val() == "0") {
    if (confirmPopup  == "true") {
      confirmationDialogue("EasyMesh is enabled.<br> This action will disable Bandsteering", "Enable EasyMesh");
      $(document).on("click", ".Enable", function() {
        easyMeshEnable()
      });
    } else {
      easyMeshEnable()
    }
  }
});

