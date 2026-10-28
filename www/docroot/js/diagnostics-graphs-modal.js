$(document).ready(function() {
    $(document).on("change", "#GraphChoice", function() {
      clearTimeout(timerajax);
      $(document).off("change", "#GraphChoice");
      tch.loadModal("/modals/diagnostics-graphs-modal.lp?graph=" + this.value);
    });

    $("#btn-refresh").click(function() {
      $(document).off("change", "#GraphChoice");
      tch.loadModal("/modals/diagnostics-graphs-modal.lp?graph=" + $("#GraphChoice").val());
    });

    $("#Graphing").parent().addClass("active");
  });

