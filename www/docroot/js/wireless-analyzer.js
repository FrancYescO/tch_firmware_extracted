function cap2info(x){
  var type = ""
  var xhex = parseInt(x,16);
  if (xhex & parseInt(1,16)) type = type + "802.11b";
  if (xhex & parseInt(2,16)) type = type + "802.11g";
  if (xhex & parseInt(4,16)) type = type + "802.11a";
  if (xhex & parseInt(8,16)) type = type + "802.11n";
  if (xhex & parseInt(8000,16)) type = type + "802.11ac";
  var ant = ""
  if (xhex & parseInt(10,16)) ant = " 1x1";
  if (xhex & parseInt(20,16)) ant = " 2x2";
  if (xhex & parseInt(40,16)) ant = " 3x3";
  if (xhex & parseInt(80,16)) ant = " 4x4";
  var Features = ""
  if (xhex & parseInt(100,16)) Features = Features +" WMM";
  if (xhex & parseInt(2000,16)) Features = Features +" STBC";
  if (xhex & parseInt(4000,16)) Features = Features +" LDPC";
  if (xhex & parseInt(40000,16)) Features = Features +" BF";
  var Bond = ""
  if (xhex & parseInt(200,16)) Bond = Bond + " 40MHz";
  if (xhex & parseInt(10000,16)) Bond = Bond + " 80MHz";
  var SGI = ""
  if (xhex & parseInt(400,16)) SGI = SGI + " SGI20";
  if (xhex & parseInt(800,16)) SGI = SGI + " SGI40";
  if (xhex & parseInt(20000,16)) SGI = SGI + " SGI80";
  return type + ant + Bond + SGI + Features;
}

