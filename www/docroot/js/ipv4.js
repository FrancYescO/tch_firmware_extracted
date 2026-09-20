var isDone = false;
var ipaddress;

$("#ipv4-btn-dhcpEnabled").click(function() {
  $(this).toggleClass('button-on button-off');
  $("#ipv4-info-dhcpparams").toggleClass('hide show');
});

$("#ipv4-btn-dnsProxy").click(function() {
  $(this).toggleClass('button-on button-off');
});

function assignIP(id_str, ip_addr,obj, divClass){
  var IPInputElementDiv =  obj.closest(".vdf-table").find(divClass)
  var splitIP = ip_addr.split(".");
  if (splitIP){
    IPInputElementDiv.find("input:eq(0)").val(splitIP[0]);
    IPInputElementDiv.find("input:eq(1)").val(splitIP[1]);
    IPInputElementDiv.find("input:eq(2)").val(splitIP[2]);
    IPInputElementDiv.find("input:eq(3)").val(splitIP[3]);
  }else{
    IPInputElementDiv.find("input:eq(0)").val("");
    IPInputElementDiv.find("input:eq(1)").val("");
    IPInputElementDiv.find("input:eq(2)").val("");
    IPInputElementDiv.find("input:eq(3)").val("");
  }
}

function assignMac(id_str, mac_addr, obj, divClass){
  var MACInputElementDiv = obj.closest(".vdf-table").find(divClass)
  if (mac_addr != ""){
    var splitMAC = mac_addr.split(":");
    if (splitMAC != "" ){
    MACInputElementDiv.find("input:eq(0)").val(splitMAC[0]);
    MACInputElementDiv.find("input:eq(1)").val(splitMAC[1]);
    MACInputElementDiv.find("input:eq(2)").val(splitMAC[2]);
    MACInputElementDiv.find("input:eq(3)").val(splitMAC[3]);
    MACInputElementDiv.find("input:eq(4)").val(splitMAC[4]);
    MACInputElementDiv.find("input:eq(5)").val(splitMAC[5]);
    }
  }else{
    MACInputElementDiv.find("input:eq(0)").val("");
    MACInputElementDiv.find("input:eq(1)").val("");
    MACInputElementDiv.find("input:eq(2)").val("");
    MACInputElementDiv.find("input:eq(3)").val("");
    MACInputElementDiv.find("input:eq(4)").val("");
    MACInputElementDiv.find("input:eq(5)").val("");
  }
}

function combineIP(id){
  var ip = [] ;
  for(var i=1; i<=4; i++)
  {
    ip[i-1] = $("#"+id+i).val();
    IPAddress = ip.join(".");
  }
  return IPAddress
}

function combineMAC(id){
  var mac = [] ;
  for(var i=1; i<=6; i++)
  {
    mac[i-1] = $("#"+id+i).val();
    MACAddress = mac.join(":");
  }
  return MACAddress
}

function splitIP(idString, IPAddress){
  var ipaddr = IPAddress.split(".");
  for(var i=1;i<=4;i++)
  {
    if (ipaddr != "" ){
      document.getElementById(idString+i).value = ipaddr[i-1];
    }else{
      document.getElementById(idString+i).value = "";
    }
  }
}

function splitMAC(idString, MACAddress){
  var macaddr = MACAddress.split(":");
  for(var i=1;i<=6;i++){
    if (macaddr != "" ){
      document.getElementById(idString+i).value = macaddr[i-1];
    }else{
      document.getElementById(idString+i).value = "";
    }
  }
}

function nameValidation(name){
  var length = name.length;
  if (length >= 0 && length <= 63 && (/^[a-zA-Z0-9.-]*$/g.test(name))){
    return true
  }
  return false
}

$('select option').filter(function() {
    return !this.value || $.trim(this.value).length == 0;
 }).remove();

function ipValidation(ip){
  var result = false;
  var ipaddr = ip.split(".");
  if (ipaddr != ""){
    for(var i=0;i<=3;i++){
      if (parseInt(ipaddr[i]) < 255 ){
        result = true
      }else{
        result = false
        break;
      }
    }
  }
  return result
}

