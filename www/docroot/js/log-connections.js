(function() {
  var target = $(".modal form").attr("action");

  $(".export-conntracklog").click(function() {
    $.fileDownload(target, {
      httpMethod: "POST",
      data: new Array({ name : "action", value : "export_conntrack_log" },
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

  $("#searchInput").keyup(function () {
    //split the current value of searchInput
    var data = this.value.toUpperCase().split(" ");
    //create a jquery object of the rows
    var jo = $("#connections").find("tr");
    if (this.value == "") {
        jo.show();
        return;
    }
    //hide all the rows
    jo.hide();

    //Recusively filter the jquery object to get results.
    jo.filter(function (i, v) {
        var $t = $(this);
        for (var d = 0; d < data.length; ++d) {
            if ($t.text().toUpperCase().indexOf(data[d]) > -1) {
                return true;
            }
        }
        return false;
    })
    //show the rows that match.
    .show();
  }).focus(function () {
    this.value = "";
    $(this).css({
        "color": "black"
    });
    $(this).unbind('focus');
  }).css({
    "color": "#C0C0C0"
  });

}());
