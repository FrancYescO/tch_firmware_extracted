  var selectedRow;
  var oldQoSObj = [];
  var qosStatusChanged = 0;

  var elements = {
    name   : ".modal.in #qos-info-editName",
    IP     : ".modal.in [id*=IP][id*=txt]:not([id*=sel])",
    MAC    : ".modal.in [id*=MAC][id*=txt]",
    port   : ".modal.in [id*=Port]"
  }
  var validations = {
    name   : function(value) { return value == "" || validateStringLength(1, 63)(value) },
    IP     : function(value) { return value == "" || IPRegExp.test(value) },
    MAC    : function(value) { return value == "" || MACRegExp.test(value) },
    port   : function(value) { return value == "" || validateNumberRange(1, 65535)(value) }
  }

  function validatePorts() {
    valid = true;
    var srcPort1  = parseInt($("#qos-txt-editSrcPort1").val());
    var srcPort2  = parseInt($("#qos-txt-editSrcPort2").val());
    var destPort1 = parseInt($("#qos-txt-editDestPort1").val());
    var destPort2 = parseInt($("#qos-txt-editDestPort2").val());
    if (!isNaN(srcPort2) && srcPort1 > srcPort2) {
      $("#qos-txt-editSrcPort1, #qos-txt-editSrcPort2").addClass('input-error');
      valid = false;
    } else $("#qos-txt-editSrcPort1, #qos-txt-editSrcPort2").removeClass('input-error');
    if (!isNaN(destPort2) && destPort1 > destPort2) {
      $("#qos-txt-editDestPort1, #qos-txt-editDestPort2").addClass('input-error');
      valid = false;
    } else $("#qos-txt-editDestPort1, #qos-txt-editDestPort2").removeClass('input-error');
    return valid;
  }

  $(function() {
    $('select').chosen({
      disable_search_threshold: 100000,
      allow_single_deselect: true
    });
    $(".table-row").each(function(index){
      oldQoSObj.push([]);
      $(this).find("input[type=hidden]").each(function(index1){
        if ($(this).attr('name')) oldQoSObj[oldQoSObj.length-1].push($(this).val());
      });
    });
    $("#footer-bg").next().remove(); // Remove opened popups if any, once page loads
  });

  $("#qos-btn-status").click(function() {
    qosStatusChanged = 1;
    $(this).toggleClass('button-on button-off');
    $("#qos-div-bw, #qos-table-details").slideToggle("slow");
  });

  $("#qos-table .button-edit").click(function() {
    copyData(this);
  });

  $("#qos-table").on("click", ".qosEnable", function() {
    $(this).closest(".table-row").find(".Enable").val( $(this).hasClass("button-on") ? "0" : "1" );
    $(this).closest(".table-row").toggleClass("op40");
    $(this).toggleClass("button-on button-off");
    //$(this).removeClass("op40");
  });

  $("#qos-btn-editSave").click(function() {
    if (!validateElements(elements, validations)) return false;
    if (!validatePorts()) return false;
    var Name = $("#qos-info-editName").val();
    var Interface = $("#qos-sel-editInterface").val();
    var ExcludeProtocol = $("#qos-exclude-protocol").is(":checked")?1:0;
    var IPProto = $("#qos-sel-editIPProto").val();
    var protocolText = $("#qos-sel-editIPProto :selected").text();
    var ExcludeSrcIP = $("#qos-exclude-srcIP").is(":checked")?1:0;
    var SrcIP = $("#qos-txt-editSrcIP").val();
    var PrefixLength = $("#qos-txt-editIPPrefixLength").val();
    var ExcludeDestIP = $("#qos-exclude-destIP").is(":checked")?1:0;
    var DestIP = $("#qos-txt-editDestIP").val();
    var SubnetMask = $("#qos-txt-editIPSubnetMask").val();
    var SrcPort1 = $("#qos-txt-editSrcPort1").val();
    var SrcPort2 = $("#qos-txt-editSrcPort2").val();
    var DestPort1 = $("#qos-txt-editDestPort1").val();
    var DestPort2 = $("#qos-txt-editDestPort2").val();
    var SourceMACAddress = $("#qos-txt-editSrcMAC").val();
    var SourceMACMask = $("#qos-txt-editSrcMACMask").val();
    var SourceMACExclude = $("#qos-exclude-srcMAC").is(":checked")?1:0;
    var DestMACAddress = $("#qos-txt-editDestMAC").val();
    var DestMACMask = $("#qos-txt-editDestMACMask").val();
    var DestMACExclude = $("#qos-exclude-destMAC").is(":checked")?1:0;
    var DSCPMark = $("#qos-txt-editDSCP").val();
    var DSCPCheck = $("#qos-txt-editDSCPCheck").val();
    var MarkPriority = $("#qos-sel-editMarkPriority").val();
    var Queue = $("#qos-sel-editQueue").val();
    var QueueText = $("#qos-sel-editQueue :selected").text();
    var EthernetProtocol = $("#qos-sel-editEthProto").val();

    // Update all hidden fields
    selectedRow.find(".Name").val(Name);
    selectedRow.find(".Interface").val(Interface);
    selectedRow.find(".SourceIPExclude").val(ExcludeSrcIP);
    selectedRow.find(".SourceIP").val(SrcIP);
    selectedRow.find(".SourceMask").val(PrefixLength);
    selectedRow.find(".DestIPExclude").val(ExcludeDestIP);
    selectedRow.find(".DestIP").val(DestIP);
    selectedRow.find(".DestMask").val(SubnetMask);
    selectedRow.find(".SourcePort1").val(SrcPort1)
    selectedRow.find(".SourcePort2").val(SrcPort2);
    selectedRow.find(".DestPort1").val(DestPort1);
    selectedRow.find(".DestPort2").val(DestPort2);
    selectedRow.find(".DSCPMark").val(DSCPMark);
    selectedRow.find(".DSCPCheck").val(DSCPCheck);
    selectedRow.find(".EthernetPriorityCheck").val(MarkPriority);
    selectedRow.find(".Queue").val(Queue);
    if ($(".l2classify:visible").length > 0) {
      selectedRow.find(".ProtocolExclude").val(ExcludeProtocol);
      selectedRow.find(".EthernetProtocol").val(EthernetProtocol);
      selectedRow.find(".SourceMACAddress").val(SourceMACAddress);
      selectedRow.find(".SourceMACMask").val(SourceMACMask);
      selectedRow.find(".SourceMACExclude").val(SourceMACExclude);
      selectedRow.find(".DestMACAddress").val(DestMACAddress);
      selectedRow.find(".DestMACMask").val(DestMACMask);
      selectedRow.find(".DestMACExclude").val(DestMACExclude);
    }

    // Update all columns
    selectedRow.find(".Protocol").val(IPProto);
    selectedName = selectedRow.find(".pr_Name").text(Name);

    var selectedInterface = selectedRow.find(".pr_Interface");
    Interface ? replaceValue( selectedInterface, Interface ) : selectedInterface.addClass("hide").removeClass("show");

    var selectedSourceIP = selectedRow.find(".pr_SourceIP");
    var selectedPrefixLength = selectedRow.find(".pr_SourceMask");
    if (SrcIP && !ExcludeSrcIP) {
      replaceValue( selectedSourceIP, SrcIP );
      PrefixLength ? replaceValue( selectedPrefixLength, PrefixLength ) : selectedPrefixLength.addClass("hide").removeClass("show");
    } else {
      selectedSourceIP.addClass("hide").removeClass("show");
      selectedPrefixLength.addClass("hide").removeClass("show");
    }

    var selectedDestIP = selectedRow.find(".pr_DestIP");
    var selectedDestMask = selectedRow.find(".pr_DestMask");
    if (DestIP && !ExcludeDestIP) {
      replaceValue( selectedDestIP, DestIP );
      SubnetMask ? replaceValue( selectedDestMask, SubnetMask ) : selectedDestMask.addClass("hide").removeClass("show");
    } else {
      selectedDestIP.addClass("hide").removeClass("show");
      selectedDestMask.addClass("hide").removeClass("show");
    }

    var selectedSourcePort = selectedRow.find(".pr_SourcePort");
    var srcPort = SrcPort1 + "-" + SrcPort2;
    if((/^\d+$/).test(SrcPort1)) {
      if((/^\d+$/).test(SrcPort2)) {
        srcPort = SrcPort1 + "-" + SrcPort2;
      } else {
        srcPort = SrcPort1;
      }
      replaceValue( selectedSourcePort, srcPort )
    } else {
      selectedSourcePort.addClass("hide").removeClass("show");
    }

    var selectedDestPort = selectedRow.find(".pr_DestPort");
    var destPort = DestPort1 + "-" + DestPort2;
    if((/^\d+$/).test(DestPort1)) {
      if((/^\d+$/).test(DestPort2)) {
        destPort = DestPort1 + "-" + DestPort2;
      } else {
        destPort = DestPort1;
      }
      replaceValue( selectedDestPort, destPort )
    } else {
      selectedDestPort.addClass("hide").removeClass("show");
    }
    var selectedProtocol = selectedRow.find(".pr_Protocol");
    protocolText ? replaceValue( selectedProtocol, protocolText ) : selectedProtocol.addClass("hide").removeClass("show");
    if ($(".l2classify:visible").length > 0) {
      var SelectedSourceMACAddress = selectedRow.find(".pr_SourceMACAddress");
      var SelectedSourceMACMask = selectedRow.find(".pr_SourceMACMask");
      if (SourceMACAddress && !SourceMACExclude) {
        replaceValue( SelectedSourceMACAddress, SourceMACAddress );
        SourceMACMask ? replaceValue( SelectedSourceMACMask, SourceMACMask ) : SelectedSourceMACMask.addClass("hide").removeClass("show");
      } else {
        SelectedSourceMACAddress.addClass("hide").removeClass("show");
        SelectedSourceMACMask.addClass("hide").removeClass("show");
      }

      var SelectedDestMACAddress = selectedRow.find(".pr_DestMACAddress");
      var SelectedDestMACMask = selectedRow.find(".pr_DestMACMask");
      if (DestMACAddress && !DestMACExclude) {
        replaceValue( SelectedDestMACAddress, DestMACAddress );
        DestMACMask ? replaceValue( SelectedDestMACMask, DestMACMask ) : SelectedDestMACMask.addClass("hide").removeClass("show");
      } else {
        SelectedDestMACAddress.addClass("hide").removeClass("show");
        SelectedDestMACMask.addClass("hide").removeClass("show");
      }

      var selectedEthProto = selectedRow.find(".pr_EthernetProtocol");
      EthernetProtocol ? replaceValue( selectedEthProto, EthernetProtocol ) : selectedEthProto.addClass("hide").removeClass("show");
    }

    var selectedDSCPMark = selectedRow.find(".pr_DSCPMark");
    (DSCPMark && DSCPMark != "-1") ? replaceValue( selectedDSCPMark, DSCPMark ) : selectedDSCPMark.addClass("hide").removeClass("show");

    var selectedDSCPCheck = selectedRow.find(".pr_DSCPCheck");
    (DSCPCheck && DSCPCheck != "0") ? replaceValue( selectedDSCPCheck, DSCPCheck ) : selectedDSCPCheck.addClass("hide").removeClass("show");

    var selectedmark = selectedRow.find(".pr_EthernetPriorityCheck");
    (MarkPriority && MarkPriority != "0") ? replaceValue( selectedmark, MarkPriority ) : selectedmark.addClass("hide").removeClass("show");

    var selectedQueue = selectedRow.find(".pr_Queue");
    replaceValue( selectedQueue, QueueText );

  });

  var QoSPorts = [];

  $("#global-apply").click(function() {
    var QoSObj = [];
    $(".table-row").each(function() {
      QoSObj.push([]);
      QoSPorts.push([]);
      $(this).find("input[type=hidden][name]").each(function(index) {
        QoSObj[QoSObj.length-1].push($(this).val());
        if (index >= 13 && index <= 16)  // Hidden feilds for Ports
          QoSPorts[QoSPorts.length-1].push($(this).val());
      });
    });

    // Check whether a row has changed or not
    for ( var i = 0; i < QoSObj.length; i++ ) {
      var isChanged = false;
      for ( var j = 1; j < QoSObj[i].length; j++ ) {
        if ( QoSObj[i][j] != oldQoSObj[i][j] ) {
          isChanged = true;
        } else {
          QoSObj[i][j] = null; // This value has not changed. No need to set this. So, Make it empty.
        }
      }
      if (!isChanged) QoSObj[i][0] = "" // No changes in this row. So, remove it's index.
    }
    var postObj = [];
     if (qosStatusChanged == 1)
    {
      postObj.push({ name : "QoSStatus", value : $("#qos-btn-status").hasClass("button-on") ? "1" : "0" });
      qosStatusChanged = 0;
    }
    postObj.push({ name : "QoSBW", value : $("#qos-txt-bw").val() });
    postObj.push({ name : "QoSTable", value : JSON.stringify(QoSObj) });
    postObj.push({ name : "QoSPorts", value : JSON.stringify(QoSPorts) });
    postObj.push({ name : "CSRFtoken", value : $("[name=CSRFtoken]").val() });
    postObj.push({ name : "rows", value : QoSObj.length });
    postHandler("/modals/qos.lp", postObj, true);
  });

  $("#global-cancel").click(function() {
    $("#content").load("/modals/qos.lp");
  });

  function replaceValue(element, replacement) {
    element.addClass("show").removeClass("hide");
    var elementText = element.text();
    element.text(elementText.substring(0, elementText.indexOf(":")+2) + replacement);
  }

  // Function to copy data from the row in which user clicked the edit button to Edit Pop-up
  // element is the edit button of the row in which user clicked the edit button
  function copyData(element) {
    $("[role=dialog] .input-error").removeClass("input-error");
    selectedRow = $(element).closest(".table-row");
    var Name = $.trim(selectedRow.find(".Name").val());
    var Order = $.trim(selectedRow.find(".Order").val());
    var Interface = $.trim(selectedRow.find(".Interface").val());
    var ProtocolExclude = $.trim(selectedRow.find(".ProtocolExclude").val());
    var Protocol = $.trim(selectedRow.find(".Protocol").val());
    var SourceIPExclude = $.trim(selectedRow.find(".SourceIPExclude").val());
    var SourceIP = $.trim(selectedRow.find(".SourceIP").val());
    var PrefixLength = $.trim(selectedRow.find(".SourceMask").val());
    var DestIPExclude = $.trim(selectedRow.find(".DestIPExclude").val());
    var DestIP = $.trim(selectedRow.find(".DestIP").val());
    var DestMask = $.trim(selectedRow.find(".DestMask").val());
    var SourcePort1 = $.trim(selectedRow.find(".SourcePort1").val());
    var SourcePort2 = $.trim(selectedRow.find(".SourcePort2").val());
    var DestPort1 = $.trim(selectedRow.find(".DestPort1").val());
    var DestPort2 = $.trim(selectedRow.find(".DestPort2").val());
    var DSCPCheck = $.trim(selectedRow.find(".DSCPCheck").val());
    var DSCPMark = $.trim(selectedRow.find(".DSCPMark").val());
    var EthernetPriorityCheck = $.trim(selectedRow.find(".EthernetPriorityCheck").val());
    var Queue = $.trim(selectedRow.find(".Queue").val());
    var EthernetProtocol = $.trim(selectedRow.find(".EthernetProtocol").val());
    var RuleType = $.trim(selectedRow.find(".RuleType").val());
    var SourceMACAddress = $.trim(selectedRow.find(".SourceMACAddress").val());
    var SourceMACMask = $.trim(selectedRow.find(".SourceMACMask").val());
    var SourceMACExclude = $.trim(selectedRow.find(".SourceMACExclude").val());
    var DestMACAddress = $.trim(selectedRow.find(".DestMACAddress").val());
    var DestMACMask = $.trim(selectedRow.find(".DestMACMask").val());
    var DestMACExclude = $.trim(selectedRow.find(".DestMACExclude").val());

    if (RuleType == "l2classify") {
      $("#qos-exclude-protocol").prop("checked", ProtocolExclude|0);
      $("#qos-txt-editSrcMAC").val(SourceMACAddress);
      $("#qos-txt-editSrcMACMask").val(SourceMACMask);
      $("#qos-exclude-srcMAC").prop("checked", SourceMACExclude|0);
      $("#qos-txt-editDestMAC").val(DestMACAddress);
      $("#qos-txt-editDestMACMask").val(DestMACMask);
      $("#qos-exclude-destMAC").prop("checked", DestMACExclude|0);
      $("#qos-sel-editEthProto").val(EthernetProtocol).trigger("chosen:updated");
      $(".l2classify").show();
    } else {
      $(".l2classify").hide();
    }

    $("#qos-info-editName").val(Name);
    $("#qos-info-editOrder").text(Order);
    if (Interface == "") {
      $("#qos-sel-editInterface option:first").prop("selected", true)
      $("#qos-sel-editInterface").trigger("chosen:updated")
    } else {
      $("#qos-sel-editInterface").val(Interface).trigger("chosen:updated");
    }
    $("#qos-sel-editIPProto").val(Protocol).trigger("chosen:updated");
    $("#qos-txt-editSrcIP").val(SourceIP);
    $("#qos-txt-editIPPrefixLength").val(PrefixLength);
    $("#qos-txt-editDestIP").val(DestIP);
    $("#qos-txt-editIPSubnetMask").val(DestMask);

    $("#qos-txt-editSrcPort1").val(SourcePort1);
    $("#qos-txt-editSrcPort2").val(SourcePort2);
    $("#qos-txt-editDestPort1").val(DestPort1);
    $("#qos-txt-editDestPort2").val(DestPort2);

    $("#qos-txt-editDSCPCheck").val(DSCPCheck);
    $("#qos-txt-editDSCP").val(DSCPMark);
    $("#qos-sel-editMarkPriority").val(EthernetPriorityCheck).trigger("chosen:updated");
    $("#qos-sel-editQueue").val(Queue).trigger("chosen:updated");

    $("#qos-exclude-protocol").prop("checked", ProtocolExclude|0);
    $("#qos-exclude-srcIP").prop("checked", SourceIPExclude|0);
    $("#qos-exclude-destIP").prop("checked", DestIPExclude|0);
  }
