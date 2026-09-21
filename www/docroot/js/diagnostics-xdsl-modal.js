$.get("/modals/diagnostics-xdsl-modal.lp?action=GET_BITS&show_line_one="+showBondingStats, function (data){
  $('#dsl_bit_chart').replaceWith(data);
});
$.get("/modals/diagnostics-xdsl-modal.lp?action=GET_ADVANCED_DATA", function (data){
  $('#xdsl_advanced_data').replaceWith(data);
  $('.modal-action-advanced').each(function(){
    var obj = $(this);
    if(obj.html() != null && obj.html().indexOf("hide") > -1 &&
      obj.attr("style") != undefined && obj.attr("style").indexOf("inline") > -1){
      $("#diagnostics-xdsl-framing").removeClass("hide");
      $("#diagnostics-xdsl-ginp").removeClass("hide");
      $("#diagnostics-xdsl-vectoring").removeClass("hide");
    }
  });
});
