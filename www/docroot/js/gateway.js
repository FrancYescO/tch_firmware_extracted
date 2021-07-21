if(wizard){
  if(wizard_accessed != "1"){
    $(document).ready(function(){
      $("#wizard-btn").click();
    });
  }
  $(document).on("click", "#cancel-config, #close-config", function (a)
  {
    $(".loading").removeClass("hide");
  });
  $(document).on("click", ".span1 a.button.btn-primary.btn-close", function (a)
  {
    $(".loading").removeClass("hide");
  });
}

// When login happened, the showAdvancedMode value should be false to hide some fields (ex: add/delete option for table in WAN Service
sessionStorage.setItem("showAdvancedMode", "false");

if(window.sessionStorage.getItem("current_role") == null && current_role != "guest"){
  window.sessionStorage.setItem("current_role", current_role);
}

function httpErrorMessage(err){
    switch(err.status){
        case 500:
            erromsg= errorGroup[0]
            break;
        case 404:
            erromsg= errorGroup[1]
            break;
        case 503:
            erromsg= errorGroup[2]
            break;
        case 408:
            erromsg= errorGroup[3]
            break;
        default:
             erromsg= errorGroup[4]
    }
    window.setTimeout(function(){
      erromsg = '<div style="margin-left:35%;margin-top:9%;"><span class="alert-error">'+erromsg+'</span></div>';
      var ht = $('.modal-body').height();
      ht = toString(ht).match(/\d+/) > 230 ? ht:230;
      $('.modal-body').height(ht);
      var tab = $('.modal-body ul').html();
      if(tab != undefined)
        erromsg = '<ul class="nav nav-tabs">' + tab + '</ul>' + erromsg;
      $('.modal-body').html(erromsg);
    },400);
}
