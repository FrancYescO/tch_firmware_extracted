  var selectedRow;
  var oldQoSObj = [];
  var OrderValue;
  var qosStatusChanged = 0;

  var elements = {
    name   : ".modal.in [id*=Name]",
    MAC    : ".modal.in [id*=MAC][id*=txt]",
  }
  var validations = {
    name   : function(value) { return value == "" || validateStringLength(1, 63)(value) },
    MAC    : function(value) { return value == "" || MACRegExp.test(value)},
  }

  var ports = {
    port   : ".modal.in [id*=Port]",
  }
  var portValidation = {
    port   : function(value) { return value === "" || validateNumberRange(1, 65535)(value) },
  }

  function validateIP(IPaddress)
  {
    return IPaddress === "" || (IPRegExp.test(IPaddress) && IPaddress !== "0.0.0.0")
  }

  function validatePorts(srcPort1, srcPort2, destPort1, destPort2, typeOfOperation)
  {
    var validSrcPorts = true;
    var validDestPorts = true;
    if (!validateElements(ports, portValidation)) return false;
    var getProtocol = $("#qos-sel-" + typeOfOperation + "IPProto :selected").text();

    // Validate ports only if protocol specified is TCP/UDP
    // For other protocols, ports will not be specified
    if (getProtocol === "TCP" || getProtocol === "UDP")
    {
      if (srcPort1 === "" && srcPort2 !== "")
      {
        $("#qos-txt-" + typeOfOperation + "SrcPort1").addClass('input-error');
        validSrcPorts = false;
      }
      else if (srcPort1 !== "" && srcPort2 === "")
      {
        $("#qos-txt-" + typeOfOperation + "SrcPort2").addClass('input-error');
        validSrcPorts = false;
      }
      else
      {
        srcPort1  = parseInt(srcPort1);
        srcPort2  = parseInt(srcPort2);
        if (srcPort1 !== "" && srcPort2 !== "")
        {
          if(srcPort1 === srcPort2)
          {
            $("#qos-txt-" + typeOfOperation + "SrcPort1, #qos-txt-" + typeOfOperation + "SrcPort2").removeClass('input-error');
            validSrcPorts = true;
          }
          else
          {
            (srcPort1 < 1 || 65535 < srcPort1) ? (validSrcPorts = false, $("#qos-txt-" + typeOfOperation + "SrcPort1").addClass('input-error')) : $("#qos-txt-" + typeOfOperation + "SrcPort1").removeClass('input-error');
            (srcPort2 < 1 || 65535 < srcPort2) ? (validSrcPorts = false, $("#qos-txt-" + typeOfOperation + "SrcPort2").addClass('input-error')) : $("#qos-txt-" + typeOfOperation + "SrcPort2").removeClass('input-error');
            if (validSrcPorts === true)
            {
              if (srcPort1 > srcPort2)
              {
                $("#qos-txt-" + typeOfOperation + "SrcPort1, #qos-txt-" + typeOfOperation + "SrcPort2").addClass('input-error');
                validSrcPorts = false;
              }
            }
          }
        }
      }
      if (destPort1 === "" && destPort2 !== "")
      {
        $("#qos-txt-" + typeOfOperation + "DestPort1").addClass('input-error');
        validDestPorts = false;
      }
      else if (destPort1 !== "" && destPort2 === "")
      {
        $("#qos-txt-" + typeOfOperation + "DestPort2").addClass('input-error');
        validDestPorts = false;
      }
      else
      {
        destPort1 = parseInt(destPort1);
        destPort2 = parseInt(destPort2);
        if (destPort1 !== "" && destPort2 !== "")
        {
          if (destPort1 === destPort2)
          {
            $("#qos-txt-" + typeOfOperation + "DestPort1, #qos-txt-" + typeOfOperation + "DestPort2").removeClass('input-error');
            validDestPorts = true;
          }
          else
          {
            (destPort1 < 1 || 65535 < destPort1) ? (validDestPorts = false, $("#qos-txt-" + typeOfOperation + "DestPort1").addClass('input-error')) : $("#qos-txt-" + typeOfOperation + "DestPort1").removeClass('input-error');
            (destPort2 < 1 || 65535 < destPort2) ? (validDestPorts = false, $("#qos-txt-" + typeOfOperation + "DestPort2").addClass('input-error')) : $("#qos-txt-" + typeOfOperation + "DestPort2").removeClass('input-error');
            if (validDestPorts === true)
            {
              if (destPort1 > destPort2)
              {
                $("#qos-txt-" + typeOfOperation + "DestPort1, #qos-txt-" + typeOfOperation + "DestPort2").addClass('input-error');
                validDestPorts = false;
              }
            }
          }
        }
      }
    }
    return validSrcPorts && validDestPorts;
  }

  function validateDSCP(dscpMark, dscpCheck, typeOfOperation, ruleType)
  {
    var valid = true;

    //Validate DSCPMark only if rule is of type rule
    if (ruleType === "rule" && typeOfOperation != "add")
    {
      if (dscpMark === "" || dscpMark < 0  || 63 < dscpMark)
      {
        $("#qos-txt-" + typeOfOperation + "DSCP").addClass("input-error");
        valid = false;
      }
    }
    if (dscpCheck === "" || dscpCheck < 0 || 63 < dscpCheck)
    {
      $("#qos-txt-" + typeOfOperation + "DSCPCheck").addClass("input-error");
      valid = false;
    }
    return valid;
  }

  function changeFields(typeOfOperation) {
    var typeSelectedIndex;
    if (typeOfOperation === "Adding")
      typeSelectedIndex = $("#qos-sel-addEthProto")[0].selectedIndex;
    else
      typeSelectedIndex = $("#qos-sel-editEthProto")[0].selectedIndex;
    switch (typeSelectedIndex) {
      case 0:
            if (typeOfOperation === "Adding")
            {
              $(".ethp2").show();
              $(".ethp3").show();
            }
            else
            {
              $(".editethp2").show();
              $(".editethp3").show();
            }
            break;
      case 1:
            if (typeOfOperation === "Adding")
            {
              $(".ethp2").hide();
              $(".ethp3").show();
              $(".portHideOnAdd").removeClass("show").addClass("hide");
            }
            else
            {
              $(".editethp2").hide();
              $(".editethp3").show();
              $(".portHideOnEdit").removeClass("show").addClass("hide");
            }
            break;
      case 2:
            if (typeOfOperation === "Adding")
            {
              $(".ethp2").hide();
              $(".ethp3").hide();
              $(".portHideOnAdd").removeClass("show").addClass("hide");
            }
            else
            {
              $(".editethp2").hide();
              $(".editethp3").hide();
              $(".portHideOnEdit").removeClass("show").addClass("hide");
            }
            break;
      case 3:
            if (typeOfOperation === "Adding")
            {
              $(".ethp2").hide();
              $(".ethp3").hide();
              $(".portHideOnAdd").removeClass("show").addClass("hide");
            }
            else
            {
              $(".editethp2").hide();
              $(".editethp3").hide();
              $(".portHideOnEdit").removeClass("show").addClass("hide");
            }
            break;
    }
     $("[role=dialog] .input-error").removeClass("input-error");
  }

  function isMacAddrEmpty(SourceMACAddress, SourceMACMask, DestMACAddress, DestMACMask, typeOfOperation) {
    valid = true;
    var invalidSrcMac = false;
    var invalidDestMac = false;
    if (SourceMACAddress.toLowerCase() === qtnMac)
    {
      $("#qos-txt-" + typeOfOperation + "SrcMAC").addClass('input-error');
      invalidSrcMac = true;
    }
    if (DestMACAddress.toLowerCase() === qtnMac)
    {
      $("#qos-txt-" + typeOfOperation + "DestMAC").addClass('input-error');
      invalidDestMac = true;
    }
    if (invalidSrcMac === true || invalidDestMac === true)
      return false;
    if (SourceMACMask.length != 0)
    {
      if (SourceMACAddress.length === 0)
      {
        $("#qos-txt-" + typeOfOperation + "SrcMAC").addClass('input-error');
        valid = false;
      }
      else
        $("#qos-txt-" + typeOfOperation + "SrcMAC").removeClass('input-error');
    }
    if (DestMACMask.length !== 0)
    {
      if (DestMACAddress.length === 0)
      {
        $("#qos-txt-" + typeOfOperation + "DestMAC").addClass('input-error');
        valid = false;
      }
      else
        $("#qos-txt-" + typeOfOperation + "DestMAC").removeClass('input-error');
    }
    return valid;
  }

  $(function() {
    $('select').chosen({
      disable_search_threshold: 100000,
      allow_single_deselect: true
    });
    $(".table-row").each(function(index) {
      oldQoSObj.push([]);
      $(this).find("input[type=hidden]").each(function(index1) {
        if ($(this).attr('name')) oldQoSObj[oldQoSObj.length-1].push($(this).val());
      });
    });
    if ($("#qos-table .qos-rule:visible").length == 0) {
      $(".no-rule").show();
    }
    else
    {
      $(".no-rule").hide();
    }
    $(".modal.in").modal("hide"); // Hide all visible popups
  });

  $("#qos-btn-status").click(function() {
    qosStatusChanged = 1;
    btn_on_off($(this));
    $("#qos-div-bw, #qos-table-details").slideToggle("slow");
    if ($(this).hasClass("button-on"))
    {
      (numberOfRules === "0" || $("#qos-table .qos-rule:visible").length === 0) ? $(".no-rule").show() : $(".no-rule").hide();
    }
  });

  $("#qos-table .button-edit").click(function() {
    copyData(this);
  });

  $("#qos-table").on("click", ".qosEnable", function() {
    var parentRow = $(this).closest('.table-row');
    var rowIndex = parentRow.find(".index");
    $(this).closest(".table-row").find(".Enable").val( $(this).hasClass("button-on") ? "0" : "1" );
    $(this).closest(".table-row").toggleClass("op40");
    $(this).toggleClass("button-on button-off");
    if ((rowIndex.val() != "new") && (rowIndex.val() != "l2classify") && (vdfVariant == "NZ")) {
      detectToggleChanges($(this));
    }
  });

  // When Add button is clicked, Clear all the previously entered entries
  $("#qos-btn-add").click(function() {
    $("div.modal #top-info-mode:last div.chosen-container ul.chosen-results").css("max-height","120px");
    $("[role=dialog] .input-error").removeClass("input-error");
    OrderValue = Number($("#qos-table-details .table-row").find(".RowNumber").last().text()) + 1;
    $("#addQosModal #qos-info-addOrder").text(OrderValue.toString());
    $(".l2classify").show();
    $(".ethp2").show();
    $(".ethp3").show();
    $(".portHideOnAdd").addClass("show");
    $(".dscpHideOnAdd").show();
    $("#addQosModal [type=text]").val("");
    $("#qos-sel-addInterface").val("").trigger("chosen:updated");
    $("#qos-sel-addEthProto").val("4").trigger("chosen:updated");
    $("#qos-sel-addIPProto").val("-1").trigger("chosen:updated");
    $("#qos-sel-addQueue").val("LOW_PRI").trigger("chosen:updated");
    $("#qos-sel-addMarkPriority").val("0").trigger("chosen:updated");
    $('#qos-exclude-add-protocol').removeAttr('checked');
    $('#qos-exclude-add-srcIP').removeAttr('checked');
    $('#qos-exclude-add-destIP').removeAttr('checked');
    $('#qos-exclude-add-srcMAC').removeAttr('checked');
    $("#qos-exclude-add-destMAC").removeAttr('checked');
    $('#qos-exclude-add-protocol').prop('checked','checked');
    $("#qos-exclude-add-srcIP").prop('checked','checked');
    $("#qos-exclude-add-destIP").prop('checked','checked');
    $("#qos-exclude-add-srcMAC").prop('checked','checked');
    $("#qos-exclude-add-destMAC").prop('checked','checked');
  });

  $("#qos-btn-editSave").click(function() {
    $("[role=dialog] .input-error").removeClass("input-error");
    if (!validateElements(elements, validations)) return false;
    var RuleType = $.trim(selectedRow.find(".RuleType").val());
    var DSCPCheck = $("#qos-txt-editDSCPCheck").val();
    var DSCPMark = $("#qos-txt-editDSCP").val();
    if (RuleType === "l2classify")
      DSCPMark = ""; // Make DSCPMark as empty for if rules are of type l2classify
    validEdit = true;
    var SrcPort1 = parseInt($("#qos-txt-editSrcPort1").val());
    var SrcPort2 = parseInt($("#qos-txt-editSrcPort2").val());
    var DestPort1 = parseInt($("#qos-txt-editDestPort1").val());
    var DestPort2 = parseInt($("#qos-txt-editDestPort2").val());
    var EthernetProtocol = $("#qos-sel-editEthProto").val();
    var Name = $("#qos-info-editName").val();
    var Interface = $("#qos-sel-editInterface").val();
    SrcPort1 = $("#qos-txt-editSrcPort1").val();
    SrcPort2 = $("#qos-txt-editSrcPort2").val();
    DestPort1 = $("#qos-txt-editDestPort1").val();
    DestPort2 = $("#qos-txt-editDestPort2").val();
    var ExcludeProtocol = $("#qos-exclude-protocol").is(":checked")?1:0;
    var IPProto = $("#qos-sel-editIPProto").val();
    var protocolText = $("#qos-sel-editIPProto :selected").text();
    var ExcludeSrcIP = $("#qos-exclude-srcIP").is(":checked")?1:0;
    var SrcIP = $("#qos-txt-editSrcIP").val();
    var PrefixLength = $("#qos-txt-editIPPrefixLength").val();
    var ExcludeDestIP = $("#qos-exclude-destIP").is(":checked")?1:0;
    var DestIP = $("#qos-txt-editDestIP").val();
    if (EthernetProtocol === "4")
    {
      if ((!(validateIP(SrcIP)) || (ExcludeSrcIP === 1 && SrcIP.length === 0 || reservedValues[SrcIP])))
      {
        $("#qos-txt-editSrcIP").addClass("input-error");
        validEdit = false;
      }
      if ((!(validateIP(DestIP)) || (ExcludeDestIP === 1 && DestIP.length === 0 || reservedValues[DestIP])))
      {
        $("#qos-txt-editDestIP").addClass("input-error");
        validEdit = false;
      }
    }
    var SubnetMask = $("#qos-txt-editIPSubnetMask").val();
    var SourceMACAddress = $("#qos-txt-editSrcMAC").val();
    var SourceMACMask = $("#qos-txt-editSrcMACMask").val();
    var SourceMACExclude = $("#qos-exclude-srcMAC").is(":checked")?1:0;
    var DestMACAddress = $("#qos-txt-editDestMAC").val();
    var DestMACMask = $("#qos-txt-editDestMACMask").val();
    var DestMACExclude = $("#qos-exclude-destMAC").is(":checked")?1:0;
    var MarkPriority = $("#qos-sel-editMarkPriority").val();
    var Queue = $("#qos-sel-editQueue").val();
    var QueueText = $("#qos-sel-editQueue :selected").text();
    var EthProtoText = $("#qos-sel-editEthProto :selected").text();
    var hidePort = false;
    var hideProtocol = false;
    var hidePriority = !($(".l2classify:visible").length === 0 || EthernetProtocol === "4" || EthernetProtocol == "802.1Q");

    if ($(".l2classify:visible").length > 0) {
      var type = $("#qos-sel-editEthProto")[0].selectedIndex;
      if (!(type == 0))
      {
        hideProtocol = true;
        hidePort = true;
        SrcIP = "";
        DestIP = "";
        SrcPort1 = "";
        SrcPort2 = "";
        DestPort1 = "";
        DestPort2 = "";
        SubnetMask = "";
        PrefixLength = "";
        IPProto = "-1";
      }
      else
      {
        if (EthernetProtocol === "4")
        {
          var listofProto = {"1" : "icmp", "6" : "tcp", "17" : "udp", "47" :"gre", "50" : "esp", "51" : "ah", "132" : "sctp", "136" : "udplite", "-1" : "all" };
          selectedRow.find(".EthernetProtocol").val(listofProto[IPProto])
        }
        if (SubnetMask.length === 0)
          SubnetMask = "255.255.255.255";
        if (PrefixLength.length === 0)
          PrefixLength = "255.255.255.255";
        if (!validatePorts(SrcPort1, SrcPort2, DestPort1, DestPort2, "edit"))
        {
          validEdit = false;
        }
      }
      if (!isMacAddrEmpty(SourceMACAddress, SourceMACMask, DestMACAddress, DestMACMask, "edit"))
      {
        validEdit = false;
      }
      if (SourceMACAddress.length === 0 & SourceMACMask.length === 0 & DestMACAddress.length === 0 & DestMACMask.length === 0)
        selectedRow.find(".RuleType").val("l2Toclassify");
    }
    else
    {
      if (SubnetMask.length === 0)
        SubnetMask = "255.255.255.255";
      if (PrefixLength.length === 0)
        PrefixLength = "255.255.255.255";
      if (!validatePorts(SrcPort1, SrcPort2, DestPort1, DestPort2, "edit"))
      {
        validEdit = false;
      }
    }
    if (!validateDSCP(DSCPMark, DSCPCheck, "edit", RuleType))
    {
      validEdit = false;
    }
    if (validEdit === false)
    {
      $(".input-error:first").focus();
      return false;
    }

    // Update all hidden fields
    selectedRow.find(".Name").val(Name);
    selectedRow.find(".Interface").val(Interface);
    selectedRow.find(".SourceIPExclude").val(ExcludeSrcIP);
    selectedRow.find(".SourceIP").val(SrcIP);
    selectedRow.find(".SourceMask").val(PrefixLength);
    selectedRow.find(".DestIPExclude").val(ExcludeDestIP);
    selectedRow.find(".DestIP").val(DestIP);
    selectedRow.find(".DestMask").val(SubnetMask);
    selectedRow.find(".DSCPMark").val(DSCPMark);
    selectedRow.find(".DSCPCheck").val(DSCPCheck);
    selectedRow.find(".EthernetPriorityCheck").val(MarkPriority);
    selectedRow.find(".Queue").val(Queue);
    selectedRow.find(".ProtocolExclude").val(ExcludeProtocol);
    if (protocolText === "TCP" || protocolText === "UDP")
    {
      selectedRow.find(".SourcePort1").val(SrcPort1)
      selectedRow.find(".SourcePort2").val(SrcPort2);
      selectedRow.find(".DestPort1").val(DestPort1);
      selectedRow.find(".DestPort2").val(DestPort2);
    }
    else
    {
      //For protocols other than TCP/UDP, ports are set to empty values
      SrcPort1 = "";
      SrcPort2 = "";
      DestPort1 = "";
      DestPort2 = "";
      selectedRow.find(".SourcePort1").val(SrcPort1);
      selectedRow.find(".SourcePort2").val(SrcPort2);
      selectedRow.find(".DestPort1").val(DestPort1);
      selectedRow.find(".DestPort2").val(DestPort2);
    }

    if ($(".l2classify:visible").length > 0) {
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
    if (SrcIP && !ExcludeSrcIP)
      replaceValue( selectedSourceIP, SrcIP );
    else
      selectedSourceIP.addClass("hide").removeClass("show");

    var selectedDestIP = selectedRow.find(".pr_DestIP");

    if (DestIP && !ExcludeDestIP)
      replaceValue( selectedDestIP, DestIP );
    else
      selectedDestIP.addClass("hide").removeClass("show");

    var selectedPrefixLength = selectedRow.find(".pr_SourceMask");
    var selectedDestMask = selectedRow.find(".pr_DestMask");

    if ((PrefixLength.length !== 0) & !ExcludeSrcIP)
      PrefixLength ? replaceValue( selectedPrefixLength, PrefixLength ) : selectedPrefixLength.addClass("hide").removeClass("show");
    else
      selectedPrefixLength.addClass("hide").removeClass("show");

    if ((SubnetMask.length !== 0) & !ExcludeDestIP)
      SubnetMask ? replaceValue( selectedDestMask, SubnetMask ) : selectedDestMask.addClass("hide").removeClass("show");
    else
      selectedDestMask.addClass("hide").removeClass("show");

    var selectedSourcePort = selectedRow.find(".pr_SourcePort");
    var selectedDestPort = selectedRow.find(".pr_DestPort");
    if (!hidePort)
    {
     var srcPort = SrcPort1 + "-" + SrcPort2;
      if ((/^\d+$/).test(SrcPort1)) {
        if ((/^\d+$/).test(SrcPort2)) {
          srcPort = SrcPort1 + "-" + SrcPort2;
        }
        else
        {
          srcPort = SrcPort1;
        }
        replaceValue( selectedSourcePort, srcPort )
      }
      else
      {
        selectedSourcePort.addClass("hide").removeClass("show");
      }

      var destPort = DestPort1 + "-" + DestPort2;
      if ((/^\d+$/).test(DestPort1)) {
        if ((/^\d+$/).test(DestPort2)) {
          destPort = DestPort1 + "-" + DestPort2;
        }
        else
        {
          destPort = DestPort1;
        }
        replaceValue( selectedDestPort, destPort )
      }
      else
      {
        selectedDestPort.addClass("hide").removeClass("show");
      }
    }
    else
    {
      selectedSourcePort.text("");
      selectedDestPort.text("");
    }
    var selectedProtocol = selectedRow.find(".pr_Protocol");
    (ExcludeProtocol || hideProtocol) ? selectedProtocol.addClass("hide").removeClass("show") : replaceValue( selectedProtocol, protocolText );

    if ($(".l2classify:visible").length > 0) {
      var SelectedSourceMACAddress = selectedRow.find(".pr_SourceMACAddress");
      var SelectedSourceMACMask = selectedRow.find(".pr_SourceMACMask");
      if (SourceMACAddress && !SourceMACExclude) {
        replaceValue( SelectedSourceMACAddress, SourceMACAddress );
        SourceMACMask ? replaceValue( SelectedSourceMACMask, SourceMACMask ) : SelectedSourceMACMask.addClass("hide").removeClass("show");
      }
      else {
        SelectedSourceMACAddress.addClass("hide").removeClass("show");
        SelectedSourceMACMask.addClass("hide").removeClass("show");
      }

      var SelectedDestMACAddress = selectedRow.find(".pr_DestMACAddress");
      var SelectedDestMACMask = selectedRow.find(".pr_DestMACMask");
      if (DestMACAddress && !DestMACExclude) {
        replaceValue( SelectedDestMACAddress, DestMACAddress );
        DestMACMask ? replaceValue( SelectedDestMACMask, DestMACMask ) : SelectedDestMACMask.addClass("hide").removeClass("show");
      }
      else {
        SelectedDestMACAddress.addClass("hide").removeClass("show");
        SelectedDestMACMask.addClass("hide").removeClass("show");
      }
      if (EthernetProtocol !== "4")
        selectedRow.find(".EthernetProtocol").val(EthernetProtocol)
      var selectedEthProto = selectedRow.find(".pr_EthernetProtocol");
      (EthernetProtocol !== "") ? replaceValue( selectedEthProto, EthProtoText ): selectedEthProto.addClass("hide").removeClass("show");
    }

    var selectedDSCPMark = selectedRow.find(".pr_DSCPMark");
    (DSCPMark && DSCPMark !== "-1") ? replaceValue( selectedDSCPMark, DSCPMark ) : selectedDSCPMark.addClass("hide").removeClass("show");

    var selectedDSCPCheck = selectedRow.find(".pr_DSCPCheck");
    (DSCPCheck && DSCPCheck !== "0") ? replaceValue( selectedDSCPCheck, DSCPCheck ) : selectedDSCPCheck.addClass("hide").removeClass("show");

    var selectedmark = selectedRow.find(".pr_EthernetPriorityCheck");
    (MarkPriority && !hidePriority) ? replaceValue( selectedmark, MarkPriority ) : selectedmark.addClass("hide").removeClass("show");

    var selectedQueue = selectedRow.find(".pr_Queue");
    replaceValue( selectedQueue, QueueText );
  });

  $("#qos-btn-addSave").click(function() {
    $(".no-rule").hide();
    $("[role=dialog] .input-error").removeClass("input-error");
    if (!validateElements(elements, validations))return false;
    validAdd = true;
    var Name = $("#qos-info-addName").val();
    var Interface = $("#qos-sel-addInterface").val();
    var SrcPort1 = $("#qos-txt-addSrcPort1").val();
    var SrcPort2 = $("#qos-txt-addSrcPort2").val();
    var DestPort1 = $("#qos-txt-addDestPort1").val();
    var DestPort2 = $("#qos-txt-addDestPort2").val();
    var ExcludeProtocol = $("#qos-exclude-add-protocol").is(":checked")?1:0;
    var IPProto = $("#qos-sel-addIPProto").val();
    var protocolText = $("#qos-sel-addIPProto :selected").text();
    var ExcludeSrcIP = $("#qos-exclude-add-srcIP").is(":checked")?1:0;
    var SrcIP = $("#qos-txt-addSrcIP").val();
    var PrefixLength = $("#qos-txt-addIPPrefixLength").val();
    var ExcludeDestIP = $("#qos-exclude-add-destIP").is(":checked")?1:0;
    var DestIP = $("#qos-txt-addDestIP").val();
    var EthernetProtocol = $("#qos-sel-addEthProto").val();

    if (EthernetProtocol === "4")
    {
      if ((!(validateIP(SrcIP)) || (ExcludeSrcIP === 1 && SrcIP.length === 0 || reservedValues[SrcIP])))
      {
        $("#qos-txt-addSrcIP").addClass("input-error");
        validAdd = false;
      }
      if ((!(validateIP(DestIP)) || (ExcludeDestIP === 1 && DestIP.length === 0 || reservedValues[DestIP])))
      {
        $("#qos-txt-addDestIP").addClass("input-error");
        validAdd = false;
      }
    }
    var SubnetMask = $("#qos-txt-addIPSubnetMask").val();
    var SourceMACAddress = $("#qos-txt-addSrcMAC").val();
    var SourceMACMask = $("#qos-txt-addSrcMACMask").val();
    var SourceMACExclude = $("#qos-exclude-add-srcMAC").is(":checked")?1:0;
    var DestMACAddress = $("#qos-txt-addDestMAC").val();
    var DestMACMask = $("#qos-txt-addDestMACMask").val();
    var DestMACExclude = $("#qos-exclude-add-destMAC").is(":checked")?1:0;
    var DSCPMark = $("#qos-txt-addDSCP").val() || "0";
    var DSCPCheck = $("#qos-txt-addDSCPCheck").val();
    var MarkPriority = $("#qos-sel-addMarkPriority").val();
    var Queue = $("#qos-sel-addQueue").val();
    var QueueText = $("#qos-sel-addQueue :selected").text();
    var EthProtoText = $("#qos-sel-addEthProto :selected").text();
    var type = $("#qos-sel-addEthProto")[0].selectedIndex;

    if (!isMacAddrEmpty(SourceMACAddress, SourceMACMask, DestMACAddress, DestMACMask, "add"))
    {
      validAdd = false;
    }
    var isRule = ((SourceMACAddress || DestMACAddress) ? "l2classify" : "rule");
    if (!validateDSCP(DSCPMark, DSCPCheck, "add", isRule))
    {
      validAdd = false;
    }
    var portSrcDest;
    function getPort(Port1, Port2) {
      if (Port1 && Port2)
      {
        portSrcDest = Port1 +"-"+ Port2;
      }
      else if(Port1)
      {
            portSrcDest = Port1;
      }
      else
      {
          portSrcDest = "";
      }
       return portSrcDest;
    }
    var EthProtocheck = false;
    var hideIp = false;
    var hidePriority = false;

    if(!(type == 0))
    {
      hideIp = true;
      SrcIP = "";
      DestIP = "";
      SrcPort1 = "";
      SrcPort2 = "";
      DestPort1 = "";
      DestPort2 = "";
      IPProto = "-1";
    }
    else
    {
      if (!validatePorts(SrcPort1, SrcPort2, DestPort1, DestPort2, "add"))
        validAdd = false;
    }
    if (validAdd === false)
    {
      $(".input-error:first").focus();
      return false;
    }

    if (!(protocolText === "TCP" || protocolText === "UDP"))
    {
      SrcPort1 = "";
      SrcPort2 = "";
      DestPort1 = "";
      DestPort2 = "";
    }
    var sourcePort =  getPort(SrcPort1, SrcPort2);
    var destinationPort = getPort(DestPort1, DestPort2);

    if (type === 2 || type === 3)
      hidePriority = true;

    if (SourceMACAddress || DestMACAddress)
      EthProtocheck = true;

    if (Interface.length === 0) //If user has selected No Interface, the value of this element will be empty
      Interface = "";

    if (PrefixLength.length === 0)
      PrefixLength = "255.255.255.255";
    if (SubnetMask.length === 0)
      SubnetMask = "255.255.255.255";

    $("<div class=\"table-row qos-rule new\">\
        <input type=\"hidden\" name=\"index\" class=\"index\" value=\"" + ((SourceMACAddress || DestMACAddress) ? "l2classify" : "new") + "\">\
        <input type=\"hidden\" name=\"Order\" class=\"Order\" value=\"" + OrderValue + "\">\
        <input type=\"hidden\" name=\"DSCPMark\" class=\"DSCPMark\" value=\"" + DSCPMark + "\">\
        <input type=\"hidden\" name=\"Interface\" class=\"Interface\" value=\"" + Interface + "\">\
        <input type=\"hidden\" name=\"EthernetProtocol\" class=\"EthernetProtocol\" value=\"" + EthernetProtocol + "\">\
        <input type=\"hidden\" name=\"ProtocolExclude\" class=\"ProtocolExclude\" value=\"" + ExcludeProtocol + "\">\
        <input type=\"hidden\" name=\"Protocol\" class=\"Protocol\" value=\""+ IPProto +"\">\
        <input type=\"hidden\" name=\"SourceIPExclude\" class=\"SourceIPExclude\" value=\"" + ExcludeSrcIP + "\">\
        <input type=\"hidden\" name=\"SourceIP\" class=\"SourceIP\" value=\"" + SrcIP + "\">\
        <input type=\"hidden\" name=\"SourceMask\" class=\"SourceMask\" value=\"" + PrefixLength + "\">\
        <input type=\"hidden\" name=\"DestIPExclude\" class=\"DestIPExclude\" value=\"" + ExcludeDestIP + "\">\
        <input type=\"hidden\" name=\"DestIP\" class=\"DestIP\" value=\"" + DestIP + "\">\
        <input type=\"hidden\" name=\"DestMask\" class=\"DestMask\" value=\"" + SubnetMask + "\">\
        <input type=\"hidden\" name=\"SourcePort1\" class=\"SourcePort1\" value=\"" + SrcPort1 + "\">\
        <input type=\"hidden\" name=\"SourcePort2\" class=\"SourcePort2\" value=\"" + SrcPort2 + "\">\
        <input type=\"hidden\" name=\"DestPort1\" class=\"DestPort1\" value=\"" + DestPort1 + "\">\
        <input type=\"hidden\" name=\"DestPort2\" class=\"DestPort2\" value=\"" + DestPort2 + "\">\
        <input type=\"hidden\" name=\"SourceMACAddress\" class=\"SourceMACAddress\" value=\"" + SourceMACAddress + "\">\
        <input type=\"hidden\" name=\"SourceMACMask\" class=\"SourceMACMask\" value=\"" + SourceMACMask + "\">\
        <input type=\"hidden\" name=\"SourceMACExclude\" class=\"SourceMACExclude\" value=\"" + SourceMACExclude + "\">\
        <input type=\"hidden\" name=\"DestMACAddress\" class=\"DestMACAddress\" value=\"" + DestMACAddress + "\">\
        <input type=\"hidden\" name=\"DestMACMask\" class=\"DestMACMask\" value=\"" + DestMACMask + "\">\
        <input type=\"hidden\" name=\"DestMACExclude\" class=\"DestMACExclude\" value=\"" + DestMACExclude + "\">\
        <input type=\"hidden\" name=\"DSCPCheck\" class=\"DSCPCheck\" value=\"" + DSCPCheck + "\">\
        <input type=\"hidden\" name=\"EthernetPriorityCheck\" class=\"EthernetPriorityCheck\" value=\"" + MarkPriority + "\">\
        <input type=\"hidden\" name=\"Name\" class=\"Name\" value=\"" + Name + "\">\
        <input type=\"hidden\" name=\"Queue\" class=\"Queue\" value=\"" + Queue + "\">\
        <input type=\"hidden\" name=\"Enable\" class=\"Enable\" value=\"1\">\
        <input type=\"hidden\" class=\"RuleType\" value=\"" + ((SourceMACAddress || DestMACAddress) ? "l2classify" : "rule") + "\">\
        <div class=\"table-col pr_Name\">" + Name + "</div>\
        <div class=\"table-col RowNumber\">" + OrderValue + "</div>\
        <div class=\"table-col\">\
          <span class=\"pr_Interface " + ((Interface.length !== 0) ? "show" : "hide") + "\">Interface: " + Interface + "</span>\
          <span class=\"pr_Protocol " + ((ExcludeProtocol || hideIp) ? "hide" : "show") + "\">IP Protocol: " + protocolText + "</span>\
          <span class=\"pr_EthernetProtocol " + (EthProtocheck ? "show" : "hide") + "\">Ethernet Protocol: " + EthProtoText + "</span>\
          <span class=\"pr_SourceIP " + ((ExcludeSrcIP || hideIp || SrcIP.length === 0) ? "hide" : "show") + "\">Source IP: " + SrcIP + "</span>\
          <span class=\"pr_SourceMask " + ((ExcludeSrcIP || hideIp) ? "hide" : "show") + "\">Prefix Length: " + PrefixLength + "</span>\
          <span class=\"pr_DestIP " + ((ExcludeDestIP || hideIp || DestIP.length === 0) ? "hide" : "show") + "\">Destination IP: " + DestIP + "</span>\
          <span class=\"pr_DestMask " + ((ExcludeDestIP || hideIp) ? "hide" : "show") + "\">Subnet Mask: " + SubnetMask + "</span>\
          <span class=\"pr_SourcePort " + (((sourcePort.length !== 0) && !hideIp) ?  "show" : "hide") + "\">Source Port: " + sourcePort + "</span>\
          <span class=\"pr_DestPort " + (((destinationPort.length !== 0) && !hideIp) ?  "show" : "hide") + "\">Destination Port: " + destinationPort + "</span>\
          <span class=\"pr_SourceMACAddress " + ((!SourceMACExclude && SourceMACAddress) ?  "show" : "hide") + "\">Source MACAddress: " + SourceMACAddress + "</span>\
          <span class=\"pr_SourceMACMask " + ((!SourceMACExclude && SourceMACAddress) ?  "show" : "hide") + "\">Source MACMask: " + SourceMACMask + "</span>\
          <span class=\"pr_DestMACAddress " + ((!DestMACExclude && DestMACAddress) ?  "show" : "hide") + "\">Dest MACAddress: " + DestMACAddress + "</span>\
          <span class=\"pr_DestMACMask " + ((!DestMACExclude  && DestMACAddress) ?  "show" : "hide") + "\">Dest MACMask: " + DestMACMask + "</span>\
          <span class=\"pr_DSCPCheck " + (DSCPCheck ? "show" : "hide") + "\">DSCP Check: " + DSCPCheck + "</span>\
        </div>\
        <div class=\"table-col\">\
          <span class=\"pr_Queue\">Queue: " + Queue + "</span>\
          <span class=\"pr_DSCPMark " + (DSCPMark ? "show" : "hide") + "\">DSCP: " +DSCPMark + "</span>\
          <span class=\"pr_EthernetPriorityCheck " + ((!hidePriority) ? "show" : "hide") + "\">Mark 802.1D Priority: " + MarkPriority + "</span>\
        </div>\
        <div class=\"table-col\">\
          <input class=\"button button-edit mapping\" type=\"button\" onclick=\"copyData(this)\" data-toggle=\"modal\" data-target=\"#editAccessControlModal\" id=\"qos-btn-edit" + OrderValue + "\">\
        </div>\
        <div class=\"table-col\">\
          <input class=\"button button-delete mapping\" type=\"button\" id=\"qos-btn-delete" + OrderValue + "\" />\
        </div>\
        <div class=\"table-col text-right\">\
          <div style=\"pointer-events:all\" class=\"button qosEnable button-on \" id=\"qos-btn-enable" + OrderValue + "\" type=\"button\"></div>\
        </div>\
      </div>").insertBefore("#qos-row-last");
  });

  function validateBW(bandwidth)
  {
    if (bandwidth !== "")
    {
      if(/^\d+$/.test(bandwidth) === false || Number(bandwidth) < 0 || 2147483647 < Number(bandwidth))
      {
        $("#qos-txt-bw").addClass('input-error');
        $(".input-error:first").focus();
        return false;
      }
    }
    return true;
  }

  var QoSPorts = [];
  $("#global-apply, #modal-apply").click(function() {
    if (!checkDuplicateQoSRules()) {
      return
    };
    var QoSObj = [];
    $("#qos-txt-bw").removeClass('input-error');
    var QoSState = $("#qos-btn-status").hasClass("button-on") ? "1" : "0";
    if (QoSState === "1")
    {
        var QoSBandwidth = $("#qos-txt-bw").val();
        if (!validateBW(QoSBandwidth)) return false;
        $("#global-apply").prop("disabled", true);
        $("#global-cancel").prop("disabled", true);
        $("#qos-table .table-row").each(function() {
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

          if (QoSObj[i][0] === "new" || QoSObj[i][0].indexOf('del') > -1 || QoSObj[i][0] === "l2classify" || QoSObj[i][28] === "l2Toclassify")
            isChanged = true;
          else if ( QoSObj[i][j] !== oldQoSObj[i][j]) {
            isChanged = true;
          }
          else {
            // The 28th element decides the type of rule(rule/l2classify)
            // The 2nd element decides the type of interface
            // The 4th element decides the type of EthernetProtocol
            if (!(j === 28 || j === 4 || j === 2))
              QoSObj[i][j] = null; // This value has not changed. No need to set this. So, Make it empty.
          }
        }
        if (QoSObj[i][28] !== "l2Toclassify")
        {
          if (QoSObj[i][0] === "new")
            QoSObj[i][28] = "rule";
          else if (QoSObj[i][0] === "l2classify" || QoSObj[i][28] === "l2classify")
            QoSObj[i][28] = "l2classify";
          else
            QoSObj[i][28] = "rule";
        }
        if (!isChanged) QoSObj[i][0] = "";
      }
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
    postObj.push({ name : "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content") });
    postObj.push({ name : "rows", value : QoSObj.length });
    postHandle("/modals/settings/qos.lp", postObj);
  });

  $("#global-cancel").click(function() {
    $("#content").load("/modals/settings/qos.lp");
  });

  $('#qos-table').on("click", ".button-delete", function() {
      var parentRow = $(this).closest('.table-row');
      var rowIndex = parentRow.find(".index");
      if (rowIndex.val() === "new" || rowIndex.val() === "l2classify") {
        if (vdfVariant == "NZ") {
          // To avoid navigation restriction when new unsaved rule is deleted
          sessionStorage.setItem("delete_bypass", "true");
        }
        parentRow.remove();
      }
      else
      {
        rowIndex.val("del" + rowIndex.val());
        parentRow.hide();
      }
      if ($("#qos-table .qos-rule:visible").length === 0) {
        $(".no-rule").show();
      }
      else
      {
        $(".no-rule").hide();
      }
  });

  function replaceValue(element, replacement) {
    element.addClass("show").removeClass("hide");
    var elementText = element.text();
    element.text(elementText.substring(0, elementText.indexOf(":")+2) + replacement);
  }

  function getDuplicates(arr) {
    var i, out=[], obj={};
    for (i=0; i < arr.length; i++)
      obj[arr[i]] == undefined ? obj[arr[i]] ++ : out.push(arr[i]);
    return out;
  }

  // Criteria for duplicate rules:
  // Rules that have same values for all below params are considered as duplicates
  // DSCPMark, Interface, Protocol, SourceIPExclude, SourceIP, SourceMask,
  // DestIPExclude, DestIP, DestMask, SourcePort1, SourcePort2, DestPort1,
  // DestPort2, DSCPCheck, EthernetPriorityCheck, Queue, Enable, RuleType
  function checkDuplicateQoSRules() {
    var excludedRules = [0, 18, 46]; // TODO: Some default rules are duplicates on thier own. This needs to be fixed in DM.
    var excludedParams = [
      "index",
      "Name",
      "Order",
      "EthernetProtocol", // below params are applicable only to l2classify which cannot be added through GUI
      "ProtocolExclude",
      "SourceMACAddress",
      "SourceMACMask",
      "SourceMACExclude",
      "DestMACAddress",
      "DestMACMask",
      "DestMACExclude"
    ];

    var qosRules = [];
    $("#qos-table .qos-rule:visible").each(function(index) {
      if (~excludedRules.indexOf(index)) {
        return true; // continue next iteration
      }
      qosRules.push({});
      $(this).find("input[type=hidden]").each(function() {
        var param = $(this).attr("class"),
            value = $(this).val();
        if (!~excludedParams.indexOf(param)) {
          qosRules[qosRules.length-1][param] = value;
        }
      });
      qosRules[qosRules.length-1] = JSON.stringify(qosRules[qosRules.length-1]);
    });

    if (getDuplicates(qosRules).length !== 0) {
      $(".articlediv > .msg-error").removeClass("hide").addClass("show");
      $(".articlediv > .msg-warning").removeClass("show").addClass("hide");
      $(".articlediv > .message-arrowbox-applied").removeClass("show").addClass("hide");
      $(".articlediv").addClass('show').removeClass('hide');
      setTimeout(function() {
        $(".articlediv").addClass('hide').removeClass('show');
      }, 3000)
      return false;
    }
    return true;
  }


  // Function to copy data from the row in which user clicked the edit button to Edit Pop-up
  // element is the edit button of the row in which user clicked the edit button
  function copyData(element) {
    $(".editethp2").show();
    $(".editethp3").show();
    $(".dscpHideOnEdit").show();
    $("[role=dialog] .input-error").removeClass("input-error");
    selectedRow = $(element).closest(".table-row");
    var index = $.trim(selectedRow.find(".index").val());
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
    var editedRowIndex = selectedRow.find("input[type=hidden]");
    var EthernetPriorityCheck = $.trim(selectedRow.find(".EthernetPriorityCheck").val());
    if ((vdfVariant == "NZ") && (editedRowIndex.val() === "new" || editedRowIndex.val() === "l2classify")) {
      // Used to restrict page navigation on selecting Cancel within a new rule that is edited
      sessionStorage.setItem("newRule_edit", "true");
    }
    if (EthernetPriorityCheck.length === 0)
      EthernetPriorityCheck = 0;
    var Queue = $.trim(selectedRow.find(".Queue").val());
    if (Queue.length === 0)
      Queue = "LOW_PRI";
    var EthernetProtocol = $.trim(selectedRow.find(".EthernetProtocol").val());
    var RuleType = $.trim(selectedRow.find(".RuleType").val());
    var SourceMACAddress = $.trim(selectedRow.find(".SourceMACAddress").val());
    var SourceMACMask = $.trim(selectedRow.find(".SourceMACMask").val());
    var SourceMACExclude = $.trim(selectedRow.find(".SourceMACExclude").val());
    var DestMACAddress = $.trim(selectedRow.find(".DestMACAddress").val());
    var DestMACMask = $.trim(selectedRow.find(".DestMACMask").val());
    var DestMACExclude = $.trim(selectedRow.find(".DestMACExclude").val());

    //Hiding DSCP Mark field of rule is of type rule/l2classify
    if (RuleType === "l2classify")
      $(".dscpHideOnEdit").hide();

    var listofProto = {"all": true, "icmp": true, "tcp": true, "udp": true, "gre": true, "esp": true, "ah": true, "sctp": true, "udplite": true, "4": true};

    if (RuleType === "l2classify" || index === "new") {
      if (!(listofProto[EthernetProtocol]))
        $(".editethp2").hide();
      if (EthernetProtocol === "97" || EthernetProtocol === "41")
        $(".editethp3").hide();
      if (listofProto[EthernetProtocol])
        EthernetProtocol = "4";
      $("#qos-sel-editEthProto").val(EthernetProtocol).trigger("chosen:updated");
      $("#qos-txt-editSrcMAC").val(SourceMACAddress);
      $("#qos-txt-editSrcMACMask").val(SourceMACMask);
      $("#qos-exclude-srcMAC").prop("checked", SourceMACExclude|0);
      $("#qos-txt-editDestMAC").val(DestMACAddress);
      $("#qos-txt-editDestMACMask").val(DestMACMask);
      $("#qos-exclude-destMAC").prop("checked", DestMACExclude|0);
      $(".l2classify").show();
    } else
    {
      $(".l2classify").hide();
    }
    $("#qos-info-editName").val(Name);
    $("#qos-info-editOrder").text(Order);
    if (Interface === "") {
      $("#qos-sel-editInterface option:first").prop("selected", true)
      $("#qos-sel-editInterface").trigger("chosen:updated")
    }
    else
    {
      $("#qos-sel-editInterface").val(Interface).trigger("chosen:updated");
    }
    $("#qos-sel-editIPProto").val(Protocol).trigger("chosen:updated");
    $("#qos-txt-editSrcIP").val(SourceIP);
    $("#qos-txt-editIPPrefixLength").val(PrefixLength);
    $("#qos-txt-editDestIP").val(DestIP);
    $("#qos-txt-editIPSubnetMask").val(DestMask);

    //Hiding port fields if protocol for this rule is other than TCP/UDP
    //For TCP, protocol value is 6 while for UDP it is 17
    if (Protocol === "6" || Protocol === "17")
    {
      $(".portHideOnEdit").addClass("show").removeClass("hide");
      $("#qos-txt-editSrcPort1").val(SourcePort1);
      $("#qos-txt-editSrcPort2").val(SourcePort2);
      $("#qos-txt-editDestPort1").val(DestPort1);
      $("#qos-txt-editDestPort2").val(DestPort2);
    }
    else
    {
      $(".portHideOnEdit").addClass("hide").removeClass("show");
    }
    $("#qos-txt-editDSCPCheck").val(DSCPCheck);
    $("#qos-txt-editDSCP").val(DSCPMark);
    $("#qos-sel-editMarkPriority").val(EthernetPriorityCheck).trigger("chosen:updated");
    $("#qos-sel-editQueue").val(Queue).trigger("chosen:updated");

    $("#qos-exclude-protocol").prop("checked", ProtocolExclude|0);
    $("#qos-exclude-srcIP").prop("checked", SourceIPExclude|0);
    $("#qos-exclude-destIP").prop("checked", DestIPExclude|0);
  }

  $("#qos-sel-editIPProto").change(function() {
    if($("#qos-sel-editIPProto :selected").text() === "TCP" || $("#qos-sel-editIPProto :selected").text() === "UDP")
    {
      $(".portHideOnEdit").addClass("show").removeClass("hide");
    }
    else
    {
      $(".portHideOnEdit").addClass("hide").removeClass("show");
    }
  });

  $("#qos-sel-addIPProto").change(function() {
    if($("#qos-sel-addIPProto :selected").text() === "TCP" || $("#qos-sel-addIPProto :selected").text() === "UDP")
    {
      $(".portHideOnAdd").addClass("show").removeClass("hide");
    }
    else
    {
      $(".portHideOnAdd").addClass("hide").removeClass("show");
    }
  });

/*Seperate function to handle post request for giving control to the page once the request(success/error) from server is obtained*/
/*This prevents the user from manipulating the page in between a post request*/
function postHandle(target, params) {
  applyCancelPopupHide();
  if (typeof(Storage) !== "undefined" && vdfVariant == "NZ") {
    // Save data to sessionStorage
    sessionStorage.setItem("user_interacted", "pristine");
  }
  $.post(target, params, function(responseText, status) {
    $("#qos-btn-add").prop("disabled",true);
    $(".editbutton").prop("disabled",true);
    $(".deletebutton").prop("disabled",true);
    $('.qosEnable').prop('disabled', true);
    if (responseText.status === "success") {
      $(".articlediv > .msg-error").removeClass("show").addClass("hide");
      $(".articlediv > .msg-warning").removeClass("show").addClass("hide");
      $(".articlediv > .message-arrowbox-applied").removeClass("hide").addClass("show");
    }
    else if (responseText.status === "error")
    {
      $(".articlediv > .msg-error").removeClass("hide").addClass("show");
      $(".articlediv > .msg-warning").removeClass("show").addClass("hide");
      $(".articlediv > .message-arrowbox-applied").removeClass("show").addClass("hide");
    }
    $(".articlediv").removeClass("hide").addClass("show");
    setTimeout(function() { $(".articlediv").removeClass("show").addClass("hide")}, 3000);
    if (responseText.status === "success") {
      setTimeout(function() {
      $("#content").load("/modals/settings/qos.lp");}, 3000);
    }
    else
    {
      $("#qos-btn-add").prop("disabled",false);
      $("#global-apply").prop("disabled", false);
      $("#global-cancel").prop("disabled", false);
      $(".editbutton").prop("disabled",false);
      $(".deletebutton").prop("disabled",false);
      $('.qosEnable').prop('disabled', false);
    }
  });
}
