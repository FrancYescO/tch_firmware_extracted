var pppdvalue = {
  "chap" : "refuse-pap refuse-eap refuse-mschap refuse-mschap-v2" ,
  "pap"  : "refuse-chap refuse-eap refuse-mschap refuse-mschap-v2",
  "auto" : ""
}

function assignIP(id_str, ip_addr,obj, divClass){
  var IPInputElementDiv =  obj.find(divClass)
  var splitIP = ip_addr.split(".");
  if (splitIP){
    IPInputElementDiv.find("input:eq(0)").val(splitIP[0]);
    IPInputElementDiv.find("input:eq(1)").val(splitIP[1]);
    IPInputElementDiv.find("input:eq(2)").val(splitIP[2]);
    IPInputElementDiv.find("input:eq(3)").val(splitIP[3]);
  }else{
    IPInputElementDiv.find("input").val("");
  }
}

function combineIP(id){
  var ip = [] ;
  var IPAddress
  for(var i=1; i<=4; i++)
  {
    ip[i-1] = $("#"+id+i).val();
    IPAddress = ip.join(".");
  }
  if (IPAddress == "...") { IPAddress = "" }
  return IPAddress
}

// Loading option based on proto type
function addressMode(val, ifname, vlanname){
  $('#wan-sel-addmode').empty();
  if (val == "pppoe" || val == "pppoa" ){
   if (ifname == "eth4" && vlanname == ""){
    $(".ipv6-div").css("display","none");
    $('#wan-sel-addmode').append('<option value="dynamic">'+T["Dynamic"]+'</option>');
    $('#wan-sel-addmode').trigger("chosen:updated");
   }else{
    $('#wan-sel-addmode').append('<option value="dynamic">'+T["Dynamic"]+'</option>');
    $('#wan-sel-addmode').trigger("chosen:updated");
    $('.dynamic').css("display","");
    $('.static').css("display","none");
    $('.pppoe').css("display", "");
   }
  }
  else if(val == "ipoa" ){
    $('#wan-sel-addmode').append('<option value="static">'+T["Static"]+'</option>');
    $('#wan-sel-addmode').trigger("chosen:updated");
    $('.pppoe').css("display", "none");
    $('.dynamic').css("display","none");
    $('.static').css("display","");
  }else {
    $('.pppoe').css("display", "none");
    $('#wan-sel-addmode').append('<option value="static">'+T["Static"]+'</option>');
    $('#wan-sel-addmode').append('<option value="dynamic">'+T["Dynamic"]+'</option>');
    $('#wan-sel-addmode').trigger("chosen:updated");
    if ($('#wan-sel-addmode').val() == "static"){
      $('.dynamic').css("display","none");
      $('.static').css("display","")
    } else {
      $('.dynamic').css("display","");
      $('.static').css("display","none")
    }
  }
}

