var elements = {
  srcIP    : ".modal.in [id$=SrcIP]:visible",
  DestIP   : ".modal.in [id$=DestIP]:visible",
  srcmask  : ".modal.in [id$=NetmaskSource]:visible",
  destmask : ".modal.in [id$=NetmaskDest]:visible",
  DSCP     : ".modal.in [id$=DSCP]:visible",
}
var validations = {
  srcIP    : IPRegExp,
  DestIP   : IPRegExp,
  srcmask  : IPRegExp,
  destmask : IPRegExp,
  DSCP     : validateNumberRange(0, 63),
}
var editedRow;
var delData =[];
function changeType(typeOfOperation) {
  var typeSelectedIndex;
  if(typeOfOperation == "Adding")
    typeSelectedIndex = $("#type-select")[0].selectedIndex;
  else
    typeSelectedIndex = $("#edit-type-select")[0].selectedIndex;

  /*The typeSelectedIndex equals the index of dropdown list (Type dropdown)
   0 --> Source Interface
   1 --> Source IP
   2 --> Destination IP
   3 --> Protocol Type
   4 --> DSCP */

  switch (typeSelectedIndex) {
    case 0:
        if(typeOfOperation == "Adding")
        {
          $("#SourceInterface").show();
          $("#sourceIP, #destinationIP, #addmsksource, #Protocol, #DiffServ, #addmskdest").hide();
        }
        else
        {
          $("#editSourceInterface").show();
          $("#editsourceIP, #editdestinationIP, #editmsksource, #editProtocol, #editcp, #editmskdest").hide();
        }
        break;
    case 1:
        if(typeOfOperation == "Adding")
        {
          $("#sourceIP").show();
          $("#addmsksource").show();
          $("#SourceInterface, #destinationIP, #Protocol, #DiffServ, #addmskdest").hide();
        }
        else
        {
          $("#editsourceIP").show();
          $("#editmsksource").show();
          $("#editSourceInterface, #editdestinationIP, #editProtocol, #editcp, #editmskdest").hide();
        }
        break;
    case 2:
        if(typeOfOperation == "Adding")
        {
          $("#destinationIP").show();
          $("#addmskdest").show();
          $("#SourceInterface, #sourceIP, #Protocol, #DiffServ, #addmsksource").hide();
        }
        else
        {
          $("#editdestinationIP").show();
          $("#editmskdest").show();
          $("#editSourceInterface, #editsourceIP, #editProtocol, #editcp, #editmsksource").hide();
        }
        break;
    case 3:
        if(typeOfOperation == "Adding")
        {
          $("#Protocol").show();
          $("#SourceInterface, #sourceIP, #destinationIP, #addmsksource, #DiffServ, #addmskdest").hide();
        }
        else
        {
          $("#editProtocol").show();
          $("#editSourceInterface, #editsourceIP, #editdestinationIP, #editmsksource, #editcp, #editmskdest").hide();
        }
        break;
    case 4:
        if(typeOfOperation == "Adding")
        {
          $("#DiffServ").show();
          $("#SourceInterface, #sourceIP, #destinationIP, #addmsksource, #Protocol, #addmskdest").hide();
        }
        else
        {
          $("#editcp").show();
          $("#editSourceInterface, #editsourceIP, #editdestinationIP, #editmsksource, #editProtocol, #editmskdest").hide();
        }
        break;
  }
  $("[role=dialog] .input-error").removeClass("input-error");
}
$(function() {
  $("#policyrouting-btn-addSave-row").click(function() {
    var Type = $("#type-select")[0].selectedIndex;
    var TypeOfService = $("#type-select option:selected").text();
    var wanIntf = $("#select-wan").val();
    var fwdcondition;
    var subnetmask = "";

    switch (Type) {
      case 0:
          fwdcondition = $("#select-lan").val();
          break;
      case 1:
          fwdcondition = $("#policy-routing-txt-addSrcIP").val();
          subnetmask = $("#policy-routing-txt-addNetmaskSource").val();
          break;
      case 2:
          fwdcondition = $("#policy-routing-txt-addDestIP").val();
          subnetmask = $("#policy-routing-txt-addNetmaskDest").val();
          break;
      case 3:
          fwdcondition = $("#select-proto").val();
          break;
      case 4:
          fwdcondition = $("#policy-routing-txt-addDSCP").val();
          break;
    }
    if (!validateElements(elements, validations)) return false;

    $('<div class="table-row" data-type="add">\
    <div class="table-col routeRow op60 type" value="'+Type+'">'+TypeOfService+' </div>\
    <div class="table-col routeRow op60 fwdcondition">'+fwdcondition+'</div>\
    <div class="table-col routeRow op60 wanintf">'+wanIntf+'</div>\
    <div class="table-col routeRow op60"><input class="button button-edit editbutton" type="button" data-toggle="modal" data-target="#policyrouting-edit-modal"></div>\
    <div class="table-col routeRow op60">\<input class="button button-delete deletebutton" type="button"></div>\
    <div class="table-col fR tR">\
        <div class="button toggle-row-enable button-on">\
          <input type="hidden" class="RouteIndex" value="new"/>\
          <input type="hidden" class="subnet" value="'+subnetmask+'"/>\
          <input type="hidden" class="status" value="1"/>\
        </div>\
    </div>\
    </div>').insertBefore("#policyRoute-row-last");
  });

  $(".policy-routing-table").on("click", ".button-add", function() {
    $("#policyrouting-add-modal input[type=text]").each(function(){$(this).val("")});
    $("#SourceInterface").show();
    $("#sourceIP, #destinationIP, #addmsksource, #Protocol, #DiffServ, #addmskdest").hide();
    $("#type-select").val("0").trigger("chosen:updated");
    $("#select-wan option:eq(0)").prop("selected", true).trigger("chosen:updated");
    $("#select-lan").val("LAN").trigger("chosen:updated");
    $("#select-proto").val("TCP").trigger("chosen:updated");
    $("[role=dialog] .input-error").removeClass("input-error");
  });
  $("#policy-routing-btn-editSave-row").click(function() {
    var type = $("#edit-type-select")[0].selectedIndex;
    switch (type) {
      case 0:
          editedRow.find(".fwdcondition").text($("#edit-select-lan").val());
          break;
      case 1:
          editedRow.find(".fwdcondition").text($("#policy-route-txt-editSrcIP").val());
          editedRow.find(".subnet").val($("#policy-route-txt-editNetmaskSource").val());
          break;
      case 2:
          editedRow.find(".fwdcondition").text($("#policy-route-txt-editDestIP").val());
          editedRow.find(".subnet").val($("#policy-route-txt-editNetmaskDest").val());
          break;
      case 3:
          editedRow.find(".fwdcondition").text($("#edit-select-protocol").val());
          break;
      case 4:
          editedRow.find(".fwdcondition").text($("#policy-route-txt-editDSCP").val());
          break;
    }
    if (!validateElements(elements, validations)) return false;
    editedRow.find(".type").text($("#edit-type-select option:selected").text());
    editedRow.find(".type").val(editedRow.find(".type").attr("value", type));
    editedRow.find(".wanintf").text($("#edit-select-wan").val());
    if ((editedRow.attr("data-type"))!="add")
      editedRow.attr("data-type","edit");
  });

  $(".policy-routing-table").on("click", ".button-edit", function() {
    $("#policyrouting-edit-modal input[type=text]").each(function(){$(this).val("")});
    editedRow = $(this).closest("div").parent();
    var rowEditIndex = editedRow.find(".RouteIndex");
    var editType = $.trim(editedRow.find(".type").attr("value"));
    var editfwd  = $.trim(editedRow.find(".fwdcondition").text());
    var editintf = $.trim(editedRow.find(".wanintf").text());
    $("#edit-type-select").val(editType).trigger("chosen:updated");
    if (rowEditIndex.val() == "new" && vdfVariant == "NZ") {
      // Used to restrict page navigation on selecting Cancel within a new rule that is edited
      sessionStorage.setItem("newRule_edit", "true");
    }

    /*editType corresponds to the Type of policy route rule which need to be edited by user.
     The value of editType is equal to the index of dropdown list (Type dropdown) */

    switch (editType) {
      case "0":
          $("#editSourceInterface").show();
          $("#editmsksource").attr('style','display: none');
          $("#editmskdest").attr('style','display: none');
          $("#editsourceIP, #editdestinationIP, #editmsksource, #editProtocol, #editcp, #editmskdest").hide();
          $("#edit-select-lan").val(editfwd).trigger("chosen:updated");
          break;
      case "1":
          var editmask = $.trim(editedRow.find(".subnet").val());
          $("#editsourceIP").show();
          $("#editmsksource").show();
          $("#editmsksource").attr('style','');
          $("#editSourceInterface, #editdestinationIP, #editProtocol, #editcp, #editmskdest").hide();
          $("#policy-route-txt-editSrcIP").val(editfwd);
          $("#policy-route-txt-editNetmaskSource").val(editmask);
          break;
      case "2":
          var editmask = $.trim(editedRow.find(".subnet").val());
          $("#editdestinationIP").show();
          $("#editmskdest").show();
          $("#editmskdest").attr('style','');
          $("#editSourceInterface, #editsourceIP, #editProtocol, #editcp, #editmsksource").hide();
          $("#policy-route-txt-editDestIP").val(editfwd);
          $("#policy-route-txt-editNetmaskDest").val(editmask);
          break;
      case "3":
          $("#editProtocol").show();
          $("#editmsksource").attr('style','display: none');
          $("#editmskdest").attr('style','display: none');
          $("#editSourceInterface, #editsourceIP, #editdestinationIP, #editmsksource, #editcp, #editmskdest").hide();
          $("#edit-select-protocol").val(editfwd).trigger("chosen:updated");
          break;
      case "4":
          $("#editcp").show();
          $("#editmsksource").attr('style','display: none');
          $("#editmskdest").attr('style','display: none');
          $("#editSourceInterface, #editsourceIP, #editdestinationIP, #editmsksource, #editProtocol, #editmskdest").hide();
          $("#policy-route-txt-editDSCP").val(editfwd);
          break;
    }
    $("#edit-select-wan").val(editintf).trigger("chosen:updated");
    $("[role=dialog] .input-error").removeClass("input-error");
  });

  $(".policy-routing-table").on("click", ".button-delete", function(){
    var deleteRow = $(this).closest("div").parent();
    deleteRow.attr("data-type","delete");
    var rowIndex = deleteRow.find(".RouteIndex");
    if (rowIndex.val() == "new" && vdfVariant == "NZ") {
      // To avoid navigation restriction when new unsaved rule is deleted
      sessionStorage.setItem("delete_bypass", "true");
    }
    delData.push({"index":rowIndex.val()});
    deleteRow.hide();
  });
  $("#policy-routing-table").on("click", ".toggle-row-enable", function() {
    var editedRow = $(this).closest("div").parent();
    var editedRowIndex = editedRow.find(".RouteIndex");
    if ($(this).hasClass('button-off')) {
      $(this).closest("div").parent().parent().find(".routeRow").removeClass("op40").addClass("op60");
      $(this).removeClass('button-off');
      $(this).toggleClass('button-on');
      if (editedRowIndex.val() != "new" && vdfVariant == "NZ") {
        detectToggleChanges($(this));
      }
    } else {
      $(this).closest("div").parent().parent().find(".routeRow").removeClass("op60").addClass("op40");
      $(this).removeClass('button-on');
      $(this).toggleClass('button-off');
      if (editedRowIndex.val() != "new" && vdfVariant == "NZ") {
        detectToggleChanges($(this));
      }
    }
    $(this).find(".status").val($(this).hasClass('button-on')?"1":"0");
    var editedbutton = $(this).closest("div").parent().parent();
    if ((editedbutton.attr("data-type"))!="add")
      editedbutton.attr("data-type","editbutton");
  });

  $("#global-cancel").click(function() {
    $("#content").load("/modals/settings/policyRouting.lp");
  });
});