function inRange(number){
  if (number > 1 && number < 255  ){
    return true
  }
  return false
}

function getStatus(target){
  $.get(target, function(responseTxt, statusTxt, xhr){
    if ( isDone || !(responseTxt.status != "") ){
      window.setTimeout(function(){
      window.location = "http://"+ipaddress;}, 5000);
      return;
    }else {
      window.setTimeout(function(){
      getStatus("modals/ipv4.lp?getstatus=true");}, 5000);
    }
  }).fail(function(data){
    isDone = true;
    window.setTimeout(function(){
    getStatus("http://"+ipaddress+"/login.lp?rb=1")}, 5000);
  });
}

var isIPChanged, ipstart, ipend, lanhostname, domainname;

function postHandle(target, params){
  if (typeof(Storage) !== "undefined"){
    // Save data to sessionStorage
    sessionStorage.setItem('apply_changes', "Y");
  }else {
    console.log("Sorry! No Web Storage support..");
  }
  //Seprate post, inorder to handle the post operation from expert mode pages.
  var expertParams = [];
  expertParams.push({
    name: "expert", value: true},{name: "CSRFtoken", value : $("[name=CSRFtoken]").val()
  });
   $.post("/home.lp", expertParams, function(reponseTxt, status, XHR){
          var elementValue = $("#expert").html();
          if (reponseTxt.status == "success"){
            $("#expert").html(elementValue+'<span>Some Expert Mode settings in use</span>')
          }else{
            $("#expert").html(elementValue);
          }
        });
  $.post(target, params, function(responseText, status, XHR){
    if (responseText.status == "success"){
      $(".articlediv > .msg-error").removeClass("show").addClass("hide");
      $(".articlediv > .msg-warning").removeClass("show").addClass("hide");
      $(".articlediv > .message-arrowbox-applied").removeClass("hide").addClass("show");
      function ipLengthCalc(ip){
        var ipaddr = ip.split(".");
        for(var i=1;i<=4;i++)
        {
          if (ipaddr[i-1].length <= 0 ){ return false}
        }
        return true
      }
      if (isIPChanged == "1" && ipstart != "" && ipend != "" && lanhostname != "" && domainname != "" && ipLengthCalc(ipaddress) == true ){
        $('#install-update-popup-5').modal();
        getStatus("/modals/ipv4.lp?getstatus=true");
      }
    }else if(responseText.status == "error"){
      $(".articlediv > .msg-error").removeClass("hide").addClass("show");
      $(".articlediv > .msg-warning").removeClass("show").addClass("hide");
      $(".articlediv > .message-arrowbox-applied").removeClass("show").addClass("hide");
      $("#clone-rec .device-mac-add").find("input").each(function(){$(this).prop("disabled", false);$(this).removeClass("op40");});
      $("#clone-rec .select-class-add").prop("disabled", false).trigger("chosen:updated");
    }
    $(".articlediv").removeClass("hide").addClass("show");
    setTimeout(function(){ $(".articlediv").removeClass("show").addClass("hide") }, 3000);
    if (isIPChanged != "1" && responseText.status == "success"){
      setTimeout(function(){  $("#content").load("/modals/ipv4.lp"); }, 500);
    }
  });
}

var elements = {
  hostName   : "#ipv4-txt-hstnme",
  domainName : "#ipv4-txt-domain",
  IPOctet    : "#ipv4Form .max3:not(.dns)",
  DNSIPOctet : "#ipv4Form #ipv4-div-dnsServer .max3",
  MACOctet   : "#ipv4Form .max2"
}

