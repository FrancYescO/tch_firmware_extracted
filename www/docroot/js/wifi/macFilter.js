  var resetPage = false;

  $(function () {
    $('select').chosen({
      disable_search_threshold: 100000,
      allow_single_deselect: true
    });
  });

var noMacMsg = $(".no-mac-rule").closest("div.no-mac-rule-parent");
function showMessageDeny(){
  var denyChecked = $("#macfilter-rad-deny").prop("checked");
  if((denyChecked == true) && ($("#mac-list-deny-main .row").length == 0)){
    noMacMsg.addClass("show");
    noMacMsg.removeClass("hide");
  } else if((denyChecked == true) && ($("#mac-list-deny-main .row").length != 0)){
    noMacMsg.addClass("hide");
    noMacMsg.removeClass("show");
  }
}
function showMessageAllow(){
  var allowChecked = $("#macfilter-rad-allow").prop("checked");
  if((allowChecked == true) && ($("#mac-list-allow-main .row").length == 0)){
    noMacMsg.addClass("show");
    noMacMsg.removeClass("hide");
  } else if((allowChecked == true) && ($("#mac-list-allow-main .row").length != 0)) {
    noMacMsg.addClass("hide");
    noMacMsg.removeClass("show");
  }
}
function MACRow(selectiveClass, mode, inputClass, name, splitMac, rowIndex){
  var getMACList = '<div class="newMacRow row padding-left-15  '+selectiveClass+' macfilter-padding-40 macfilter-mobile-padding-left del-accept" data-row="'+rowIndex+'" data-mode='+mode+'>'+
    '<div class="col-md-4 col-sm-4 col-xs-12 padding-top-bottom-20 mobile-padding-left-none mobile-mac-filter-top-bottom macfilter-column-4 macfilter-mobile-no-padding-bottom">'+
        '<p><span class="hidden-lg hidden-md hidden-sm">' + T["Name"] + '</span>'+
        '</p>'+
        '<p>'+
            '<input name="" type="text" class="mac-filter-txtbox" value="'+name+'" disabled>'+
        '</p>'+
    '</div>'+
    '<div class="col-md-7 col-sm-7 col-xs-12 padding-top-bottom-20 mobile-padding-left-none mobile-mac-filter-top-bottom no-padding-left-right macfilter-column-3">'+
        '<p><span class="hidden-lg hidden-md hidden-sm">' + T["MAC Address"] + '</span>'+
        '</p>'+
        '<p>'+
            '<input class="max2 mobile-mac-filter-max2 '+inputClass+' alphanum" name="" value="'+splitMac[0]+'" type="text" disabled><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">. </span>'+
            '<input class="max2 mobile-mac-filter-max2 '+inputClass+' alphanum" name="" value="'+splitMac[1]+'" type="text" disabled><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">. </span>'+
            '<input class="max2 mobile-mac-filter-max2 '+inputClass+' alphanum" name="" value="'+splitMac[2]+'" type="text" disabled><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">. </span>'+
            '<input class="max2 mobile-mac-filter-max2 '+inputClass+' alphanum" name="" value="'+splitMac[3]+'" type="text" disabled><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">. </span>'+
            '<input class="max2 mobile-mac-filter-max2 '+inputClass+' alphanum" name="" value="'+splitMac[4]+'" type="text" disabled><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">. </span>'+
            '<input class="max2 mobile-mac-filter-max2 '+inputClass+' alphanum" name="" value="'+splitMac[5]+'" type="text" disabled>'+
        '</p>'+
    '</div>'+
    '<div class="padding-top-bottom-20 text-right mobile-padding-left-none macfilter-mobile-padding-top-bottom mac-filter-deleteIcon">'+
        '<input class="button button-delete " value="" type="button" id="macfilter-btn-del24" onclick="deleteRow(this)">'+
    '</div>'+
'</div>';
return getMACList;
}
function assignMACAllow(name,macAddr,rowInd)
{
  var allowedchars=/\d+/;
  var rowIndex = rowInd.match(allowedchars);
  if (macAddr == "")
    return;
  var splitMac = macAddr.split(":");
  var macAllow=MACRow("mac-allow-edit24", "allow", "mac-allow24", name, splitMac, rowIndex)
  noMacMsg.addClass("hide");
  noMacMsg.removeClass("show");
  $("#mac-list-allow-main").append(macAllow);
}

