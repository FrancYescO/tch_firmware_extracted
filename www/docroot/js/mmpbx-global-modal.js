$(".btn-table-edit, .btn-table-modify, .btn-table-cancel").click(function(){
  document.getElementById("myform").action = "modals/mmpbx-global-modal.lp";
});

$("#Show_Advanced_id").click(function(){
  sessionStorage.setItem("showAdvancedMode", true);
});
$("#Hide_Advanced_id").click(function(){
  sessionStorage.setItem("showAdvancedMode", false);
});

$("#duplicate-value-codec1, #duplicate-value-codec2").removeClass("hide").addClass("hide");
var value;
if (control_qos == "dscp") {
  $("#control_qos_value").after(dscp_control).remove();
}
else if (control_qos == "precedence") {
  $("#control_qos_value").after(precedence_control).remove();
}
if (realtime_qos == "dscp") {
  $("#realtime_qos_value").after(dscp_realtime).remove();
}
else if (realtime_qos == "precedence") {
  $("#realtime_qos_value").after(precedence_realtime).remove();
}
$("#control_qos_field").change(function() {
  value = this.value;
  if (value == "dscp") {
    $("#control_qos_value").after(dscp_control).remove();
  }
  else if (value == "precedence") {
    $("#control_qos_value").after(precedence_control).remove();
  }
});

$("#realtime_qos_field").change(function() {
  value = this.value;
  if (value == "dscp") {
    $("#realtime_qos_value").after(dscp_realtime).remove();
  }
  else if (value == "precedence") {
    $("#realtime_qos_value").after(precedence_realtime).remove();
  }
});

$("#preferredCodec1,#preferredCodec2").change(function() {
  var prefCodec1 = $("#preferredCodec1").val();
  var prefCodec2 = $("#preferredCodec2").val();
    if (prefCodec1 == prefCodec2) {
      $("#duplicate-value-codec1, #duplicate-value-codec2").removeClass("hide").addClass("show");
      $("#save-config").hide();
    }
    else{
      $("#duplicate-value-codec1, #duplicate-value-codec2").removeClass("hide").addClass("hide");
      $("#save-config").show();
    }
});

$("#Refresh_id").click(function(){
  document.getElementById("myform").action = "modals/mmpbx-global-modal.lp";
});
