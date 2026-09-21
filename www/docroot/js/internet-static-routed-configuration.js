$(document).ready(function(){
    if ( $.trim($("#wanIpAddrParam").val()).length <=0 || $.trim($("#wanNetmaskParam").val()).length <=0 || $.trim($("#wanGatewayParam").val()).length <=0) {
      $('#modal-no-change').hide();
      $('#modal-changes').show();
    }
  });
