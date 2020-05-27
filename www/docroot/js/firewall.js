(function() {
  //by disabling the add new rule button, we prevent that the user start adding a rule, before the adapted firewall level user is save
  //as this is a special case, we implement this here and not in actions.js
  $(document).on("change", '.modal select:not(.no-save):not(.disabled)', function() {
    $(".btn-table-new").addClass("disabled");
  });
  //Only for iinet
  if (sipAlg == 1) {
    $(document).on("change", '#fw_alg_sip_1', function() {
      $("#alert-sip-alg").removeClass("hide");
    });
  }

  //no need to display trafficType for ti and iinet
  if (trafficTypeValue == "true") {
    $("#fwrules tr > *:nth-child(2)").addClass("hide");
    $("#fwrules_v6 tr > *:nth-child(2)").addClass("hide");
  }
  //no need to display dscp for iinet
  if (dscpValue == "true") {
    $("#fwrules tr > *:nth-child(9)").addClass("hide");
    $("#fwrules_v6 tr > *:nth-child(9)").addClass("hide");
  }
}());

if(protocollist == "false") {
  var portLessProtocol = {};
  if(portLessProtocol[$("#protocol").val()]){
    $("#src_port, #dest_port").attr("readonly", "true");
  }

  if(portLessProtocol[$("#protocol_v6").val()]){
    $("#src_port_v6, #dest_port_v6").attr("readonly", "true");
  }

  $("#protocol, #protocol_v6").on("change", function(){
    if(portLessProtocol[this.value]){
      $("#src_port, #dest_port, #src_port_v6, #dest_port_v6").val("");
      $("#src_port, #dest_port, #src_port_v6, #dest_port_v6").attr("readonly", "true");
    }
else{
      $("#src_port, #dest_port").removeAttr("readonly");
      $("#src_port_v6, #dest_port_v6").removeAttr("readonly");
    }
  });
}

if ($("#src_port").val() == "custom") {
  $("#src_port").replaceWith($('<input/>',{'type':'text', 'name':'src_port','id' : 'src_port'}));
}
if ($("#dest_port").val() == "custom") {
  $("#dest_port").replaceWith($('<input/>',{'type':'text', 'name':'dest_port','id' : 'dest_port'}));
}
if ($("#src_ip").val() == "custom") {
  $("#src_ip").replaceWith($('<input/>',{'type':'text', 'name':'src_ip','id' : 'src_ip'}));
}
if ($("#dest_ip").val() == "custom") {
  $("#dest_ip").replaceWith($('<input/>',{'type':'text', 'name':'dest_ip','id' : 'dest_ip'}));
}

if ($("#src_port_v6").val() == "custom") {
  $("#src_port_v6").replaceWith($('<input/>',{'type':'text', 'name':'src_port_v6','id' : 'src_port_v6Input'}));
}
if ($("#dest_port_v6").val() == "custom") {
  $("#dest_port_v6").replaceWith($('<input/>',{'type':'text', 'name':'dest_ip_v6','id' : 'dest_ip_v6Input'}));
}
if ($("#src_ip_v6").val() == "custom") {
  $("#src_ip_v6").replaceWith($('<input/>',{'type':'text', 'name':'src_ip_v6','id' : 'src_ip_v6Input'}));
}
if ($("#dest_ip_v6").val() == "custom") {
  $("#dest_ip_v6").replaceWith($('<input/>',{'type':'text', 'name':'dest_ip_v6','id' : 'dest_ip_v6Input'}));
}

function portChange(portName,portId){
  $("[name = " + portName + "]").change(function () {
    if ((this.value) == "custom") {
      $(this).replaceWith($('<input/>',{'type':'text', 'name':portName,'id':portId }));
     }
  });
}

portChange('src_port','src_portInput')
portChange('src_ip','src_ipInput')
portChange('dest_port','dest_portInput')
portChange('dest_ip','dest_ipInput')
portChange('src_port_v6','src_port_v6Input')
portChange('dest_ip_v6','dest_ip_v6Input')
portChange('dest_port_v6','dest_port_v6Input')
portChange('src_ip_v6','src_ip_v6Input')
