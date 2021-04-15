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
  if(isGuest){
    $("#wifiGuestbandsteerEnable").val("0")
  }
  labelHide.closest(".control-group").show();
}

function easyMeshDisable() {
  $("#agentEnable").val("0")
  $("#controllerEnable").val("0")
  $("#wificonductorEnable").val("0")
  if (bandsteerDisabled) {
    if (ap0_state == "1" && ap1_state == "1") {
      $("#wifibandsteerEnable").val("1")
    }
    var count = 0
    for(var ap in guestAP){
      var apVal = guestAP[ap]
      if (content[apVal] == "1") {
        count = count + 1
      }
    }
    if (count == guestAP.length && isGuest && count > 1) {
      $("#wifiGuestbandsteerEnable").val("1")
      count = 0
    }
  }
  labelHide.closest(".control-group").hide();
}

if ($("#easyMeshEnable").val() == "1") {
  easyMeshEnable()
  $("[id='" + extenderInfo + "'], [id='" + agentList + "'], [id='" + devicesList + "']").show();
} else if ($("#easyMeshEnable").val() == "0") {
  easyMeshDisable()
  $("[id='" + extenderInfo + "'], [id='" + agentList + "'], [id='" + devicesList + "']").hide();
}

$(".switch").click(function() {
  if ($("#easyMeshEnable").val() == "1") {
    if (confirmPopup == "true") {
      confirmationDialogue(easyMeshDisableMessage, disableTitle, "disable");
      $(document).on("click", ".disable", function() {
        easyMeshDisable()
      });
    } else {
      easyMeshDisable()
    }
  } else if($("#easyMeshEnable").val() == "0") {
    if (confirmPopup  == "true") {
      confirmationDialogue(easyMeshEnableMessage, enableTitle, "enable");
      $(document).on("click", ".enable", function() {
        easyMeshEnable()
      });
    } else {
      easyMeshEnable()
    }
  }
});

