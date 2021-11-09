var timerajax

function getInfo(mac,ap,getpath)
{
    var url = '/modals/wireless-client-modal.lp';
    var gets =  {}
    gets.ajaxreq = "1";
    gets.mac = mac;
    gets.path = getpath;
    gets.ap = ap;
    $.getJSON(url, gets )
    .done(function( data ) {
        var phy_rate_up = (Math.floor(data.tx_phy_rate / 10)/100);
        var phy_rate_down = (Math.floor(data.rx_phy_rate / 10)/100);
        $("#PHY_Rate").html("<i class=\"icon-download icon-small gray\"></i> " + phy_rate_up + " Mbps  <i class=\"icon-upload icon-small gray\"></i> " + phy_rate_down + " Mbps");
        $("#Active").html(data.flags);
        $("#assoc_time").html(data.assoc_time);
        $("#rssivalue").html(data.rssi + "dBm");
        $("#capabilities").html(data.capabilities);
        $("#freq").html(data.freq);
        $("#ssid").html(data.ssid);

        if (data.freq == "5GHz" && type5G != "broadcom") {
          $("div.control-group:contains('Data')").addClass('hide');
        } else {
          $("div.control-group:contains('Data')").removeClass('hide');
        }

        if (PacketsInfoAndCurrentTime) {
          if(data.Packets_Sent<sentpctstart || data.Packets_Received<recvpctstart)
          {
            sentpctstart = 0;
            recvpctstart = 0;
          }
          $("#Packets_Sent").html(data.Packets_Sent);
          $("#Packets_Received").html(data.Packets_Received);

          $("#Current_Time").html(data.Current_Time);
        }

        bars(data.rssi);
    })
    .error(function() {
    });
    clearTimeout(timerajax);
   timerajax = window.setTimeout(function () {getInfo(mac,ap);}, checktimer);
}
// Wifi chart scripts
    var countwifi = 0;
   function bars(x){
          var y = 100 + parseInt(x);
          var x = parseInt(x) * -1
          $("#chartcontainerwifi").append('<div class=\"barswifi\" id=\"bar-'+countwifi+'\"></div>');
          var $d = $("#bar-"+countwifi)
          var color = '#FF0000'; //default red
          if (x <= 55){
            color =  '#00FF00'; //green
          }else if (x<80 && x>55){
            color =  '#FF9900'; //orange
          }
          $d.css({'height': y+'px', 'left': $('#chartcontainerwifi').width() + 'px', 'background-color': color }).appendTo('#div-1');;
          $(".barswifi").each(function(){
                $(this).animate({//left: '5px'
                //$(this).css({
                  'left': $(this).position().left -5,
                  'opacity': $(this).css('opacity')-0.02,
                  'filter': 'alpha(opacity='+toString(($(this).css('opacity')-0.02)*100)+')'
                },'1500');
                if ($(this).position().left < 0){$(this).remove();}
           });
           countwifi++;
   }

//

var client_selected_option = $("[name='client_selected'] option");

var client_selected = $("[name='client_selected']");
var btn_refresh = $("#btn-refresh");
var btn_return = $("#btn-return");

$(function() {
    $('h2').removeClass('span4');
    $('#save-config').remove();
    $("#chartcontainerwifi").css({'left': '20px', 'margin' : '0px'});
    $(".control-label").css({"font-weight":"bold"});
    client_selected.change(function() {
        if (timerajax){clearTimeout(timerajax)};
        tch.loadModal('/modals/wireless-client-modal.lp', 'device='+client_selected.val());
    });
    btn_refresh.click(function() {
        if (timerajax){clearTimeout(timerajax)};
        var devicestr = "";
        if (client_selected.val() != "0"){
            devicestr = 'device='+client_selected.val();
        }
        tch.loadModal('/modals/wireless-client-modal.lp', devicestr);
    });

    btn_return.click(function() {
        if (timerajax){clearTimeout(timerajax)};
            tch.loadModal('/modals/wireless-modal.lp', '', function() {
            $(".modal").modal();
        });
   });
   $(".nav-tabs").click(function() {
        if (timerajax){clearTimeout(timerajax)};
   });
   if (dyn_device) {
       getInfo(mac, ap, path)
   }
});

