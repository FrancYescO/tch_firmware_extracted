(function() {
  var target = $(".modal form").attr("action");
    $("#btn-unlock").click(function() {
      $("#switch_alert, #modal-changes").removeClass("hide");
      $("#modal-no-change").addClass("hide");
      $("#save-config").click(function() {
        setTimeout(function(){location.reload();},20000)
        $.post(
          target,
          { action: "unlock_gw", CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
          "json"
        );
      });
    });
}());