var validations = {
  hostName   : validateHostName,
  domainName : validateHostName,
  IPOctet    : validateNumberRange(0, 255),
  DNSIPOctet : function(value) {
    // Empty IP is also allowed.
    var count = 0;
    $(elements.DNSIPOctet).each(function() {
      if ($(this).val() == "") {
        ++count; // If an octet is empty, increment the counter
      }
    });
    return count == 4 || validateNumberRange(0, 255)(value); // If all 4 octets are empty, return true or validate the octet
  },
  MACOctet   : MACOctetRegExp
}
var popupElements = {
  IPOctet    : ".modal.in [id^=ipv4-txt-popupip]",
  MACOctet   : ".modal.in [id^=ipv4-txt-popupmac]",
  hostName   : ".modal.in #ipv4-txt-popupdevname:visible"
}


$(function() {
  $('select').chosen({
    disable_search_threshold: 100000,
    allow_single_deselect: true
  });
  splitIP("ipv4-txt-ipaddr",ipv4Content_IPAddress);
  splitIP("ipv4-txt-subntmsk",ipv4Content_localdevmask);
  $("#ipv4-txt-hstnme").val(ipv4Content_hostName);
  splitIP("ipv4-txt-ipstart",startIPAddress);
  splitIP("ipv4-txt-ipend", endIPAddress);
  $("#ipv4-txt-domain").val(ipv4Content_domainName);
  var delDHCPStaticList = [];
  var updateData = [];
  var ipField = {
    ipOctet:"#ipv4Form .max3:focus"
  }
  var ipValid = {
    ipOctet:validateNumberRange(0, 255)
  }
  $("#ipv4Form").on("blur", ".max3:not(.dns)", function() {
    if (!validateNumberRange(0, 255)($(this).val())) $(this).addClass('input-error');
    else $(this).removeClass('input-error');
  });
  $("#static-popup-add").on("blur", ".popup-ipaddress", function() {
    if (!validateNumberRange(0, 255)($(this).val())) $(this).addClass('input-error');
    else $(this).removeClass('input-error');
  });

  $("#global-apply").click(function(){
    if (!validateElements(elements, validations)) return false;
    $("#clone-rec .device-mac-add").find("input").each(function(){$(this).prop("disabled", true);$(this).addClass("op40");});
    $("#clone-rec .select-class-add").prop("disabled", true).trigger("chosen:updated");
    ipaddress = combineIP("ipv4-txt-ipaddr");
    subnetmask = combineIP("ipv4-txt-subntmsk");
    ipstart = $("#ipv4-txt-ipstart4").val();
    ipend = $("#ipv4-txt-ipend4").val();
    leasetime = $("#ipv4-sel-lease").children("option").filter(":selected").val();
    lanhostname = $("#ipv4-txt-hstnme").val();
    domainname =  $("#ipv4-txt-domain").val();
    var target = $("#ipv4Form").attr("action");
    var dhcpEnabled = $("#ipv4-btn-dhcpEnabled").hasClass("button-on") ? "" : "disabled";
    var params = [];
    var hostnameCheck = nameValidation(lanhostname);
    var domainnameCheck = nameValidation(domainname);
    var gatewayAddress = ipValidation(ipaddress) ;
    var startAddress = inRange(ipstart);
    var stopAddress = inRange(ipend);
    var DHCPStart = [];
    var DHCPEnd = [];
    $("[id^=ipv4-txt-ipstart]").each(function() {
      DHCPStart.push($(this).val());
    });
    DHCPStart = DHCPStart.join(".");
    $("[id^=ipv4-txt-ipend]").each(function() {
      DHCPEnd.push($(this).val());
    });
    DHCPEnd = DHCPEnd.join(".");
    if ( !hostnameCheck || !domainnameCheck || !gatewayAddress  || !startAddress || !stopAddress  ){
      $(".articlediv > .msg-error").removeClass("hide").addClass("show");
      $(".articlediv > .msg-warning").removeClass("show").addClass("hide");
      $(".articlediv > .message-arrowbox-applied").removeClass("show").addClass("hide");
      $(".articlediv").removeClass("hide").addClass("show");
      setTimeout(function(){ $(".articlediv").removeClass("show").addClass("hide") }, 3000);
      return false;
    }
    if (ipaddress != ipv4Content_IPAddress ){
      isIPChanged = "1";
    }else{ isIPChanged = "0"; }
    params.push({
      name  : "IPAddress",
      value : ipaddress
    },{
      name  : "IPStart",
      value : ipstart
    },{
      name  : "IPEnd",
      value : ipend
    },{
      name  : "DHCPStart",
      value : DHCPStart
    },{
      name  : "DHCPEnd",
      value : DHCPEnd
    },{
      name  : "leaseTime",
      value : leasetime
    },{
      name  : "dhcpEnabled",
      value : dhcpEnabled
    },{
      name  : "localdevmask",
      value : subnetmask
    },{
      name  : "hostName",
      value : lanhostname
    },{
      name  : "domainName",
      value : domainname
    },{
      name  : "isIPChanged",
      value :  isIPChanged
    },{
      name  : "action",
      value : "SAVE"
    });
    var tableData = {} ;
    var addData = [];

    $("tr").each(function(){
      if ($(this).attr("data-type")=="add"){
        var name = $(this).find("td:first").text();
        var mac =  $(this).find("td:eq(1)").text();
        var ip =  $(this).find("td:eq(2)").text();
        addData.push({"name":decodeURI(name),"mac":mac,"ip":ip});
      }
    });

     $("tr").each(function(){
      if ($(this).attr("data-type")=="edit"){
        var name = $(this).find("td:first").text();
        var mac = $(this).find("td:eq(1)").text();
        var ip = $(this).find("td:eq(2)").text();
        var index = $(this).find("td:eq(3) input").attr("data-value");
        updateData.push({"index":index,"name":decodeURI(name),"mac":mac,"ip":ip});
      }
    });

    var dnsServer = [];
    $("#ipv4-div-dnsServer .max3").each(function() {
      if ($(this).val() == "") {
        dnsServer = [];
        return false;
      }
      dnsServer.push($(this).val());
    });
    dnsServer = dnsServer.join(".");

    tableData["ADD"] = addData;
    tableData["UPDATE"] = updateData;
    tableData["DELETE"] = delDHCPStaticList;
    tableData = JSON.stringify(tableData);
    params.push({name: "tableRequest", value:tableData},{name: "CSRFtoken", value : $("[name=CSRFtoken]").val() });
    params.push({name: "dnsProxy", value: $("#ipv4-btn-dnsProxy").hasClass('button-on') ? "1" : "0"});
    params.push({name: "dnsServer", value: dnsServer});
    if  (isIPChanged == "1"){
      for(i in params){
        $('<input>').attr({
          type: 'hidden',
          name: params[i].name,
          value: params[i].value
        }).appendTo('#lanreboot');
      }
      $('#lanreboot').submit();
    }else{
      postHandle(target, params, "json");
    }
  });

  $("#ipv4-sel-popupcondev").change(function(){
    var macClass = ".popup-macaddress";
    var ipClass = ".popup-ipaddress";
    var self = $(this);
      $.each(deviceInfo, function(i, v) {
        if(v.mac == self.val()) {
        $("#new-device").removeAttr("style");
        $("#new-device").css("display","none");
          assignMac("ipv4-txt-popupmac", v.mac, self, macClass);
          assignIP("ipv4-txt-popupip", v.ip, self, ipClass);
        }
      });

    if ($(this).val() == "0"){
      $("#new-device").removeAttr("style");
      $("#new-device").css("display","table-row");
      assignIP("ipv4-txt-popupmac","",$(this), ipClass);
      assignMac("ipv4-txt-popupmac","",$(this), macClass);
    }
  });

  $("#ipv4-btn-addsave").click(function(){
    if (!validateElements(popupElements, validations)) return false;
    $("#static-popup-add").modal("hide");
    var deviceName = $("#ipv4-sel-popupcondev option:selected").text();
    if (deviceName == "No specific device"){
      deviceName = $("#ipv4-txt-popupdevname").val();
    }
    var MACAddress = combineMAC("ipv4-txt-popupmac");
    var IPAddress = combineIP("ipv4-txt-popupip");
    if ($("#static-popup-add").attr("data-value") == "edit"){
      if (($(editedRow).closest("tr").attr("data-type"))!="add"){
        $(editedRow).closest("tr").attr("data-type","edit");
      }
      var element = $(editedRow).closest("tr");
      element.find("td:first p").html(deviceName);
      element.find("td:eq(1)").html(MACAddress);
      element.find("td:eq(2)").html(IPAddress);
      var desIndex = $("#ipv4-tbl-staticdhcp .button-edit").index(this);
      var mobElement = $("#ipv4-tbl-mobilestaticdhcp .button-edit").eq(desIndex).closest(".mobile-display");
      mobElement.find(".mobile-devname").html(deviceName);
      mobElement.find(".mobile-devmac").html(MACAddress);
      mobElement.find(".mobile-devip").html(IPAddress);
    }else{
      $('<tr data-type="add">\
        <td>'+deviceName+'</td>\
        <td>'+MACAddress+'</td>\
        <td>'+IPAddress+'</td>\
        <td class="tR">\
        <input class="button button-edit triggering" value="" type="button" data-toggle="modal" data-target="#static-popup-add" id="ipv4-btn-edit" >\
        </td>\
        <td>\
        <input class="button button-delete" value="" type="button"  id = "ipv4-btn-del">\
        </td>\
        </tr>').insertBefore(".add-btn-port-triggering-wrapper");
      $('<div class="mobile-entry">\
        <div class="table-mobile-title">\
        <span>" + T["Device Name"] + "</span>\
        </div>\
        <div class="table-mobile-content">'+deviceName+'</div>\
        <div class="table-mobile-title">\
        <span>" + T["MAC Address"] + "</span>\
        </div>\
        <div class="table-mobile-content">\ '+MACAddress+'</div>\
        <div class="table-mobile-title">\
        <span>" + T["IP Address"] + "</span>\
        </div>\
        <div class="table-mobile-content">\ '+IPAddress+'</div>\
        <div class="btn-wrap">\
        <input class="button button-edit"  value="" type="button" id="ipv4-btn-mobedit">\
        <input class="button button-delete" value="" type="button" id="ipv4-btn-mobdel">\
        </div>\
        </div>').insertBefore(".mob-add");
    }
  });

  $("#ipv4-btn-add, #ipv4-btn-mobadd").click(function(){
    $("#ipv4-lbl-tittle").html("Add Static DHCP - Home Network");
    $("#ipv4-btn-addsave").val("Add");
    $("#ipv4-sel-popupcondev").val("0").trigger("chosen:updated");
    splitMAC("ipv4-txt-popupmac","");
    splitIP("ipv4-txt-popupip","");
    $("#ipv4-txt-popupdevname").val("");
    $("#new-device").removeAttr("style");
    $("#new-device").css("display","table-row");
    $("#ipv4-sel-popupcondev").prop("disabled", false).trigger("chosen:updated");
    $(".popup-macaddress").removeClass("disabled op40");
    if ($("#ipv4-sel-popupcondev").val() == "-1"){
        $(".popup-macaddress,.popup-ipaddress").find("input").prop("disabled",true);
        $(".popup-macaddress, .popup-ipaddress").find("input").addClass("op40");
     }
    $("#ipv4-sel-popupcondev").change(function(){
     if ($(this).val() != "-1"){
        $(".popup-macaddress,.popup-ipaddress").find("input").prop("disabled",false);
        $(".popup-macaddress, .popup-ipaddress").find("input").removeClass("op40");
     }
    });
    $("#static-popup-add .input-error").removeClass("input-error");
  });

  $("#ipv4-tbl-staticdhcp").on("click",".button-delete",function(){
    if ($(this).attr("data-value")){
      delDHCPStaticList.push($(this).attr("data-value"));
    }
    $(this).closest("tr").remove();
  });

  $("#ipv4-tbl-staticdhcp").on("click",".button-edit",function(){
    $("#ipv4-lbl-tittle").html("Edit Static DHCP - Home Network");
    $("#ipv4-btn-addsave").val("Save");
    $("#static-popup-add").attr("data-value","edit");
    editedRow = $(this);
    if (($(this).closest("tr").attr("data-type"))!="add"){
      $("#ipv4-sel-popupcondev").prop("disabled", true).trigger("chosen:updated");
      $(".popup-macaddress").addClass("disabled op40");
    }
    var element = $(this).closest("tr")
    var deviceName = element.find("td:first").text();
    var MACAddress = element.find("td:eq(1)").text();
    var IPAddress = element.find("td:eq(2)").text();
    var mac;
    var macFound = false;

      $.each(deviceInfo, function(i, v) {
        if(v.mac == MACAddress) {
        mac = v.mac;
        macFound = true;
        }
      });

      if (macFound == true ){
        $("#ipv4-sel-popupcondev").val(mac).trigger("chosen:updated");
        $("#new-device").removeAttr("style");
        $("#new-device").css("display","none");
      }else{
        $("#ipv4-sel-popupcondev").val("0").trigger("chosen:updated");
        $("#new-device").removeAttr("style");
        $("#new-device").css("display","table-row");
        $("#ipv4-txt-popupdevname").val(deviceName);
      }
      assignMac("ipv4-txt-popupmac", MACAddress, $("#ipv4-sel-popupcondev"), ".popup-macaddress");
      assignIP("ipv4-txt-popupip", IPAddress, $("#ipv4-sel-popupcondev"), ".popup-ipaddress");
  });

  $("#global-cancel").click(function(){
    sessionStorage.setItem('apply_changes', "Y");
    $("#content").load("/modals/ipv4.lp");
  });

  $("#ipv4-tbl-mobilestaticdhcp").on("click",".button-edit",function(){
    var thisIndex = $("#ipv4-tbl-mobilestaticdhcp .button-edit").index(this);
    $("#ipv4-tbl-staticdhcp .button-edit").eq(thisIndex).trigger("click");
  });

  $("#ipv4-btn-mobileclose").click(function(){
    $("#static-popup-add").modal("hide");
  });


  $("#ipv4-tbl-mobilestaticdhcp").on("click",".button-delete",function(){
    $(this).closest(".mobile-display").remove();
    var thisIndex = $("#ipv4-tbl-mobilestaticdhcp .button-delete").index(this);
    $("#ipv4-tbl-staticdhcp .button-delete").eq(thisIndex).trigger("click");
  });
});

