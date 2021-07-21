$(document).ready(function () {
  var name_column = 0;
  $('#bridges tbody tr').each(function(){
    var td = $(this).find("td");
    if (td.eq(name_column).text() === default_lanValue) {
        td.find("div.btn.btn-mini").hide();
    };
  });

  var portname_column = 0;
  $('#ports tbody tr').each(function(){
    var td = $(this).find("td");
    var td = $(this).find("td");
    if (td.eq(portname_column).text() === port_mapValue) {
        td.find("div.btn.btn-mini").hide();
    }
  });
});

function waiting_action(self) {
  var msg_dst = $(self);
  var busy_msg = $(".loading-wrapper");

  msg_dst.after(busy_msg);
  busy_msg.removeClass("hide");
  busy_msg[0].scrollIntoView();
  $(".modal-body").scrollLeft(0);
};

$(document).on("click", "#save-config", function () {
  waiting_action(this);
});

$(document).on("click", "table [class*='btn-table-']:not(.disabled)", function () {
  waiting_action(this);
});

$(document).on("change", 'table .switch input[type="hidden"]', function (e) {
  var table = $(this).closest("table");
  // Check that we are not editing a line, this is only for when the line is displayed
  if (table.find(".btn-table-cancel").length === 0) {
    waiting_action(this);
  }
});
