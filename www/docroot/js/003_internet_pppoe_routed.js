function refreshInternetCard(){
    var timeOutId=0;
    $.ajax({ type: "GET", url: "/ajax/internet.lua?auto_update=true", dataType: "json", success: function(data){
      if(data.ppp_status == "connected" && data.ipv6_state == "IPv6 Connected"){
        var html =  "<span class=\"simple-desc\"><div class=\"light " + data.ppp_light+"\"></div>"+data.ppp_state+"</span>";
        html = html + "<p class=\"subinfos\">";
        html = html + WANIP +"<strong>" + data.WAN_IP + "</strong><span class=\"simple-desc\"></span></p>";
        html = html + "<div class=\"light " + data.ipv6_light+"\"></div>"+data.ipv6_state+"<p></p>";
        clearTimeout(timeOutId);
      }
      else
      {
        timeOutId=setTimeout(refreshInternetCard,5000);
      }
      $("#internetCard .content").html(html);
    }, error: clearTimeout(timeOutId) });
  }
  $(document).ready(function(){
    refreshInternetCard();
  });
