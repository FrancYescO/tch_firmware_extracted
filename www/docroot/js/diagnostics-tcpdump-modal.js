(function() {
  var target = $(".modal form").attr("action");

  $("#saveonusb").click(function() {
    $(this).val($(this).is(":checked")? "1": "0")
  });

  $(".tcpdump-download").click(function() {
    $.fileDownload(target, {
      httpMethod: "POST",
      data: new Array({ name : "action", value : "tcpdump_download" },
                      { name : "CSRFtoken", value : $("meta[name = CSRFtoken]").attr("content") }),
      prepareCallback: function() {
        $("#download-failed-msg").addClass("hide");
        var downloading_msg = $("#downloading-msg");
        downloading_msg.removeClass("hide");
        downloading_msg[0].scrollIntoView();
      },
      successCallback: function() {
       $("#downloading-msg").addClass("hide");
      },
      failCallback: function() {
        var download_failed_msg = $("#download-failed-msg");
        download_failed_msg.removeClass("hide");
        download_failed_msg[0].scrollIntoView();
        $("#downloading-msg").addClass("hide");
      }
    });
    return false;
  });
}());

