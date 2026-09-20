/*
 * (C) 2016 NETDUMA Software
 * Kian Cross
*/

<%
require "libos"
local platform = os.platform_information()
local showUpload = platform.vendor ~= "TELSTRA"
%>

browserSetup.onReady(function () {
  $(document).ready(function () {

    <% if platform.vendor == "TELSTRA" then %>
    long_rpc_promise("com.netdumasoftware.qos","get_acceleration",[]).done(function(result){
      if(!result[0]){
    <% end %>
    qos.addPanel("sliders.html", [], {
      x: 0, y: 0, width: 12, height: 7
    });

    qos.addPanel("flower.html", [], {
      x: 0, y: 7, width: 12, height: 20
    });
    <% if platform.vendor == "TELSTRA" then %>
        }
      })
    <% end %>

    qos.addPanel("hyper-lane.html", [], {
      x: 0, y: 27, width: 8, height: 12
    });

    qos.addPanel("lane-information.html", [], {
      x: 8, y: 27, width: 4, height: 12
    });

  });
});
