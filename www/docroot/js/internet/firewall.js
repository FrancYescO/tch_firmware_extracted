  $(function() {
    $("#firewall-btn-onoff").click(function() {
      if ($(this).hasClass('button-off')) {
        $("#firewallStatus").val("1");
      } else {
        $("#firewallStatus").val("0");
      }
      $(this).toggleClass('button-on button-off');
    });

    $("#ping-btn-onoff").click(function() {
      if ($(this).hasClass('button-off')) {
        $("#pingStatus").val("1");
      } else {
        $("#pingStatus").val("0");
      }
      $(this).toggleClass('button-on button-off');
    });

    $("#global-apply, #modal-apply").click(function() {
      postHandler("/modals/internet/firewall.lp", $("#firewall_form").serializeArray());
    });
  });

  function changeButton(id, value, hiddenClass) {
    $(id).val(value);
    if (hiddenClass === "#pingStatus") {
      if (value === "0") {
        $(hiddenClass).val("0");
        $(id).addClass('button-off').removeClass('button-on');
      } else {
        $(hiddenClass).val("1");
        $(id).addClass('button-on').removeClass('button-off');
      }
    } else {
      if (value === "1") {
        $(hiddenClass).val("1");
        $(id).addClass('button-on').removeClass('button-off');
      } else {
      $(id).addClass('button-off').removeClass('button-on');
      $(hiddenClass).val("0");
      }
    }
  }
  $("#resetR, .resetR").click(function() {
    changeButton("#ping-btn-onoff", resetAllowPing, "#pingStatus");
    changeButton("#firewall-btn-onoff", resetFirewall, "#firewallStatus");
  });

