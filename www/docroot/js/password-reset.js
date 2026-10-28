$(document).ready(function(){
    $("#btn_cancel").click(function(){
      $("#action").val("cancel");
      $("#password_reset").submit();
    });
     $("#btn_reset").click(function(){
       $("#password_reset").submit();
    });
  });

