if (($('#Hide_Advanced_id').css("display") == "none" || $('#Show_Advanced_id').css("display") == "inline") && ($("#Hide_Advanced_id").hasClass("hide") && sessionStorage.getItem("showAdvancedMode") == "false")){
  $("#btn-dhcp-reset").addClass("hide");
}
else{
  $("#btn-dhcp-reset").removeClass("hide");
}
$("#Show_Advanced_id").click(function(){
  sessionStorage.setItem("showAdvancedMode", true);
  $("#btn-dhcp-reset").removeClass("hide");
});
$("#Hide_Advanced_id").click(function(){
  sessionStorage.setItem("showAdvancedMode", false);
  $("#btn-dhcp-reset").addClass("hide");
});
var iPv6StateOnlyChanged = 0;
$("input, select").on("change", function(){
  if(this.id == "dhcpv6State" && iPv6StateOnlyChanged == 0)
    iPv6StateOnlyChanged = 1;
  else
    iPv6StateOnlyChanged = 2;
});
//Override the save button click event to update the IPv6 state alone.
$("#save-config").click(function(){
  if(iPv6StateOnlyChanged == 1){
    var params = [];
    params.push({
      name : "action",
      value : "SAVE"
    },
    {
      name : "iPv6StateOnlyChanged",
      value : "yes"
    },
    {
      name : "dhcpv6State",
      value : $("#dhcpv6State").val()
    }, tch.elementCSRFtoken());
    var target = $(".modal form").attr("action");
    tch.showProgress(waitMsg);
    $.post(target, params, function(response){
      //The following block of code used to display the success/error message and manage the footer.
      $(".alert").remove();
      $("form").prepend(response);
      $("#modal-changes").attr("style", "display:none");
      $("#modal-no-change").attr("style", "display:block");
      iPv6StateOnlyChanged = 0;
      tch.removeProgress();
    });
    return false;
  }
});

$(".public-subnet-settings").show();
$("#save-config").click(function(){
  if($("#Hide_Advanced_id").is(":visible"))
    $("#isAdvanced").val("1");
  else
    $("#isAdvanced").val("0");
});
$("[name ='sleases_mac']").change(function () {
  if ((this.value) == "custom") {
    $(this).replaceWith($('<input/>',{'type':'text', 'name':'sleases_mac'}));
  }
});

var target = $(".modal form").attr("action");
function resetreboot(rebootMsg, confirmMsg, action) {
  confirmMsg.after(rebootMsg);
  rebootMsg.removeClass("hide");
  rebootMsg[0].scrollIntoView();
  $.post(
    target,
    { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
    wait_for_webserver_down,
    "json"
  );
  return false;
}

$("#btn-bridged").click(function() {
  $("#confirming-msg, #bridged-changes").removeClass("hide");
  $(".modal-body").animate({'scrollTop':"+=100px"}, "fast")
});

$("#bridged-confirm").click(function() {
  $("#confirming-msg, #bridged-changes, #btn-bridged").addClass("hide");
  resetreboot($("#rebooting-msg"), $("#btn-bridged"), "BRIDGED");
});

$("#bridged-cancel").click(function() {
  $("#confirming-msg, #bridged-changes, #rebooting-msg").addClass("hide");
});

$("#btn-dhcp-reset").click(function(){
  if(confirm(confirmMessage)) {
    for (var dhcpData in resetData)
    {
      $("#" + dhcpData).val(resetData[dhcpData]);
    }
    $("#dhcpv6State").prev().removeClass("switcherOn").closest(".switch").removeClass("switchOn");
    $("#dhcp4State").prev().addClass("switcherOn").closest(".switch").addClass("switchOn");
    $("#save-config").click();
  }
});
