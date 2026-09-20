var iconType;
var disableEdit = 0;
var disableInfo = 0;
$("#devices tbody tr").each(function (key, val) {
  var obj = $(this)
  if(obj.children("td").find("div").hasClass("off")){
    obj.children("td:nth-child(2)").html("");
  }
});

$(".foldable-container-title").click(function(){
    var temp = $(this).hasClass("smallArrow");
    $(this).removeClass(temp ? "smallArrow" :"smallArrowUp").addClass(temp ? "smallArrowUp" :"smallArrow");
    $(this).children().eq(0).css("display",temp ? "none":"block" );
    $(this).children().eq(1).css("display",temp ? "block":"none" );
    $(this).next().css("display",temp ? "block":"none");
  }
);

function details(val, name ,toggle1 , toggle2) {
    var wifiid = document.getElementById(name+"showDropdown"+val);
    $("."+name+"_arrow_down"+val).css("left", "133px");
    $("."+name+"_arrow_down"+val).css("bottom", "25px");
    if(name == "usb") {
      $("."+name+"_arrow_down"+val).css("left", "140px");
      $("."+name+"_arrow_down"+val).css("bottom", "40px");
      $("."+name+"_arrows"+val).css("bottom", "39px");
    }
    if(wifiid.style.display == "none"){
       $("."+name+"_arrow_down"+val).addClass(toggle2).removeClass(toggle1);
       $("."+name+"_arrows"+val).addClass(toggle1).removeClass(toggle2);
       wifiid.style.display = "block";
    } else {
       $("."+name+"_arrow_down"+val).addClass(toggle2).removeClass(toggle1);
       $("."+name+"_arrows"+val).addClass(toggle1).removeClass(toggle2);
       wifiid.style.display = "none";
    }
}

function close_modal_info(val, type){
    disableInfo = 0;
    var wifiinfo =  document.getElementById(type+"Arrow"+val);
    if(wifiinfo.style.display == "none"){
      wifiinfo.style.display = "block";
    }else {
     wifiinfo.style.display = "none";
    }
}

function device_info(val, type){
   if (disableEdit == "0" && disableInfo == "0") {
     var wifiinfo =  document.getElementById(type+"Arrow"+val);
     disableInfo = 1;
     if(wifiinfo.style.display == "none"){
       wifiinfo.style.display = "block";
     }
   } else { return; }
}

function device_edit_info(val, iconType, type){
   if (disableInfo == "0" && disableEdit == "0") {
      $("#modal_edit_info_"+type+val).removeClass("hidden");
      disableEdit = 1;
      if(iconType != "") {
         $("#"+iconType+" .red").removeClass("hide");
         $("#"+iconType+" .black").addClass("hide");
      }else {
         $("#smartphone .red").removeClass("hide");
         $("#smartphone .black").addClass("hide");
      }
   } else { return; }
}

$('#icon-list .icon').click(function(){
  $('#icon-list .red').addClass("hide");
  $('#icon-list .black').removeClass("hide");
  $(this).children(".black").addClass("hide");
  $(this).children(".red").removeClass("hide");
  $(this).addClass("active");
  iconType = $(this).attr("icon-name");
});

function device_Edit(edit_value, mac, type){
   var edit_device_name = $("#edit_device_name_"+type+edit_value).val();
   disableEdit = 1;
   var params = [];
   params.push({
     name : "action",
     value : "EDIT"
   },
   {
     name : "edit_values" ,
     value : edit_device_name
   },
   {
     name : "macAddress" ,
     value : mac
   },
   {
     name: "icon",
     value: iconType
   },tch.elementCSRFtoken());
   $.post("./modals/device-modal.lp", params, function(response){
      $("#modal_edit_info_"+type+edit_value).addClass("hidden");
   });
   tch.loadModal("./modals/device-modal.lp");
   $('#icon-list .red').addClass("hide");
   $('#icon-list .black').removeClass("hide");
}

function close_modal(){
  disableEdit = 0;
  $('#icon-list .red').addClass("hide");
  $('#icon-list .black').removeClass("hide");
  $(".edit").addClass("hidden");
}

