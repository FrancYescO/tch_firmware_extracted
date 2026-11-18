var index, helperName = "";
$('.switch').removeClass("disabled");
var jsonParam = {}, params = [];
var dmzChanged = 0;
$(document).on("change", '.switch input[type="hidden"]', function () {
  if (this.id == "DMZ_enable" ||this.id == "DMZ_enable_ipv6" ||  this.id == "uci_wan_masq") {
    dmzChanged = 1;
  }
  $("#modal-no-change").hide();
  $("#modal-changes").show();
  $("#popUp, .popUpBG").remove();
  if (dmzChanged == 0){
    index = $(this).closest("tr").index() + 1;
    helperName = (document.getElementById("helper").rows[index].cells[1].lastChild.nodeValue).toLowerCase();
    helperState = document.getElementById("helper").rows[index].cells[0].lastChild.lastChild.value;
    jsonParam[helperName] = helperState;
  }
});

if (showIPv6DMZ) {
  $("#DMZ_enable_ipv6").on('change', function() {
    if ($("#DMZ_enable_ipv6").val() == "1") {
      $("#dmz_switch_alert").removeClass("hide").addClass("show");
    } else {
      $("#dmz_switch_alert").removeClass("show").addClass("hide");
    }
  });
  $("[name ='DMZ_destinationip_ipv6']").change(function () {
      if ((this.value) == "custom") {
        $(this).replaceWith($('<input/>',{'type':'text', 'name':'DMZ_destinationip_ipv6', 'id' : 'DMZ_destinationip_ipv6Input'}));
     }
  });
}

$("[name ='DMZ_destinationip']").change(function () {
    if ((this.value) == "custom") {
      $(this).replaceWith($('<input/>',{'type':'text', 'name':'DMZ_destinationip', 'id' : 'DMZ_destinationipInput'}));
   }
});
$("#save-config").click(function () {
  var dest_ip_new = $("#DMZ_destinationip").val();
  if (showIPv6DMZ) {
    var dest_ip_new_v6 = $("#DMZ_destinationip_ipv6").val();
    if (dmzEnable && (dest_ip_old != dest_ip_new) || (dest_ip_old_v6 != dest_ip_new_v6) ) {
      dmzChanged = 1;
    }
  } else {
    if (dmzEnable && dest_ip_old != dest_ip_new) {
      dmzChanged = 1;
    }
  }
  if (dmzChanged == 0){
    var target = "modals/nat-alg-helper-modal.lp";
    params.push({
      name: "natHelperData",
      value: JSON.stringify(jsonParam)
    }, {
      name: "action",
      value: "SAVE"
    }, {
      name: "dmzChanged",
      value: "true"
    }, tch.elementCSRFtoken());

    $.post(target, params, function (response) {
      $("form").prepend(response);
      tch.removeProgress();
      $('.popUp, .popUpBG').remove();
      dmzChanged = 0;
    });

    var scrolltop = $(".modal-body").scrollTop();
    tch.loadModal(target, function () {
      $(".modal-body").scrollTop(scrolltop);
    });
  }
  else {
    document.getElementById("myform").method = "post";
    document.getElementById("myform").action = "modals/nat-alg-helper-modal.lp";
    dmzChanged = 0;
  }
});

$("#Refresh_id").click(function(){
  document.getElementById("myform").action = "modals/nat-alg-helper-modal.lp";
});