$("#global-apply, #modal-apply").click(function() {
  var totalRows = 0;
  var CSRFtoken = $("#policyroute-form #CSRFtoken").val();
  var target = $("#policyroute-form").attr("action");
  var addData = [];
  var updateData = [];
  var tableData = {} ;
  var postObj = [];
 $('.policy-routing-table').find(".table-row:not(:first):not(:last)").each(function(index) {
    totalRows++;
    if( $(this).attr("data-type")=="add") {
      var index           = $.trim($(this).find(".RouteIndex").val());
      var typeofOperation = $.trim($(this).find(".type").attr("value"));
      var fwdcondition    = $.trim($(this).find(".fwdcondition").text());
      var waninterface    = $.trim($(this).find(".wanintf").text());
      var status          = $(this).find(".status").val() || "1";
      var netmask         = $.trim($(this).find(".subnet").val());
      addData.push({"index":index, "typeofOperation":typeofOperation, "fwdcondition":fwdcondition, "waninterface":waninterface, "status":status, "netmask":netmask});
    }
    else if( $(this).attr("data-type")=="edit" || $(this).attr("data-type")=="editbutton") {
      var index           = $.trim($(this).find(".RouteIndex").val());
      var typeofOperation = $.trim($(this).find(".type").attr("value"));
      var fwdcondition    = $.trim($(this).find(".fwdcondition").text());
      var waninterface    = $.trim($(this).find(".wanintf").text());
      var status          = $(this).find(".status").val() || "1";
      var netmask         = $.trim($(this).find(".subnet").val());
      updateData.push({"index":index, "typeofOperation":typeofOperation, "fwdcondition":fwdcondition, "waninterface":waninterface, "status":status, "netmask":netmask});
    }
  });
  tableData["ADD"] = addData;
  tableData["UPDATE"] = updateData;
   if (delData.length !=0)
     delData.sort(function(a, b){return b["index"]-a["index"]});
  tableData["DELETE"] = delData;
  tableData = JSON.stringify(tableData);
  postObj.push({name  : "policyRouteTable", value:tableData});
  postObj.push({ name : "CSRFtoken", value : CSRFtoken });
  postObj.push({ name : "rows", value : totalRows });
  postHandle(target, postObj);
});