function get_random_color() {
  var letters = '0123456789ABCDEF'.split('');
  var color = '#';
  for (var i = 0; i < 6; i++ ) {
    color += letters[Math.round(Math.random() * 15)];
  }
   return color;
}
  function get_y_from_sig(max, min, range, sig) {
    return ((sig-max)/((min-max)/range))+30;
  }
  function get_curve_y_from_sig(max, min, range, sig) {
      var line = 350 - get_y_from_sig(max, min, range, sig);
      var line = 350 - (line *2);
    return line;
  }
  var maximum= -20;
  var minimum= -105;
  var range = 320;
  var bittarget40 = 10;
  var bittarget80 = 16;
  var ctx
  function initializeAnalyzer() {
    var c=document.getElementById("wrapper");
    ctx=c.getContext("2d");
    ctx.lineStyle="#FF0000";
    ctx.strokeStyle = "#000000";

    //Y Axis
    ctx.moveTo(30,30);
    ctx.lineTo(30,350);
    ctx.stroke();

    //Power Marks
    //30
    var line10 = get_y_from_sig(maximum, minimum, range, -10);

    ctx.moveTo(30,line10);
    ctx.lineTo(25,line10);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("-10",7,line10 + 3);

    var line30 = get_y_from_sig(maximum, minimum, range, -30);

    ctx.moveTo(30,line30);
    ctx.lineTo(25,line30);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("-30",7,line30 + 3);

    //60
    var line60 = get_y_from_sig(maximum, minimum, range, -60);

    ctx.moveTo(30,line60);
    ctx.lineTo(25,line60);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("-60",7,line60 + 3);

     //90
    var line90 = get_y_from_sig(maximum, minimum, range, -90);

    ctx.moveTo(30,line90);
    ctx.lineTo(25,line90);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("-90",7,line90 + 3);

    //X Axis
    ctx.moveTo(30,350);
    if (radio == "radio_2G") {
      ctx.lineTo(690,350);
    } else {
      ctx.lineTo(870,350);
    }
    ctx.stroke();
    //Titles
    ctx.font="9px Arial";
    ctx.fillText("Channel",310,390);
    ctx.save();
    ctx.translate(0, 0);
    //ctx.rotate(Math.PI/2);
    ctx.textAlign = "center";
    ctx.fillText("Signal Strength (-dBm)", 60, 25);
    ctx.restore();

    //Channel Marks
    if (radio == "radio_2G") {
      var chn_diff = 40;
      for (i = 1; i<=14; i++) {
        ctx.moveTo((i*chn_diff)+80, 350);
        ctx.lineTo((i*chn_diff)+80, 355);
        ctx.stroke();
        ctx.font="9px Arial";
        ctx.fillText(i.toString(), 77+(chn_diff*i), 370);
      }
    } else {
      var chn_diff = 30;
      var chnl = 0;
      for (i = 0; i <= 7; i++) {
         ctx.moveTo(60+(chn_diff*i),350);
         ctx.lineTo(60+(chn_diff*i),355);
         ctx.stroke();
         ctx.font="9px Arial";
         chnl = 36+(i*4);
         ctx.fillText(chnl.toString(),60+(chn_diff*i)-4,370);
      }

      for (i = 10; i <= 27; i++) {
         ctx.moveTo(60+(chn_diff*i),350);
         ctx.lineTo(60+(chn_diff*i),355);
         ctx.stroke();
         ctx.font="9px Arial";
         chnl = 60+(i*4);
         ctx.fillText(chnl.toString(),60+(chn_diff*i)-6,370);
      }

    }
    var color = parseInt("00000F", 16);
    // analyzer table header
    $("#key").empty().append(
      $("<br/>"),
      $("<div>").addClass("col_ssid").text(networkName),
      $("<div>").addClass("col_channel").text(channel),
      $("<div>").addClass("col_str").text(fortyMHz));
      if (radio != "radio_2G") { $("#key").append($("<div>").addClass("col_str").text(eightyMHz)); }
      $("#key").append($("<div>").addClass("col_rssi").text(signalStrength),$("<br/>"));
  }

  function generateGraph(ssid, channel, rssi, cap, sec, macaddr, chan_descr, extra, channeldisplay){
    var channel_descr = chan_descr;

    color =  get_random_color();
    var Mhz = 1;
    var Str = "";
    if (graphGeneration && isextenderSupported) {
      var cap = parseInt(cap,16).toString(2);

      /*if(cap.indexOf("40MHz")!=-1)
      {
        Mhz = 2;
        Str = "*"
      }
      */
      while (cap.length <= 16)
      {
        cap = "0"+cap;
      }

      if (cap.charAt(cap.length-bittarget40) == "1") {
        Mhz = 2;
        Str = '*';
      }
    } else {
      var str40 = "";
      var str80 = "";

      chan_descr = chan_descr.match(/(u)|(l)|(\/80)/g);
      if (chan_descr == "u" || chan_descr == "l") {
        Mhz = 2;
        Str = '*';
        str40 = "*";
      } else if (chan_descr == "/80") {
        Mhz = 4;
        str80 = "*";
      }
   }

    if (radio == "radio_2G") {
    //2.4GHz
    if ((extra == "u") || (extra == "l")) {
      Mhz = 2;
    }
    var xcoord = 80+(channel*40);
    var sig = rssi;
    if (sig > maximum){sig = maximum }else if (sig < minimum){sig = minimum}
    ctx.beginPath();

    color =  get_random_color();
    var curvey = get_y_from_sig(maximum, minimum, range, sig);
    ctx.strokeStyle = color;

    ctx.moveTo(xcoord-(80*Mhz), 350);
    ctx.quadraticCurveTo(xcoord-(80*Mhz)+20, curvey, xcoord-(80*Mhz)+40, curvey);
    ctx.lineTo(xcoord+(80*(Mhz))-40,curvey);
    ctx.moveTo(xcoord+(80*(Mhz)), 350);
    ctx.quadraticCurveTo(xcoord+(80*(Mhz))-20, curvey, xcoord+(80*(Mhz))-40, curvey);

    ctx.stroke();
    } else {
    //5G
    if (channelList && isextenderSupported) {
      var chlist40 = [38,46,54,62,102,110,118,126,134,142]
      var chlist80 = [42,58,106,122,138]
      var channel_text = channel
      var str40 = ""
      var str80 = ""
      for (i = 0; i <= chlist40.length; i++) {
        if (chlist40[i] == channel){
          str40 = "*";
          Mhz = 2;
        }
      }
      for (i = 0; i <= chlist80.length; i++) {
        if (chlist80[i] == channel){
          str80 = "*";
          Mhz = 4;
        }
      }
    }

    var xcoord = 0
    if  (channel <= 64) {
       xcoord = 60+((channel-36)*7.5);
    }else{
       xcoord = 360+((channel-100)*7.5);
    }

    var sig = rssi;

    if (sig > maximum){sig = maximum }else if (sig < minimum){sig = minimum}
        ctx.beginPath();
        color =  get_random_color();
	var curvey = get_y_from_sig(maximum, minimum, range, sig);
        ctx.strokeStyle = color;
        ctx.moveTo(xcoord-(15*Mhz), 350);
	ctx.quadraticCurveTo(xcoord-(15*Mhz)+5, curvey, xcoord-(15*Mhz)+10, curvey);
	ctx.lineTo(xcoord+(15*Mhz)-10,curvey);
	ctx.moveTo(xcoord+(15*Mhz), 350);
	ctx.quadraticCurveTo(xcoord+(15*Mhz)-5, curvey, xcoord+(15*Mhz)-10, curvey);
        ctx.stroke();
	channel = channel_text;
     }

     // A new row for analyzer table
     var row = $("<div>").css("color", color);

     // Append the row
     $("#key").append(row);
     var img = document.createElement("img");
     img.src = img_path;

     //Creating JSON object so as to get the details of each ssid dynamically.
     var dataobj = {"ssid":ssid,"channel":channeldisplay,"rssi":rssi,"cap":cap,"sec":sec,"macaddr":macaddr, "chan_descr":chan_descr}
     var dataString = JSON.stringify(dataobj);

     // Add columns to the new row
     var divinfo = " data-toggle='tooltip' title='"+cap2info(cap)+"' data-placement='right'";
     $(row).append($("<div"+divinfo+">").addClass("col_ssid").text(ssid), $("<div"+divinfo+">").addClass("col_channel").text(channeldisplay));
     (radio == "radio_2G") ? $(row).append($("<div"+divinfo+">").addClass("col_str").text(Str)) : $(row).append($("<div"+divinfo+">").addClass("col_str").text(str40),$("<div"+divinfo+">").addClass("col_str").text(str80));
     $(row).append($("<div"+divinfo+">").addClass("col_rssi").text(rssi));
     $(row).append($("<div"+divinfo+">").addClass("col_infof").append(img).attr("value", dataString).attr("onclick","deviceInfo($(this).attr('value'))"));
  }

  function deviceInfo(ssid){
    var objDetails = JSON.parse(ssid);
    $("#ssid_info").addClass("popUp");
    $("#ssid_info").show();
    $(".modal-body").scrollTop(500);
    $("#ssidName").text(objDetails.ssid);
    $("#macAddrCh").text(objDetails.macaddr);
    $("#signalStrength").text(objDetails.rssi);
    $("#channelInfo").text(objDetails.channel);
    var secmode = "";
    if (objDetails.sec != null){
      secmode = objDetails.sec;
    }
    $("#protMode").text(secmode.replace("WPAWPA","WPA"));
    var channelDescr = objDetails.chan_descr;
    var channelWidth = "20 Mhz";
    if(channelDescr){
      channelDescr = channelDescr.match(/(u)|(l)|(\/80)|(\/160)/g);
      if (channelDescr == "u" || channelDescr == "l")
        channelWidth = "40 Mhz";
      else if (channelDescr == "/80")
        channelWidth = "80 Mhz";
      else if (channelDescr == "/160")
        channelWidth = "160 Mhz";
    }
    $('#chWidth').text(channelWidth);
  }

  $("#moreDetails-btn-ok").click(function() {
    $("#ssid_info").hide();
  });

  function show_rescanconfirming(freq,show){
    var msg_id = "confirming-msg_" + freq;
    var rescan_id = "rescan-changes_" + freq;
    if (show == 1){
      $("div[id^= "+ rescan_id +"]").show();
      $("div[id^= "+ msg_id +"]").show();
    }
    else {
      $("div[id^= "+ rescan_id +"]").hide();
      $("div[id^= "+ msg_id +"]").hide();
    }
  }

  $("div[id^='ReScan_']").click(function() {
    var freq = (this.id).split("_")[1];
    show_rescanconfirming(freq,1);
  });

  $("div[id^='rescan-confirm_']").click(function() {
    var freq = (this.id).split("_")[1];
    show_rescanconfirming(freq,0);
  });

  $("div[id^='rescan-cancel_']").click(function() {
    var freq = (this.id).split("_")[1];
    show_rescanconfirming(freq,0);
  });

    $(document).ready(function(){
      $("div[id^='rescan-confirm_']").on("click",function(a) {
        $("#ssid_info").removeClass("popUp");
        var freq = (this.id).split("_")[1];
        show_rescanconfirming(freq,0);

        var params = [];
        params.push({
          name : "action",
          value : "rescan"
        });
        params.push({
          name : "curradio",
          value : radio
        });
        params.push(tch.elementCSRFtoken());
        tch.showProgress(rescan);
        $.post("/modals/wireless-modal.lp", params, function(acsData){
          tch.removeProgress();
          initializeAnalyzer();
          if ( acsData.length > 0 ) {
            $.each(acsData, function(i, data){
              var macaddr = data.paramindex;
              var macRegex = /[a-fA-F0-9:]{17}/g;
              if (macaddr) {
                macaddr = macaddr.match(macRegex);
              }
              else {
                macaddr = data.mac_address;
              }
	      generateGraph(data.ssid, data.channelCentre, data.rssi, data.cap, data.sec, macaddr, data.chan_descr, data.channelExtra, data.channel);
            });
          }
        });
      });
      initializeAnalyzer();
      $.get("/modals/wireless-modal.lp?isWifiAnalyzer="+getWifiAnalyzer+"&getAcsData=true&radio="+radio,function(acsData){
         $("#analyzerloader").addClass("hide");
         $("#analyzerGraph").removeClass("hide");
         $("#analyzerloader1").addClass("hide");
         $.each(acsData, function(i, data) {
           var macaddr = data.paramindex;
           var macRegex = /[a-fA-F0-9:]{17}/g;
           if (macaddr) {
             macaddr = macaddr.match(macRegex); }
           else {
             macaddr = data.mac_address; }
           generateGraph(data.ssid, data.channelCentre, data.rssi, data.cap, data.sec, macaddr, data.chan_descr, data.channelExtra, data.channel);
         });
          $('[data-toggle="tooltip"]').tooltip()
       });
    });
