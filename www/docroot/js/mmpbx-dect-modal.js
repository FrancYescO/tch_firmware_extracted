(function() {
    var target = $(".modal form").attr("action");
    var modalbody = $(".modal-body");
    var scrolltop = $(".modal-body").scrollTop();
    var checkDelay = 3000;
    var refreshTimeOut = 5000;
    var time_elapsed = 0;
    var pairtime = parseInt(document.getElementsByName("pairTime")[0].value) * 1000;
    var max_timer = pairtime + checkDelay + 1000;
    var _this;

    function wait_to_registered() {
      $.ajax({ url: target, data: "action=pairing_state", timeout: refreshTimeOut, dataType: "json" })
        .done(function(data) {
          if (data.success == "true") {
            time_elapsed = time_elapsed + checkDelay;
            if (time_elapsed < max_timer) {
              window.setTimeout(wait_to_registered, checkDelay);
            }
          }
          else {
            tch.loadModal(target, function () {
              $(".modal-body").scrollTop(scrolltop);
            });
            $('.popUpBG').remove();
            $('#popUp').remove();
          }
        });
    }

    $("#btn-pairing").click(function() {
      pairProgress(cancelMsg);
      $.post(
        target,
        { action: "pairing_handset", CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
        wait_to_registered,
        "json"
      );
      return false;
    });
    function wait_to_unregisterd() {
      tch.loadModal(target, function () {
        $(".modal-body").scrollTop(scrolltop);
      });
    };
    $("#btn-unreg").click(function() {
      if (document.getElementById("handset_id").value == "all") {
        var r = confirm("Are you sure you want to Unregister all the Dect Handset?");
        if (r == false) {
          return false
        }
      }
      $.post(
        target,
        {
          action: "unreg_handset",
          handset_id: document.getElementById("handset_id").value,
          CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
        },
        wait_to_unregisterd,
        "json"
      );
      return false;
    });

   //The function used to build and show the bubble progress bar on mini pop-up window.
    function pairProgress(msg){
      var header = '<div class="header"><div data-toggle="modal" class="header-title pull-left"><p>'+processMsg+'</p></div></div>'
      $("body").append('<div class="popUpBG"></div>');
      $("body").append('<div id="popUp"  class="popUp smallcard">'+header+'<div id="Poptxt" class="content"></div>');
      var content = msg+'<br/><div id="spinner" class="spinner" align="center"><div class="spinner3"><div class="rect1"></div><div class="rect2">'+'</div><div class="rect3"></div><div class="rect4"></div><div class="rect5"></div></div><div id="cancel_pairing" class="btn btn-large"'+'>Cancel</div></div>';
      var ht =$(document).height();
      var wht = $(window).height();
      var sp = $(window).scrollTop();
      $("#Poptxt").html(content);
      $('.popUpBG').css("height", ht);
      var bgcolor = $(".header .settings").css("background-color");
      //Setting progress bar color as the color of small card header.
      $(".spinner3 div").css("background-color", bgcolor);
      if(sp > 10){
        wht= wht*(4/10)+sp;
        $('#popUp').css("top", wht);
      }
      $("#cancel_pairing").click(function() {
        $.post(
          target,
          { action: "cancel_pairing", CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
          function(){
            tch.loadModal(target, function () {
              $(".modal-body").scrollTop(scrolltop);
            });
            $('.popUpBG').remove();
            $('#popUp').remove();
          },
          "json"
        );
      });
    }
}());
