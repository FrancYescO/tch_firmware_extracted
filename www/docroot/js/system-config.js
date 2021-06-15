  var schedule_time = "";
  var refreshTimeOut = 5000;
  var target = $(".modal form").attr("action");
  var valeur = 2;
  function resetReboot(msg, msg_dst, action) {
    msg_dst.after(msg);
    msg.removeClass("hide");
    msg[0].scrollIntoView();
    $.post(
      target,
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
      wait_for_webserver_down(action),
      "json"
    );
    return false;
  }

  function resetrtfd(msg, process_bar, action) {
    msg.removeClass("hide");
    process_bar.removeClass("hide");
    $('.bar').css('width', valeur+'%').attr('aria-valuenow', valeur);
    msg[0].scrollIntoView();
    $.post(
      target,
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
      wait_for_webserver_down,
      "json"
    );
    return false;
  }

  $("#btn-system-bootp").click(function() {
    confirmationDialogue(T["lanUpgradeMsg"], T["lanUpgrade"]);
    $(document).on("click", ".LAN", function() {
      tch.removeProgress();
      tch.showProgress(T["reboot"]);
      return resetReboot($("#bootp-msg"), $(this), "system_bootp");
    });
  });

  $("#btn-system-reboot").click(function() {
    if (resetrtfdValue == "true") {
      return resetrtfd($("#rebooting-msg"), $(this), "system_reboot" );
    }
    confirmationDialogue(T["confirmmsg"], T["restartDev"]);
    $(document).on("click", ".Restart", function() {
      tch.removeProgress();
      tch.showProgress(T["reboot"]);
      return resetReboot($("#rebooting-msg"), $(this), "system_reboot" );
    });
  });

  $("#btn-schedule-reboot").click(function() {
    var _date = $("#date_schedule").val();
    var _time = $("#time_schedule").val();
    schedule_time = $("#date_schedule").val()+"T"+$("#time_schedule").val()+":00Z" ;
    var temp = system_time;
    var timeformat = temp.split(" ");
    temp = timeformat[0]+"T"+timeformat[1]+"Z";
    if ((( _date && _time) != "") &&( temp < schedule_time))
    {
      $('#schedule-failed-msg, #date_schedule, #time_schedule, #btn-schedule-reboot').addClass("hide");
      $(".schedule_message_get").removeClass("hide");
      $.post(
        target,
        { action: "schedulerebootset", CSRFtoken: $("meta[name=CSRFtoken]").attr("content"), paramvalue :schedule_time }, wait_for_webserver_down, "json");
    }
    else
    {
      $("#schedule-failed-msg").removeClass("hide");
    }
  });

  $("#btn-system-reset").click(function() {
    if (resetrtfdValue == "true") {
      return resetrtfd($("#resetting-msg"), $(this), "system_reset");
    }
    confirmationDialogue(T["confirmmsg"], T["factoryDefaults"]);
    $(document).on("click", ".Factory", function() {
      tch.removeProgress();
      tch.showProgress(T["resetting"]);
      return resetReboot($("#resetting-msg"), $(this), "system_reset");
    });
  });

  if (schedule_reboot_get == "1") {
    $('#date_schedule, #time_schedule, #btn-schedule-reboot').addClass("hide");
    $(".schedule_message_get").removeClass("hide");
  }

  $(document).on("click", "#cancel", function() {
    tch.removeProgress();
  });

  $(".export-config").click(function() {
    $.fileDownload(target, {
      httpMethod: "POST",
      data: new Array({ name : "action", value : "export_config" },
                      { name : "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content") }),
      prepareCallback: function() {
        $("#export-failed-msg").addClass("hide");
        var exporting_msg = $("#exporting-msg");
        exporting_msg.removeClass("hide");
        exporting_msg[0].scrollIntoView();
      },
      successCallback: function() {
        $("#exporting-msg").addClass("hide");
      },
      failCallback: function() {
        var export_failed_msg = $("#export-failed-msg");
        export_failed_msg.removeClass("hide");
        export_failed_msg[0].scrollIntoView();
        $("#exporting-msg").addClass("hide");
      }
    });
    return false;
  });

  $(".import-config").click(function() {
    $('#import-nofile-msg, #import-failed-msg, #import-wrong-ext-msg, #import-too-big-msg').addClass("hide");
    var nofile_msg = $("#import-nofile-msg");
    var wrongext_msg = $("#import-wrong-ext-msg");
    var toobig_msg = $("#import-too-big-msg");
    if ($("#file-import").val() == "") {
      nofile_msg.removeClass("hide");
      nofile_msg[0].scrollIntoView();
      return false;
    }
    nofile_msg.addClass("hide");

    var validExtensions = ['bin'];
    var fileName = $("#file-import").val();
    var fileNameExt = fileName.substr(fileName.lastIndexOf('.') + 1);
    if ($.inArray(fileNameExt, validExtensions) == -1){
        wrongext_msg.removeClass("hide");
	wrongext_msg[0].scrollIntoView();
	return false;
    }
    var fileSize = $("#file-import")[0].files[0].size;
    // Imported config file size should be more than 1MB
    if (fileSize > 1048576) {
      toobig_msg.removeClass("hide");
      toobig_msg[0].scrollIntoView();
      return false;
    }

    var _this = $(this).parents(".control-group");
    $("#import-failed-msg").addClass("hide");
    var importing_msg = $("#importing-msg");
    importing_msg.removeClass("hide");
    importing_msg[0].scrollIntoView();
    $.fileUpload($("#form-import"), {
      params: { CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
      completeCallback: function(form, response) {
        $("#importing-msg").addClass("hide");
        if (response.success) {
          var msg = $("#rebooting-msg");
          var msg_dst = $(_this);
          msg_dst.after(msg);
          msg.removeClass("hide");
          msg[0].scrollIntoView();
          wait_for_webserver_down("import_config");
        }
        else {
          $("#import-failed-msg").removeClass("hide");
        }
      }
    });
    return false;
  });

  // Do not use the default values.
  // On low memory boards sysupgrade use all resources.
  // Do not request too often an upgradefwstatus.
  // It takes more than 5 sec to check if sysupgrade is running.
  // Sysupgrade is running for at least 10 sec.
  function wait_for_upgradefw() {
    var upgrfw_refreshTimeOut = 15000;
    var upgrfw_refreshDelay = 10000;
    var msg = $("#upgrade-busy-msg");
    var msg_dst = $(this);
    msg_dst.after(msg);
    msg.removeClass("hide");
    msg[0].scrollIntoView();
    function waitForShutdownOrError() {
      $.ajax({ url: target, data: "action=upgradefwstatus", timeout: upgrfw_refreshTimeOut, dataType: "json" })
      .done(function(data) {
        if (data.success == "true") {
          window.setTimeout(waitForShutdownOrError, upgrfw_refreshDelay);
        }
        else {
          msg.addClass("hide");
          var failure_msg = $("#upgrade-failed-msg");
          switch (data.errorcode) {
          case "1":
            failure_msg.text(T["upgradeFailed"] + " " + T["noFreeMemory"]);
            break;
          case "255":
            failure_msg.text(T["upgradeFailed"] + " " + T["incorrectFirmware"]);
            break;
          case "15":
            failure_msg.text(T["upgradeFailed"] + " " + T["wrongKey"]);
            break;
          default:
            failure_msg.text(T["upgradeFailed"]);
            break;
          }
          failure_msg.text(failure_msg.text() + "(" + T["errorCode"] + " " + data.errorcode + ")")
          failure_msg.removeClass("hide");
          failure_msg[0].scrollIntoView();
          tch.removeProgress()
        }
      })
      .fail(wait_for_webserver_running)
    }
    window.setTimeout(waitForShutdownOrError, upgrfw_refreshDelay);
    return false;
  }

  $(".upgradefw").click(function() {
    $("#upgrade-nofile-msg, #upgrade-wrong-ext-msg, #upgrade-failed-msg, #upgrade-too-big-msg").addClass("hide");
    var nofile_msg = $("#upgrade-nofile-msg");
    var wrongext_msg = $("#upgrade-wrong-ext-msg");
    var toobig_msg = $("#upgrade-too-big-msg");
    if ($("#file-upgradefw").val() == "") {
      nofile_msg.removeClass("hide");
      nofile_msg[0].scrollIntoView();
      return false;
    }
    nofile_msg.addClass("hide");
    var validExtensions = ['rbi', 'fw'];
    var fileName = $("#file-upgradefw").val();
    var fileNameExt = fileName.substr(fileName.lastIndexOf('.') + 1);
    if ($.inArray(fileNameExt, validExtensions) == -1) {
      wrongext_msg.removeClass("hide");
      wrongext_msg[0].scrollIntoView();
      return false;
    }
    wrongext_msg.addClass("hide");
    var fileSize = $("#file-upgradefw")[0].files[0].size;

    $.ajax({ url: target, data: "action=getbanksize", timeout: refreshTimeOut, dataType: "json" })
      .done(function(data) {
        if (data.success == "true") {
	  var targetBankSize = Number(data.banksize);
	  if (fileSize > targetBankSize) {
            toobig_msg.removeClass("hide");
	    toobig_msg[0].scrollIntoView();
            $("#upgrade-transfer-msg").addClass("hide");
	    return false;
	  }
        }
      })
    toobig_msg.addClass("hide");

    var _this = $(this).parents(".control-group");
    $("#upgrade-failed-msg").addClass("hide");
    var upgrading_msg = $("#upgrade-transfer-msg");
    upgrading_msg.removeClass("hide");
    upgrading_msg[0].scrollIntoView();
    tch.showProgress(T["upgrading"]);
    $.fileUpload($("#form-upgradefw"), {
      params: { CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
      completeCallback: function(form, response) {
        $("#upgrade-transfer-msg").addClass("hide");
        if (response.success) {
          wait_for_upgradefw.call(_this);
        }
        else {
          tch.removeProgress();
          $("#upgrade-failed-msg").addClass("hide");
        }
      }
    });
    return false;
  });
