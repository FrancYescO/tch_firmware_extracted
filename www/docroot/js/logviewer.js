var target = $(".modal form").attr("action");

$(".export-conntracklog").click(function() {
  $.fileDownload(target, {
    httpMethod: "POST",
    data: new Array({ name : "action", value : "export_log" },
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
if (isFeatureLogViewerFlag) {
  $(document).ready(function() {
    $('select[name="process"]').on("change", function() {
      var process = $(this).val();
      tch.loadModal("/modals/logviewer-modal.lp?process=" + process);
    });
  });
} else {
  $(document).ready(function() {
    $('select[name="facility"] , select[name="process"]').on("change", function() {
      sessionStorage.setItem("facility" ,$("#facility option:selected").val());
      tch.loadModal("/modals/logviewer-modal.lp?process=" +$("#process option:selected").val());
    });
    var temp = sessionStorage.getItem("facility") == "" ? 0 : sessionStorage.getItem("facility") == "processes" ? 0 : 1;
    $('#facility')[0].selectedIndex = temp;
    for(var i = 1;i< document.getElementById("logviewer").rows.length;i++) {
      var stringPattern = $("#logviewer tr:nth-child("+i+")").children("td").eq(1).html();
      (stringPattern.match(".err") || stringPattern.match(".warn")) ? $("#logviewer tr:nth-child("+i+")").css('color','#ff0000') : temp==1 ? $("#logviewer tr:nth-child("+i+")").addClass("hide"): "";
    }
    $("#logviewer th").css("color", "#000000");
  });
}