function assignMACDeny(name,macAddr,rowInd)
{
  if (macAddr == "")
    return;
  var allowedchars=/\d+/;
  var rowIndex = rowInd.match(allowedchars);
  var splitMac  = macAddr.split(":");
  var macDeny=MACRow("mac-deny-edit24", "deny", "mac-deny24", name, splitMac, rowIndex)
  noMacMsg.addClass("hide");
  noMacMsg.removeClass("show");
  $("#mac-list-deny-main").append(macDeny);
}
var delObjAllow, delObjDeny, currentRow;
var allowDeleteCount = 0 , blockDeleteCount =0;
var deleteArgs = [];
function deleteRow(element){
  currentRow = $(element);
  currentRow.closest(".newMacRow").remove();
  var deletedRow = currentRow.closest("div.newMacRow").attr("data-row");
  var $myDiv = $(".newMacRow");
  showMessageAllow();
  showMessageDeny();
  var chosenMode = currentRow.parent().parent().data("mode");
  if(chosenMode == "allow"){
    allowDeleteCount = allowDeleteCount +1;
    delObjAllow = currentRow.closest(".newMacRow").data("row");
    deleteArgs.push({
      name  : "allowDeleteInstance"+allowDeleteCount+"",
      value : delObjAllow,});}
  else if(chosenMode == "deny"){
    blockDeleteCount = blockDeleteCount +1;
    delObjDeny = currentRow.closest(".newMacRow").data("row");
    deleteArgs.push({
      name  : "denyDeleteInstance"+blockDeleteCount+"",
      value : delObjDeny,});}
  if (deletedRow == "new" && vdfVariant == "NZ") {
    // To avoid navigation restriction when new unsaved rule is deleted
    sessionStorage.setItem("delete_bypass", "true");
  }
}
function addNewRow()
{
  var getId, retrieveId, macVal1, macVal2, macVal3, macVal4, macVal5, macVal6, macName;
  if($("#macfilter-rad-allow").prop("checked") == true){
    retrieveId = "mac-list-allow-main";}
  else if ($("#macfilter-rad-deny").prop("checked") == true){
    retrieveId = "mac-list-deny-main";}
  getId = $("#"+retrieveId+" .mac-add").length;
  var addValue = 1 , index = 0, addedRow = [];
  for(i=1;i<=getId;i++){
    if(i>1){
      addValue = addValue+2;
      index = index + 1;}
    var addObject = {};
    macName=$("#"+retrieveId+" div.mac-add:eq("+index+") div:nth-child(1) input").val();
    var getValue = "#"+retrieveId+" div.mac-add div:nth-child(2) p:eq("+addValue+")";
    macVal1=$(""+getValue+" input:eq(0)").val();
    macVal2=$(""+getValue+" input:eq(1)").val();
    macVal3=$(""+getValue+" input:eq(2)").val();
    macVal4=$(""+getValue+" input:eq(3)").val();
    macVal5=$(""+getValue+" input:eq(4)").val();
    macVal6=$(""+getValue+" input:eq(5)").val();
    addObject.name=macName;
    addObject.value=macVal1+":"+macVal2+":"+macVal3+":"+macVal4+":"+macVal5+":"+macVal6;
    addedRow.push(addObject);
  }
return addedRow;
}
  $(function(){
    if(macMode_aclMode24 == "disabled") {
    $("#macfilter-btn-mode").addClass("button-off");
    $("#macfilter-btn-mode").removeClass("button-on");
    } else {
    $("#macfilter-btn-mode").addClass("button-on");
    $("#macfilter-btn-mode").removeClass("button-off");
    }
    if(macMode_aclMode24 == "lock") {
      $("#macfilter-rad-allow").prop("checked",true);
      $("#macfilter-rad-deny").prop("checked",false);
      $("#mac-list-allow-main").show();
      $("#mac-list-deny-main").hide();
    } else if(macMode_aclMode24 == "unlock") {
      $("#macfilter-rad-allow").prop("checked",false);
      $("#macfilter-rad-deny").prop("checked",true);
      $("#mac-list-allow-main").hide();
      $("#mac-list-deny-main").show();
    }

    $.each(allowList, function(i, v) {
      assignMACAllow(hostTable[v.value] ? hostTable[v.value] : "unknown-" + v.value, v.value, v.paramindex);
    });
    $.each(denyList, function(i, v) {
      assignMACDeny(hostTable[v.value] ? hostTable[v.value] : "unknown-" + v.value, v.value, v.paramindex);
    });

    if($("#macfilter-btn-mode").hasClass('button-on')){
      $("#macfilter-hide").removeClass('hide');}
    else{
      $("#macfilter-hide").addClass('hide');
      $("#macfilter-rad-deny").prop("checked",true);
      $("#mac-list-allow-main").hide();
      $("#mac-list-deny-main").show();
    }
    $("#macfilter-btn-mode").click(function() {
      detectToggleChanges($(this));
      if($(this).hasClass('button-on')){
        $(this).removeClass('button-on');
        $(this).addClass('button-off');
        $("#macfilter-hide").addClass('hide');}
      else {
        $(this).removeClass('button-off');
        $(this).addClass('button-on');
        $("#macfilter-hide").removeClass('hide');
      }
    });
    $("#macfilter-rad-deny").change(function(){
      $("#mac-list-allow-main").hide();
      $("#mac-list-deny-main").show();
    });
    $("#macfilter-rad-allow").change(function(){
      $("#mac-list-allow-main").show();
      $("#mac-list-deny-main").hide();
   });
      // Add New Mac Address
    $(".macfilter-btn-add").click(function(){
      var chosenClass1 , chosenClass2;
      if($("#macfilter-rad-allow").prop("checked") == true){
        chosenClass1 = "mac-allow-edit24";
        chosenClass2 = "mac-allow24";
      } else
      {
        chosenClass1 = "mac-deny-edit24";
        chosenClass2 = "mac-deny24";
      }
      var mac_list='<div class="newMacRow row padding-left-15 mac-list-allow-main-tr macfilter-padding-40 macfilter-mobile-padding-left mac-add '+chosenClass1+'" data-row = "new">'+
    '<div class="col-md-4 col-sm-4 col-xs-12 padding-top-bottom-20 mobile-padding-left-none mobile-mac-filter-top-bottom macfilter-column-4 macfilter-mobile-no-padding-bottom">'+
        '<p><span class="hidden-lg hidden-md hidden-sm">' + T["Name"] + '</span>'+
        '</p>'+
        '<p>'+
            '<input name="allowed_mac" class="mac-filter-txtbox mac-add-name" type="text" value="" autocomplete="off">'+
        '</p>'+
    '</div>'+
    '<div class="col-md-7 col-sm-7 col-xs-12 padding-top-bottom-20 mobile-padding-left-none mobile-mac-filter-top-bottom no-padding-left-right macfilter-column-3">'+
        '<p><span class="hidden-lg hidden-md hidden-sm">' + T["MAC Address"] + '</span>'+
        '</p>'+
        '<p>'+
            '<input class="max2 macnew mobile-mac-filter-max2 alphanum '+chosenClass2+'" name="" value="" maxlength="2" type="text" autocomplete="off"><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">. </span>'+
            '<input class="max2 macnew mobile-mac-filter-max2 alphanum '+chosenClass2+'" name="" value="" maxlength="2" type="text" autocomplete="off"><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">. </span>'+
            '<input class="max2 macnew mobile-mac-filter-max2 alphanum '+chosenClass2+'" name="" value="" maxlength="2" type="text" autocomplete="off"><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">. </span>'+
            '<input class="max2 macnew mobile-mac-filter-max2 alphanum '+chosenClass2+'" name="" value="" maxlength="2" type="text" autocomplete="off"><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">. </span>'+
            '<input class="max2 macnew mobile-mac-filter-max2 alphanum '+chosenClass2+'" name="" value="" maxlength="2" type="text" autocomplete="off"><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">. </span>'+
            '<input class="max2 macnew mobile-mac-filter-max2 alphanum '+chosenClass2+'" name="" value="" maxlength="2" type="text" autocomplete="off">'+
        '</p>'+
    '</div>'+
    '<div class="padding-top-bottom-20 text-right mobile-padding-left-none macfilter-mobile-padding-top-bottom mac-filter-deleteIcon">'+
        '<input class="button button-delete" value="" type="button" id="macfilter-btn-del24" onclick="deleteRow(this)">'+
    '</div>'+
'</div>';
      noMacMsg.addClass("hide");
      noMacMsg.removeClass("show");
      if($("#macfilter-rad-allow").prop("checked") == true){
        $("#mac-list-allow-main").append(mac_list);
      }else
      {
       $("#mac-list-deny-main").append(mac_list);
      }
    });

$("#macFilter-form").on("keyup", ".macnew", function(){
  var textfield = $(this);
  if(textfield.val().length >= 2 ) {
    if (textfield.next().length > 0) {
      textfield.next().focus();
    }
  };
});
$("#macfilter-rad-allow").click(function()
{
  $("#macfilter-rad-allow").prop("checked",true);
  $("#macfilter-rad-deny").prop("checked",false);
});
$("#macfilter-rad-deny").click(function()
{
  $("#macfilter-rad-allow").prop("checked",false);
  $("#macfilter-rad-deny").prop("checked",true);
});
showMessageDeny();
showMessageAllow();
$("#macfilter-rad-allow").click(function()
{
  showMessageAllow();
});
$("#macfilter-rad-deny").click(function()
{
  showMessageDeny();
});

var selectedValues = [];
var friendlyName = [];
$("#content").on('click', '#macfilter-btn-addmac', function(){
    var chosenClass1, chosenClass2 ;
     if( $("#macfilter-rad-allow").prop("checked") == true){
            chosenClass1 = "mac-allow-edit24";
            chosenClass2 = "mac-allow24";
          } else
          {
            chosenClass1 = "mac-deny-edit24";
            chosenClass2 = "mac-deny24";
          }
      $(".device01").each(function() {
        if ($(this).prop("checked")) {
          var macArrayAllow = [];
          var macArrayDeny = [];
          $(".row .mac-allow-edit24").each(function(index) {
            macArrayAllow[index] = [];
            $(this).find(".mac-allow24").each(function() {
              macArrayAllow[index].push($(this).val());
            });
            macArrayAllow[index] = macArrayAllow[index].join(":");
          });
          $(".row .mac-deny-edit24").each(function(index) {
            macArrayDeny[index] = [];
            $(this).find(".mac-deny24").each(function() {
              macArrayDeny[index].push($(this).val());
            });
            macArrayDeny[index] = macArrayDeny[index].join(":");
          });
          var name = $(this).parent().find(".checkbox-label").text();
          var mac = $(this).parent().parent().find(".checkbox-mac").text();
          if($("#macfilter-rad-allow").prop("checked") == true){
          if ( macArrayAllow.indexOf(mac) != -1) { return true;}}
          else{
          if ( macArrayDeny.indexOf(mac) != -1) { return true;}
          }
          var splitMac = mac.split(":");
          var mac_list='<div class="newMacRow row padding-left-15 mac-list-allow-main-tr macfilter-padding-40 macfilter-mobile-padding-left mac-add '+chosenClass1+'">'+
    '<div class="col-md-4 col-sm-4 col-xs-12 padding-top-bottom-20 mobile-padding-left-none mobile-mac-filter-top-bottom macfilter-column-4 macfilter-mobile-no-padding-bottom">'+
        '<p><span class="hidden-lg hidden-md hidden-sm">' + T["Name"] + '</span>'+
        '</p>'+
        '<p>'+
            '<input name="" class="deviceName mac-filter-txtbox mac-add-name" type="text" autocomplete="off" value="'+name+'" disabled>'+
        '</p>'+
    '</div>'+
    '<div class="col-md-7 col-sm-7 col-xs-12 padding-top-bottom-20 mobile-padding-left-none mobile-mac-filter-top-bottom no-padding-left-right macfilter-column-3">'+
        '<p><span class="hidden-lg hidden-md hidden-sm">' + T["MAC Address"] + '</span>'+
        '</p>'+
        '<p>'+
            '<input class="max2 mobile-mac-filter-max2 alphanum '+chosenClass2+'" name="" type="text" value="'+splitMac[0]+'" disabled><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">. </span>'+
            '<input class="max2 mobile-mac-filter-max2 alphanum '+chosenClass2+'" name="" type="text" value="'+splitMac[1]+'" disabled><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">. </span>'+
            '<input class="max2 mobile-mac-filter-max2 alphanum '+chosenClass2+'" name="" type="text" value="'+splitMac[2]+'" disabled><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">. </span>'+
            '<input class="max2 mobile-mac-filter-max2 alphanum '+chosenClass2+'" name="" type="text" value="'+splitMac[3]+'" disabled><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">.</span>'+
            '<input class="max2 mobile-mac-filter-max2 alphanum '+chosenClass2+'" name="" type="text" value="'+splitMac[4]+'" disabled><span class="hidden-xs">.</span><span class="hidden-md hidden-sm hidden-lg">.</span>'+
            '<input class="max2 mobile-mac-filter-max2 alphanum '+chosenClass2+'" name="" type="text" value="'+splitMac[5]+'" disabled>'+
        '</p>'+
    '</div>'+
    '<div class="padding-top-bottom-20 text-right mobile-padding-left-none macfilter-mobile-padding-top-bottom mac-filter-deleteIcon">'+
        '<input class="button button-delete" value="" type="button" id="macfilter-btn-del24" onclick="deleteRow(this)">'+
    '</div>'+
'</div>';
          noMacMsg.addClass("hide");
          noMacMsg.removeClass("show")
          if($("#macfilter-rad-allow").prop("checked") == true){
            $("#mac-list-allow-main").append(mac_list);
          } else
          {
           $("#mac-list-deny-main").append(mac_list);
          }
        }
      });
      $('#addModal').modal('hide')
    });

    $("#macfilter-rad-allow, #macfilter-rad-deny").change(function(){
      $(".device01").prop("checked", false)
    });

  var elements = {
    deviceName: "#macFilter-form .mac-filter-txtbox:visible",
    MACAddress: "#macFilter-form .max2:visible",
  }

  var validations = {
    deviceName: validateStringLength(1, 63),
    MACAddress: MACOctetRegExp,
  }
$("#global-apply, #modal-apply").click(function() {

  if (!validateElements(elements, validations)) {
    return false
  }

  var params = [];
  for (var i = 0; i < deleteArgs.length; i++) {
    params.push(deleteArgs[i]);
  }
  var addRowCount = 0, addRowCount5 = 0;
   var get_addrow = addNewRow();
  if (!get_addrow) return false;
    params.push({
          name  : "blockDeleteCount",
          value : blockDeleteCount,
          },{
          name  : "allowDeleteCount",
          value : allowDeleteCount,
          });
  $.each(get_addrow, function( key, value ) {
    addRowCount = addRowCount + 1;
    params.push({
      name  : "newAddMacName"+addRowCount+"",
      value : value.name
      }, {
      name  : "newAddMacAddr"+addRowCount+"",
      value : value.value
    });
  });
  params.push({
      name : "addRowCount",
      value : addRowCount,
      })
var target = "/modals/wifi/macFilter.lp";
var macControlTwoState24 = $("#macfilter-rad-allow").prop("checked") ? true : false;
var macControlStateDis24 = $("#macfilter-btn-mode").hasClass("button-on") ? 1 : 0;
var mac_value24;
if (macControlStateDis24 == "0"){
  macControlStateDis24 = "disabled";
  params.push({
      name : "aclMode24",
      value : macControlStateDis24
    });}
else{
  if(macControlTwoState24 == true) {
    mac_value24 = "lock"}
  else{
    mac_value24 = "unlock"}
    params.push({
      name : "aclMode24",
      value : mac_value24
    });}
params.push({
  name : "action",
  value : resetPage ? "Reset" : "SAVE"
  }, {
  name : "CSRFtoken",
  value : $("meta[name=CSRFtoken]").attr("content") });
postHandler(target, params,true);
});
$("#global-cancel").click(function() {
  $("#content").load("/modals/wifi/macFilter.lp"); });
});
$("#resetR, .resetR").click(function(){
  resetPage = true;
  $("#macfilter-btn-mode").val(resetmacfilter_enable);
  if (resetmacfilter_enable == "1") {
    $('#macfilter-btn-mode').addClass('button-on').removeClass('button-off');
    $('#macfilter-hide').removeClass("hide").addClass("show");
  }
  else
  {
    $('#macfilter-btn-mode').addClass('button-off').removeClass('button-on');
    $('#macfilter-hide').removeClass("show").addClass("hide");
  }
  $("#macfilter-btn-mode").val(resetmacfilter_access);
  if (resetmacfilter_access == "allow") {
    $("#macfilter-rad-allow").prop("checked",true);
    $("#macfilter-rad-deny").prop("checked",false);
  }
  else
  {
    $("#macfilter-rad-allow").prop("checked",false);
    $("#macfilter-rad-deny").prop("checked",true);
  }
  $('.button-delete').click();
});
