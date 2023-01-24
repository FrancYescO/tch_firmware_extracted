  $(document).ready(function() {
    if (readOnlyWirelessCard) {
      $('.wifi-card').on('mouseenter', function() {
        var $this = $(this);
        if (this.offsetWidth < this.scrollWidth && !$this.attr('title')) {
          $this.attr('title', $this.text());
        }
      });
    }
    var clearRefreshInterval = function() {
        clearInterval(refreshTimer);
      };
      var self = this;
      self.render = function() {
        $.ajax({ type: "POST", url: "/ajax/wirelesscard.lua?auto_update=true", dataType: "json", data: [tch.elementCSRFtoken()], success: function(data) {
          if (data != "") {
            if (data.length > 4) {
              $(".wifi-card strong").attr("style", "margin-left:26px;font-size:30px;").html("...");
              clearInterval(refreshTimer);
            }
            else {
              for (i = 0; i < data.length ; i++) {
                $("#wificard_"+(i+1)).html("<div class='" + data[i].listatus + "'></div><p class = 'wifi-card'>"+"<strong>"+data[i].ssid+"</strong>("+data[i].radio+")"+"</p>");
              }
            }
            if(data.length!=2 && varient_check){
              clearInterval(refreshTimer);
              $("#wificard_3, #wificard_4").removeAttr("style");
            }else if(!varient_check){
              clearInterval(refreshTimer);
           }
          }
        }, error: clearRefreshInterval });
      };
      var refreshTimer = setInterval(self.render, 7000);
      self.render();
    });
