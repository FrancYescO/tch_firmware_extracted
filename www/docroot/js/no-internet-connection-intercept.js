$(document).ready(function() {
  var target = "/no-internet-connection-intercept.lp";

  //Reconnect button function for redirecting to requested page
  $("#reconnect").click(function() {
    $.get(target+"?action=wanIpStatus", function(responseTxt) {
      if (responseTxt == "success") {
        window.setTimeout(function(){
          var redirectURL = location.protocol+"//"+prevUrl;
          location.href = redirectURL;
          return true;
        }, 5000);
      }
      else if (responseTxt == "error") {
        $.get(target+"?action=restart", function(responseTxt) {
          if (responseTxt == "true") {
            showWanProgress(restart);
            window.setTimeout(function(){
              var redirectURL = location.protocol+"//"+prevUrl;
              location.href = redirectURL;
              return true;
            }, 10000);
          }
        });
      }
    });
  });

  //The function used to build and show the bubble progress bar on mini pop-up window.
  function showWanProgress(msg){
    var header = '<div class="header"><div data-toggle="modal" class="header-title pull-left"><p>'+processMsg+'</p></div></div>'
    $("body").append('<div class="popUpBG"></div>');
    $("body").append('<div id="popUp"  class="popUp smallcard span3">'+header+'<div id="Poptxt" class="content"></div>');
    var content = msg+'<br/><div id="spinner" class="spinner" align="center"><div class="spinner3"><div class="rect1"></div><div class="rect2">'
    +'</div><div class="rect3"></div><div class="rect4"></div><div class="rect5"></div></div></div>';
    var ht =$(document).height();
    var wht = $(window).height();
    var sp = $(window).scrollTop();
    $("#Poptxt").html(content);
    $('.popUpBG').css("height",ht);
    var bgcolor = $(".smallcard .header").css("background-color");
    //Setting progress bar color as the color of small card header.
    $(".spinner3 div").css("background-color",bgcolor);
    if(sp > 10){
      wht= wht*(4/10)+sp;
      $('#popUp').css("top",wht);
    }
  }
});

