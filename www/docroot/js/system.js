(function() {
  $("[name=syslog_present]").change(function(){
    $("[name=syslog_ip]").val("");
    $("[name=syslog_filter_ip]").val("");
  });

  $("#btn-serial").click(function(){
    $("[name=syslog_prefix]").val(serial_numValue);
    $("#modal-no-change").slideUp();
    $("#modal-changes").slideDown();
  });

  $("[name=syslog_filter_sw]").change(function(){
    if ($( this ).val() == "0"){
      $("[name=syslog_ip]").val($("[name=syslog_filter_ip]").val());
      $("[name=syslog_filter_ip]").val("");
      $("[name=syslog_filter]").val("daemon");
     }
    else{
      $("[name=syslog_filter_ip]").val($("[name=syslog_ip]").val());
      $("[name=syslog_ip]").val("");
      $("[name=syslog_filter]").val("daemon");
    }
  });
}());