$("#resetR, #resetR").click(function(){
  splitIP("ipv4-txt-ipaddr", resetLan.reset_ipaddress);
  splitIP("ipv4-txt-subntmsk", resetLan.reset_ipsubnet_mask);
  $('#ipv4-txt-hstnme').val(resetLan.reset_hostname);
  splitIP("ipv4-txt-ipstart", resetLan.reset_address_pool_startip);
  splitIP("ipv4-txt-ipend", resetLan.reset_address_pool_endip);
  splitIP("ipv4-txt-dns", resetLan.reset_localdnsserver);
  $("#ipv4-sel-lease").val(resetLan.reset_leasetime).trigger("chosen:updated");
  $("#ipv4-txt-domain").val(resetLan.reset_domainname);
  $('.button-delete').click();
  $("#ipv4-btn-dhcpEnabled").val(resetLan.reset_dhcpserver);
    if (resetLan.reset_dhcpserver == "1") {
      $("#ipv4-btn-dhcpEnabled").addClass('button-on').removeClass('button-off');
      $('#ipv4-info-dhcpparams').removeClass("hide").addClass("show");
    }
    else
    {
      $("#ipv4-btn-dhcpEnabled").addClass('button-off').removeClass('button-on');
      $('#ipv4-info-dhcpparams').removeClass("show").addClass("hide");
    }
  $("#ipv4-btn-dnsProxy").val(resetLan.reset_dnsproxy);
  if (resetLan.reset_dnsproxy == "1") {
    $("#ipv4-btn-dnsProxy").addClass('button-on').removeClass('button-off');
  }
  else
  {
    $("#ipv4-btn-dnsProxy").addClass('button-off').removeClass('button-on');
  }
});