/*Seperate function to handle post request for giving control to the page once the request(success/error) from server is obtained*/
/*This prevents the user from manipulating the page in between a post request*/
function postHandle(target, params) {
  applyCancelPopupHide();
  $.post(target, params, function(responseText, status, XHR) {
     $("#policy-routing-btn-add-row").prop("disabled",true);
     $(".editbutton").prop("disabled",true);
     $(".deletebutton").prop("disabled",true);
     $('.toggle-row-enable').prop('disabled', true);
    if (responseText.status == "success") {
      $(".articlediv > .msg-error").removeClass("show").addClass("hide");
      $(".articlediv > .msg-warning").removeClass("show").addClass("hide");
      $(".articlediv > .message-arrowbox-applied").removeClass("hide").addClass("show");
      }
    else if(responseText.status == "error") {
      $(".articlediv > .msg-error").removeClass("hide").addClass("show");
      $(".articlediv > .msg-warning").removeClass("show").addClass("hide");
      $(".articlediv > .message-arrowbox-applied").removeClass("show").addClass("hide");
    }
    $(".articlediv").removeClass("hide").addClass("show");
    setTimeout(function(){ $(".articlediv").removeClass("show").addClass("hide")}, 3000);
    if (responseText.status == "success") {
      setTimeout(function(){
      $("#content").load("/modals/settings/policyRouting.lp");}, 3000);
    }
    else
    {
      $("#policy-routing-btn-add-row").prop("disabled",false);
      $(".editbutton").prop("disabled",false);
      $(".deletebutton").prop("disabled",false);
      $('.toggle-row-enable').prop('disabled', false);
    }
  });
}