var pppdList = {
  "refuse-pap refuse-eap refuse-mschap refuse-mschap-v2"  : "chap",
  "refuse-chap refuse-eap refuse-mschap refuse-mschap-v2" : "pap",
}
$(function(){
  $(".auto-button").each(function(){
    if ($(this).hasClass("button-off")){
      $(this).closest(".table-row").css("opacity", "0.4");
    }
  });
  $("#wan-sel-conntype").change(function(){
    addressMode($(this).val(), ifnameglobal, vlannameglobal);
  });
  $("#wan-sel-addmode").change(function(){
    if ( $("#wan-sel-addmode").val() == "dynamic" ){
      $(".dynamic").css("display", "");
      $(".static").css("display","none" );
    }else {
      $(".dynamic").css("display", "none");
      $(".static").css("display","" );
    }
  });

  $(document).on("click",".wan-edit", function(){
    $('#wan-sel-conntype option[value="ipoa"]').remove().trigger("chosen:updated");
    $('#wan-sel-conntype option[value="pppoa"]').remove().trigger("chosen:updated");
    $("#wan-txt-vpi").closest(".vdf-row").find(".left").html("<span>"+T["VPI [0-255]"]+"</span>")
    $("#wan-txt-vci").closest(".vdf-row").find(".left").html("<span>"+T["VCI [32-65535]"]+"</span>")
    $("#wan-txt-vci").removeClass("op40");
    var editedFor = $(this).closest(".h3-content").prev().text();
    editedRow = $(this).closest(".table-row");
    var proto = editedRow.find(".proto").val();
    var vpi_802priority = editedRow.find(".vpi_802priority").val();
    var vci_vlanid = editedRow.find(".vci_vlanid").val();
    var usedFor = editedRow.find(".table-usedfor").find("span").attr("data-value")
    $("#wan-sel-usedfor").val(usedFor).trigger("chosen:updated")
    var firewall = editedRow.find(".firewall").val();
    var qos = editedRow.find(".qos").val();
    var nat = editedRow.find(".nat").val();
    var ipaddress = editedRow.find(".wanip").val();
    var subnetmask = editedRow.find(".wansubnet").val();
    var gateway = editedRow.find(".wangw").val();
    var option12 = editedRow.find(".option12").val();
    var option60 = editedRow.find(".option60").val();
    var option61laid = editedRow.find(".option61laid").val();
    var option61duid = editedRow.find(".option61duid").val();
    var option125 = editedRow.find(".option125").val();
    var username = editedRow.find(".username").val();
    var password = editedRow.find(".password").val();
    var servicename = editedRow.find(".servname").val();
    var authmethod = editedRow.find(".authmethod").val();
    var conntigger = editedRow.find(".conntigger").val();
    var lcp = editedRow.find(".lcpecho").val();
    var mtu = editedRow.find(".mtu").val();
    var obtdns = editedRow.find(".obtdns").val();
    var ifname = editedRow.find(".ifname").val();
    ifnameglobal = editedRow.find(".ifname").val();
    vlannameglobal = editedRow.find(".vlanname").val();
    var ulp = editedRow.find(".ulp").val();
    var ipv6 = editedRow.find(".ipv6").val();
    var ipaddressmode = editedRow.find(".ipaddressmode").val();
    var primaryDNS = editedRow.find(".primaryDNS").val();
    var secondaryDNS = editedRow.find(".secondaryDNS").val();
    if (vci_vlanid == "nil"){
      vci_vlanid = "";
      $("#wan-txt-vci").addClass("op40");
    }
    if (editedFor == "WAN ADSL"){
      $("#wan-txt-vpi").val(vpi_802priority);
      $("#wan-txt-vci").val(vci_vlanid);
      $('#wan-sel-conntype').append($('<option>', {
        value: "ipoa",
        text: T["IPoA"]
      })).trigger("chosen:updated");
      $('#wan-sel-conntype').append($('<option>', {
        value: "pppoa",
        text: T["PPPoA"]
      })).trigger("chosen:updated")
    } else {
      $("#wan-txt-vpi").closest(".vdf-row").find(".left").html("<span>"+T["802.1P Priority [0-7]"]+"</span>")
      $("#wan-txt-vci").closest(".vdf-row").find(".left").html("<span>"+T["802.1Q VLAN ID [0-4094]"]+"</span>")
      $("#wan-txt-vpi").val(vpi_802priority);
      $("#wan-txt-vci").val(vci_vlanid);
    }
    if  (proto == "static" || proto == "dhcp"  || ipaddressmode == "static" || ipaddressmode == "dhcp"){
      if (editedFor == "WAN ADSL"){
        if (ulp == "eth"){
          $("#wan-sel-conntype").val("ipoe").trigger("chosen:updated");
        }else if (ulp == "ip"){
          $("#wan-sel-conntype").val("ipoa").trigger("chosen:updated");
        }else{
          $("#wan-sel-conntype").val("ipoe").trigger("chosen:updated");
        }
      } else {
        $("#wan-sel-conntype").val("ipoe").trigger("chosen:updated");
      }
    }else {
      $("#wan-sel-conntype").val(proto).trigger("chosen:updated");
    }
    if (vdfVariant == "NZ" && (proto == "pppoe" || proto == "pppoa")){
      $('#wan-sel-addmode option[value="static"]').remove().trigger("chosen:updated");
    }
    addressMode($("#wan-sel-conntype").val(), ifname, vlannameglobal);
    if (proto == "static" || ipaddressmode == "static"){
      $("#wan-sel-addmode").val("static").trigger("chosen:updated");
    }else{
      $("#wan-sel-addmode").val("dynamic").trigger("chosen:updated");
    }
    (firewall == "0")  ? $("#wan-btn-firewall").removeClass("button-on").addClass("button-off") : $("#wan-btn-firewall").removeClass("button-off").addClass("button-on") ;
    (ipv6 == "0")  ? $("#wan-btn-ipv6").removeClass("button-on").addClass("button-off") : $("#wan-btn-ipv6").removeClass("button-off").addClass("button-on") ;
    (nat == "0")  ? $("#wan-btn-nat").removeClass("button-on").addClass("button-off") : $("#wan-btn-nat").removeClass("button-off").addClass("button-on");
    (qos == "0")  ? $("#wan-btn-qos").removeClass("button-on").addClass("button-off") : $("#wan-btn-qos").removeClass("button-off").addClass("button-on");
    assignIP("wan-txt-ipaddress", ipaddress, $("#wanadsl-edit-popup"),".wan-div-address"  )
    assignIP("wan-txt-subnet", subnetmask, $("#wanadsl-edit-popup"), ".wan-div-subnet"  )
    assignIP("wan-txt-gateway", gateway, $("#wanadsl-edit-popup"), ".wan-div-gateway" )
    assignIP("wan-txt-pridns", primaryDNS, $("#wanadsl-edit-popup"), ".wan-div-primaryDNS" )
    assignIP("wan-txt-secdns", secondaryDNS, $("#wanadsl-edit-popup"), ".wan-div-secondaryDNS" )
    $("#wan-txt-username").val(username);
    $("#wan-txt-password").val(password);
    $("#wan-txt-servicename").val(servicename);
    //(pppdList[authmethod]) ?  $("#wan-sel-authmethod").val(pppdList[authmethod]).trigger("chosen:updated") : $("#wan-sel-authmethod").val("auto").trigger("chosen:updated");
    (authmethod != "") ? $("#wan-sel-authmethod").val(authmethod).trigger("chosen:updated"): $("#wan-sel-authmethod").val("auto").trigger("chosen:updated") ;
    (conntigger == "" || conntigger == "1") ? $("#wan-sel-conntrigger").val("alwayson").trigger("chosen:updated") : $("#wan-sel-conntrigger").val("ondemand").trigger("chosen:updated");
    $("#wan-txt-lcp").val(lcp);
    $("#wan-txt-mtu").val(mtu);
    (obtdns != "0")  ? $("#wan-btn-obtdns").removeClass("button-off").addClass("button-on") :  $("#wan-btn-obtdns").removeClass("button-on").addClass("button-off");
    $("#wan-txt-option12").val(option12);
    $("#wan-txt-option60").val(option60);
    $("#wan-txt-option61laid").val(option61laid);
    $("#wan-txt-option61duid").val(option61duid);
    if (($("#wan-sel-conntype").val() == "pppoe")||((vdfVariant == "NZ") && ($("#wan-sel-conntype").val() == "pppoa"))){
      if (ifname == "eth4" && vlannameglobal =="") {
        $(".ipv6-div").css("display","none" );
      }else{
         $(".pppoe").css("display","" )
      }
    } else {
      $(".pppoe").css("display","none" );
    }
    //$("#wan-sel-conntype").val() == "pppoe" ?  $(".pppoe").css("display","" ) : $(".pppoe").css("display","none" );
    if ($("#wan-sel-addmode").val() == "dynamic"){
      $(".dynamic").css("display", "");
      $(".static").css("display","none" );
    }else {
      $(".dynamic").css("display", "none");
      $(".static").css("display","" );
    }
    if ($("#wan-btn-obtdns").hasClass("button-on")){
      $(".dns").css("display", "none");
    } else {
      $(".dns").css("display", "");
    }
  });

  $(document).on("click", ".wan-save", function(){
    var buttonState = {
       "true" : "1",
       "false" : "0"
    };
    var ifnameflag =  editedRow.find(".ifname").val();
    var vlannameflag = editedRow.find(".vlanname").val();
    if (flagTable[ifnameflag]){
      ipv6 = flagTable[ifnameflag].ipv6
    }else if (flagTable[vlannameflag]){
       ipv6 = flagTable[vlannameflag].ipv6
    }else {
       ipv6 = ""
    }
    var dns = flagTable[ifnameflag] ? flagTable[ifnameflag].obtdns : flagTable[vlannameflag].obtdns;
    var auth = flagTable[ifnameflag] ? flagTable[ifnameflag].auth : flagTable[vlannameflag].auth;
    var commonButtonInfo = {
        "1" : {"idvalue"  : "wan-btn-ipv6",   "hiddenClass" : ".ipv6flag", "value" : ipv6 },
        "2" : { "idvalue" : "wan-btn-obtdns", "hiddenClass" : ".dnsflag",  "value" : dns == "" ? "1" : "0"},
        "3" : { "idvalue" : "wan-sel-authmethod", "hiddenClass" : ".authflag", "value": auth, "table": pppdvalue }
    }
    for (i =1 ; i<= 3 ; i++){
      if (i <= 2){
        if (buttonState[$("#"+commonButtonInfo[i].idvalue).hasClass("button-on")] == commonButtonInfo[i].value){
          editedRow.find(commonButtonInfo[i].hiddenClass).val("0");
        } else {
          editedRow.find(commonButtonInfo[i].hiddenClass).val("1");
        }
      } else {
        if (commonButtonInfo[i].table[$("#"+commonButtonInfo[i].idvalue).val()] == commonButtonInfo[i].value) {
          editedRow.find(commonButtonInfo[i].hiddenClass).val("0");
        } else {
          editedRow.find(commonButtonInfo[i].hiddenClass).val("1");
        }
      }
    }
    $(editedRow).closest(".table-row").attr("data-value","edit");
    editedRow.find(".proto").val($("#wan-sel-conntype").val());
    editedRow.find(".ipaddressmode").val($("#wan-sel-addmode").val());
    editedRow.find(".vpi_802priority").val($("#wan-txt-vpi").val());
    editedRow.find(".vci_vlanid").val($("#wan-txt-vci").val());
    var firewall = $("#wan-btn-firewall").hasClass("button-on") ? 1 : 0;
    editedRow.find(".firewall").val(firewall);
    var firewall = $("#wan-btn-ipv6").hasClass("button-on") ? 1 : 0;
    editedRow.find(".ipv6").val(firewall);
    var qos = $("#wan-btn-qos").hasClass("button-on") ? 1 : 0;
    editedRow.find(".qos").val(qos);
    qos == 1 ? editedRow.find(".table-qos").html('<span>'+T["Enabled"]+'</span>') : editedRow.find(".table-qos").html('<span>'+T["Disabled"]+'</span>')
    var nat = $("#wan-btn-nat").hasClass("button-on") ? 1 : 0;
    editedRow.find(".nat").val(nat);
    editedRow.find(".wanip").val(combineIP("wan-txt-ipaddress"));
    editedRow.find(".wansubnet").val(combineIP("wan-txt-subnet"));
    editedRow.find(".wangw").val(combineIP("wan-txt-gateway"));
    editedRow.find(".option12").val($("#wan-txt-option12").val());
    editedRow.find(".option60").val($("#wan-txt-option60").val());
    editedRow.find(".option61laid").val($("#wan-txt-option61laid").val());
    editedRow.find(".option61duid").val($("#wan-txt-option61duid").val());
    var option125 = $("#wan-btn-option125").hasClass("button-on") ? 1 : 0;
    editedRow.find(".option125").val(option125);
    var username = editedRow.find(".username").val($("#wan-txt-username").val());
    var password = editedRow.find(".password").val($("#wan-txt-password").val());
    var servicename = editedRow.find(".servname").val($("#wan-txt-servicename").val());
    var authValue = $("#wan-sel-authmethod").val();
    editedRow.find(".authmethod").val(authValue);
    var conntigger = $("#wan-sel-conntrigger").val() == "ondemand" ? 1 : 0
    editedRow.find(".conntigger").val(conntigger);
    editedRow.find(".lcpecho").val($("#wan-txt-lcp").val());
    editedRow.find(".mtu").val($("#wan-txt-mtu").val());
    var obtdns = $("#wan-btn-obtdns").hasClass("button-on") ? 1 : 0;
    editedRow.find(".obtdns").val(obtdns);
    editedRow.find(".primaryDNS").val(combineIP("wan-txt-pridns"));
    editedRow.find(".secondaryDNS").val(combineIP("wan-txt-secdns"));
  });

  $("#global-apply, #modal-apply").click(function(){
    var tableData = {} ;
    var updateData = [];
    var params = [];
    $(".table-row").each(function(){
      if ($(this).attr("data-value") == "edit"){
        updateData.push($(this).find('input[type="hidden"]').serializeArray());
      }else if (!$(this).hasClass("table-row-head") && !$(this).hasClass("table-row-last") && $(this).attr("data-value") == "autoChange"){
        var autoValue = $(this).find(".auto").val();
        var intf = $(this).find(".intf").val();
        updateData.push([{"auto" :autoValue, "intf" : intf, "change":"auto"}]);
      }
    });
    tableData["UPDATE"] = updateData;
    tableData = JSON.stringify(tableData);
    params.push({name: "tableRequest", value:tableData},{name: "CSRFtoken",value:$("meta[name=CSRFtoken]").attr("content") });
    postHandler("modals/settings/wan.lp", params, true);
  });

  $(".wan-button").click(function(){
    btn_on_off($(this));
  });

  $("#wan-btn-obtdns").click(function(){
      if ($(this).hasClass("button-on")){
        $(".dns").css("display", "none");
      } else {
        $(".dns").css("display", "");
      }
  });

  $(".auto-button").click(function(){
    if ( !$(this).closest(".table-row").attr("data-value")){
       $(this).closest(".table-row").attr("data-value","autoChange");
    }
    if ( $(this).hasClass("button-on")){
      $(this).removeClass("button-on").addClass("button-off");
      $(this).closest(".table-row").css("opacity", "0.4");
      $(this).closest(".table-row").find(".auto").val(0);
    }else{
      $(this).removeClass("button-off").addClass("button-on");
      $(this).closest(".table-row").css("opacity", "1");
      $(this).closest(".table-row").find(".auto").val(1);
    }
  })
});
