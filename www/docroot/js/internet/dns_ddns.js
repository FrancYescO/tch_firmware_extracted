var resetPage = false;
var manualdns = 0;
$(function() {
  if (primaryDNS != "" )
  {
    $("input[name='dns-config']").filter('[value="2"]').prop("checked",true);
  }
  if ($("input[name='dns-config']").filter('[value="1"]').prop("checked")){
    $(".dnsContent").removeClass("show").addClass("hide");
     manualdns = 0;
  }else
  {
   $(".dnsContent").removeClass("hide").addClass("show");
    manualdns = 1;
  }
  $("input[name='dns-config']").change(function(){
  if ($(this).val() == "1") {
    $(".dnsContent").removeClass("show").addClass("hide");
    manualdns = 0;
  }else{
    $(".dnsContent").removeClass("hide").addClass("show");
    manualdns = 1;
  }
  });
  $('input,textarea').focus(function () {
    $(this).data('placeholder', $(this).attr('placeholder')).attr('placeholder', '');
  }).blur(function () {
    $(this).attr('placeholder', $(this).data('placeholder'));
  });

  if (ddnsservice.length == 0)
  {
    $("#dns-ddns-select-service option:first").prop("selected", true);
    $("#dns-ddns-select-service").trigger("chosen:updated");
  }
  else
  {
    $("#dns-ddns-select-service").val(ddnsservice).trigger("chosen:updated");
    $("#dns-ddns-select-service").trigger("chosen:updated");
  }
  document.getElementById("dns-ddns-txt-username").value = oldUsername;
  document.getElementById("dns-ddns-txt-domain").value = domain;

  $("#dns-ddns-select-service").change(function(){
    $(".ddns-input-field").each(function(){ $(this).val("");});
    $(".ddns-input-field").removeClass("input-length");
  });

  $("#dns-ddns-btn-ddns_enable").click(function() {
    if($(this).hasClass('button-on'))
    {
      $(this).removeClass('button-on');
      $(this).toggleClass('button-off');
      $(".ddns_account_details").slideUp("400");
    }
    else
    {
      $(this).removeClass('button-off');
      $(this).toggleClass('button-on');
      $(".ddns_account_details").slideDown("400");
    }
  });
  if ($("#ddns-btn-sdns").hasClass('button-on')) {
    $("#ddns-div-sdns").removeClass("show").addClass("hide");
  }  else {
    $("#ddns-div-sdns").removeClass("hide").addClass("show");
  }
  $("#ddns-btn-sdns").click(function(){
    if($(this).hasClass('button-on'))
    {
      $(this).removeClass('button-on');
      $(this).toggleClass('button-off');
      $("#ddns-div-sdns").removeClass("hide").addClass("show");
    }else
    {
      $(this).removeClass('button-off');
      $(this).toggleClass('button-on');
      $("#ddns-div-sdns").removeClass("show").addClass("hide");
    }
  });

  function combineDNSOctets(id) {
    var DNSAddress = [];
    $("[id^="+id+"]").each(function() {
      $(this).val() && DNSAddress.push($(this).val());
    });
    return DNSAddress.length == 4 ? DNSAddress.join(".") : "";
  }

  var elements = {
    primaryDNSOctet : "[id^=dns-txt-pridns]",
    secondaryDNSOctet : "[id^=dns-txt-secdns]"
  }

  var validations = {
    primaryDNSOctet : validateNumberRange(0, 255),
    secondaryDNSOctet : function(value) {
      if (value == "") {
        return true;
      }
      return validateNumberRange(0, 255)(value);
    }
  }

  $("#global-apply, #modal-apply").click(function() {
    if(manualdns == "1") {
      if(!validateElements(elements, validations))
      {
        return false;
      }
    }
    $(".ddns-input-field").removeClass("input-length");
    $(".articlediv, .articlediv > .msg-error").removeClass("show").addClass("hide");
    var iserror = false;
    var paramsForPost = [];
    var ddnsProvider, username, domainName, password;
    if ($("#dns-ddns-btn-ddns_enable").hasClass("button-on"))
    {
      ddnsSwitch = "1";
    }
    else
    {
      ddnsSwitch   = "0";
      username     = userName;
      domainName   = domainname;
      password     = passWord ;
      ddnsProvider = service;
    }
    var target = $("#dns-ddns-form").attr("action");
    if(!resetPage) {
    if (ddnsSwitch == "1")
    {
      ddnsProvider = document.getElementById("dns-ddns-select-service").value;
      username     = document.getElementById("dns-ddns-txt-username").value;
      domainName   = document.getElementById("dns-ddns-txt-domain").value;
      password     = document.getElementById("dns-ddns-txt-password").value;

      if (username || (oldUsername.length == 0 && username.length == 0))
      {
        if (!(password.length > 0 && password.length <=255))
        {
          $("#dns-ddns-txt-password").addClass("input-length");
           iserror = true;
        }
      }
      if (!(username.length > 0 && username.length <=255))
      {
        $("#dns-ddns-txt-username").addClass("input-length");
        iserror = true;
      }
      var domain = domainName.split(".");
      if (domainName.length > 0 && domainName.length <=255 && domain.length!=1)
      {
        var i = 0;
        while(i < domain.length)
        {
          if (domain[i].length > 1)
          {
            var correctLabel = domain[i].match("^[a-zA-z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9]");
            if (domain[i] != correctLabel || domain[i].length > 63)
            {
              $("#dns-ddns-txt-domain").addClass("input-length");
              return;
            }
          }
          else if(domain[i].length == 1)
          {
            if (domain[i].match("[a-zA-Z0-9]"))
            {
              $("#dns-ddns-txt-domain").addClass("input-length");
              return;
            }
          }
          else
          {
            $("#dns-ddns-txt-domain").addClass("input-length");
            return;
          }
          i=i+1;
        }
      }
      else
      {
        $("#dns-ddns-txt-domain").addClass("input-length");
        return;
      }
      if (iserror == true)
        return;
    }
    }
    else {
      ddnsSwitch   = $("#dns-ddns-btn-ddns_enable").val();
      username     = $("#dns-ddns-txt-username").val();
      domainName   = $("#dns-ddns-txt-domain").val();
      password     = $("#dns-ddns-txt-password").val();
      ddnsProvider = $("#dns-ddns-select-service").val();
    }
    var securednsstatus = $("#ddns-btn-sdns").hasClass("button-on") ? 1 : 0;
    paramsForPost.push({
      name : "ddnsStatus",
      value : ddnsSwitch
    },
    {
      name : "action",
      value : "SAVE"
    },
    {
      name : "CSRFtoken",
      value : CSRFvalue
    });
    if( ddnsSwitch == "1"){
      paramsForPost.push(
    {
      name: "ddnsService",
      value : ddnsProvider
    },
    {
      name: "ddnsDomain",
      value : domainName
    },
    {
      name: "ddnsUsrname",
      value : username
    },
    {
      name: "ddnsPswrd",
      value : password
    });
    };
    if (variant == "VF-UK"){
      paramsForPost.push({
        name : "manualdns",
        value: manualdns
      },
      {
        name : "primarydns",
        value : combineDNSOctets("dns-txt-pridns")
      },
      {
        name : "secondarydns",
        value : combineDNSOctets("dns-txt-secdns")
      });
    };
    if (variant != "VF-UK") {
      paramsForPost.push({
        name: "securedns",
        value : securednsstatus
      });
    };
    postHandler(target,paramsForPost,true);
  });
});
$("#resetR, .resetR").click(function() {
  resetPage = true;
  if (variant == "VF-UK")
    $("#dns-ddns-select-service").val("dtdns.com").trigger("chosen:updated");
  else
    $("#dns-ddns-select-service").val(ddnsprovider).trigger("chosen:updated");
  $("#dns-ddns-txt-domain").val(resetdomainname);
  $("#dns-ddns-txt-username").val(resetusername);
  $("#dns-ddns-txt-password").val(resetpassword );
  $("#dns-ddns-btn-ddns_enable").val(ddnsswitch);
  if (ddnsswitch == "1") {
    $('#dns-ddns-btn-ddns_enable').addClass('button-on').removeClass('button-off');
    $('.ddnsContent').show();
  }
  else
  {
    $('#dns-ddns-btn-ddns_enable').addClass('button-off').removeClass('button-on');
    $('.ddnsContent').hide();
  }
  if (primaryDNS != "") {
    $(".dnsContent").removeClass("show").addClass("hide");
    $("input[name='dns-config']").filter('[value="1"]').prop("checked",true)
    $(".secondarydns").val("");
    $(".primarydns").val("");
    manualdns = 0;
  }
  if(variant != "VF-UK" ){
    if (resetsecuredns == "1") {
      $("#ddns-btn-sdns").addClass('button-on').removeClass('button-off');
    }
    else
    {
      $("#ddns-btn-sdns").addClass('button-off').removeClass('button-on');
    }
  }
});
