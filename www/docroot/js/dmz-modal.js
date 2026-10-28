(function() {
  var refreshTimeOut = 5000;
  var refreshDelay = 3000;
  var target = $(".modal form").attr("action");

  $("#input-dmz").change(function() {
    $("#dmz-flag").val("1");
  });

  // Handle save config call
  $(document).on("click", "#save-dmz-config", function () {
      $("#modal-changes").css({"display":"none"});
      $("#modal-no-change").css({"display":"block"});
      $("#rebooting-msg").removeClass("hide");
      var form = $(".modal form");
      var params = form.serializeArray();
      params.push({
          name : "action",
          value : "SAVE"
      }, {
          name : "fromModal",
          value : "YES"
      }, tch.elementCSRFtoken());
      var target = form.attr("action");
      if ($("#dmz-flag").val() === "1") {
        $.post(
          target,
          params,
          wait_for_webserver_down,
          "json"
        );
        return false;
      }
  });
}());

