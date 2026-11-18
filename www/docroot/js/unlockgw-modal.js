(function() {
  var target = $(".modal form").attr("action");
    function postAction() {
      $.post(
        target,
           {action: "unlock_gw", CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
        "json"
      );
    }
    if (! $("#btn-unlock").is(":visible")) {
      $("#close-config").attr("data-dismiss", "")
      $("#close-config").attr("id", "new-close")
    }
    $("#new-close").click(function() {
      window.location = "/login.lp";
    });
    $("#btn-unlock").click(function() {
      $("#switch_alert, #modal-changes").removeClass("hide");
      $("#modal-no-change").addClass("hide");
      $("#save-config").click(function() {
        setTimeout(function(){
          window.location = "/login.lp";
        },20000)
        postAction()
      });
    });
}());
