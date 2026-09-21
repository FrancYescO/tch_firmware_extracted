<%
-- Localization
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local table, ipairs = table, ipairs
local format = string.format
local iconUp = "<i class=\"icon-upload icon-small gray\"></i> "
local iconDown = "<i class=\"icon-download icon-small gray\"></i> "
local floor = math.floor
local match, format, gsub  = string.match, string.format, string.gsub

local TIMERJS = 1000
local function secondsToTime(uptime)
  if not uptime or uptime == "" then return T"Not Connected" end
  local days =  floor(uptime / 86400)
  local hours =  floor(uptime / 3600) % 24
  local minutes = floor(uptime / 60) % 60
  local seconds = uptime % 60
  if (days > 0) then
    return format(T"%d days %d hours %d minutes %d seconds", days, hours, minutes, seconds)
  elseif (hours > 0) then
    return format(T"%d hours %d minutes %d seconds", hours, minutes, seconds)
  elseif (minutes > 0) then
    return format(T"%d minutes %d seconds", minutes, seconds)
  else
    return format(T"%d seconds", seconds)
  end
end


--AJAX Part
function AJAX(ap,mac,path)
  local path, ssid_path, count = "", "", 0 
  local content = {}
  
  for i,v in ipairs(content_helper.getMatchedContent("rpc.wireless.ap.", true)) do
    local ap = match(v.path, "rpc%.wireless%.ap%.@([^%.]+)%.")
    for j,w in ipairs(content_helper.getMatchedContent("rpc.wireless.ap.@" .. ap .. ".station.", true))  do  
        local mac_found = match(w.path, tostring("rpc%.wireless%.ap%.@" .. ap .. "%.station%.@([^%.]+)%."))
        if mac_found == mac:untaint() and (w.flags ~= "" and w.rssi ~= "0") then 
          ssid_path = format("rpc.wireless.ssid.@%s.",v.ssid)
          count = count +1
          content = {
              rx_bytes = w.rx_bytes,
              tx_bytes = w.tx_bytes,
              assoc_time = w.assoc_time,
              ps_off_on_transistions = w.ps_off_on_transistions,
              rx_phy_rate = w.rx_phy_rate,
              tx_phy_rate = w.tx_phy_rate,
              rx_data_rate = w.rx_data_rate,
              tx_data_rate = w.tx_data_rate,
              flags = w.flags,
              rssi = w.rssi,
              capabilities = w.capabilities,
                 
          }
         elseif count == 0 then 
           content = {
              rx_bytes = "0",
              tx_bytes = "0",
              assoc_time = "0",
              ps_off_on_transistions = "0",
              rx_phy_rate = "0",
              tx_phy_rate = "0",
              rx_data_rate = "0",
              tx_data_rate = "0",
              flags = "",
              rssi = "0",
              capabilities = w.capabilities,
                 
          }
         
        end
    end
  end  

  
 
 
  if content.rssi == "0" then content.rssi ="-100" end
  content.assoc_time = secondsToTime(content.assoc_time)
  local ssid_content = {
     ssid = ssid_path .. "ssid",
     radio = ssid_path .. "radio",
  }
  content_helper.getExactContent(ssid_content)
  
   
   content.ssid = ssid_content.ssid
   content.freq = ""
   if ssid_content.radio == "radio_5G" then 
         content.freq = "5GHz"
   elseif ssid_content.radio == "radio_2G" then
         content.freq = "2.4GHz"
   end 
  
 
  --local state = T"Offline"
  --if content["State"] == "1" then 
  --  state = T"Online"
  --end
  
  local html = {}
  html[#html+1]="{"
  for k,v in pairs(content) do
    html[#html+1]=format("\"%s\":\"%s\"",k,v)
    html[#html+1]=","
  end
  html[#html]="}"
  ngx.print(html)
end

local getap, getpath, getmac, ajaxreq, dyn_device

local args = ngx.req.get_uri_args()

for key, val in pairs(args) do
  if key=="relf" then
    ajaxreq = 1
  elseif key=="ap" then
    getap = val
  elseif key=="mac" then
    getmac = val
  elseif key=="path" then
    getpath = val
  elseif key=="device" then
    dyn_device = val  
  end
end
--check the device value  
if dyn_device then
   if dyn_device:len() < 16 then dyn_device = nil end
end
if ajaxreq == 1 then
   AJAX(getap,getmac,getpath)
   ngx.exit(ngx.HTTP_OK)     
end


--AJAX End



--Collect the Wireles Client details
local ssids = {}
for i,v in ipairs(content_helper.getMatchedContent("rpc.wireless.ssid.", true)) do
    local ssid = match(v.path, "rpc%.wireless%.ssid%.@([^%.]+)%.")
    if ssid then
        ssids[ssid] = {
                           radio = v.radio,
                           ssid = v.ssid,
        }
    end
end 
local accesspoints = {}
local clients = {}
local output_details = {}
local online = 0
for i,v in ipairs(content_helper.getMatchedContent("rpc.wireless.ap.", true)) do
    local ap = match(v.path, "rpc%.wireless%.ap%.@([^%.]+)%.")
    if ap then
        if ssids[format("%s",v.ssid)] then
          for j,w in ipairs(content_helper.getMatchedContent("rpc.wireless.ap.@" .. ap .. ".station.", true))  do          
          --ipairs(proxy.getPN("rpc.wireless.ap.@" .. ap .. ".station.", true))
                  local client = match(w.path, "rpc%.wireless%.ap%.@" .. ap .. "%.station%.@([^%.]+)%.")
                  
                  if w.flags ~= "" and w.rssi ~= "0" then
                     online = 1 
                    clients[client] = {
                               ap = ap,
                               radio = ssids[format("%s",v.ssid)]["radio"],
                               ssid = ssids[format("%s",v.ssid)]["ssid"],
                               path = w.path,
                               hostname = client,
                               
                    }
                    if client == dyn_device then
                      
                      output_details = {
                                 ap = ap,
                                 radio = ssids[format("%s",v.ssid)]["radio"],
                                 ssid = ssids[format("%s",v.ssid)]["ssid"],
                                 path = w.path,
                                 hostname = client,
                                 mac = client,
                      } 
                    end  
                  end
                  
               
          end
        end
    end
end
for i,v in ipairs(content_helper.getMatchedContent ("sys.hosts.host.")) do
   local MACAddress = format("%s",v.MACAddress)
   if clients[MACAddress] then
      clients[MACAddress]["hostname"] = v.HostName
      if MACAddress == dyn_device then
            output_details["hostname"] = v.HostName
      end   
   end
end



local client_select = {}
local path = output_details["path"]
local device_info = {}
if online == 0 then dyn_device = nil end
if dyn_device  then
   
   local content = {
      rx_bytes = path .. "rx_bytes",
      tx_bytes = path .. "tx_bytes",
      assoc_time = path .. "assoc_time",
      state = path .. "state",
      ps_off_on_transistions = path .. "ps_off_on_transistions",
      rx_phy_rate = path .. "rx_phy_rate",
      tx_phy_rate = path .. "tx_phy_rate",
      rx_data_rate = path .. "rx_data_rate",
      tx_data_rate = path .. "tx_data_rate",
      capabilities = path .. "capabilities",
      flags = path .. "flags",  
  }
   content_helper.getExactContent(content)
   for k,v in pairs(content) do
       output_details[k] = v
    end
else
   client_select[#client_select+1] = {"0" , "None selected"}
end



for i,v in pairs(clients) do
    client_select[#client_select+1] = {i,v.hostname}
end



%>

<% ngx.print(ui_helper.createHeader(T"Wireless Client Monitor", false, false)) %>

<div class="modal-body update">
  <form class="form-horizontal" method="post" action="modals/wireles-client-modal.lp">
    <%
    html = {}
    html[#html + 1] = ui_helper.createMessages(message_helper.popMessages())
    %>

    <fieldset>
      <legend><%= T"Selection" %></legend>
      <%
      local clientSelect = {
        group = {
            class = "",
        },
        select = {
            class = "span6"
        }
      }
    html[#html + 1] = ui_helper.createInputSelect(T"Choose Device", "client_selected", client_select, dyn_device, clientSelect)
    local refresh_style = {

        button = {
          id = "btn-refresh",
        }
      }
    html[#html + 1] = ui_helper.createButton(T"Refresh List", T"Refresh", "icon-refresh", refresh_style)
    ngx.print(html)
    %>  
    </fieldset>
    <% if dyn_device then %>
    <fieldset>
      <legend><%= T"Device Details" %></legend>
      <%
      html = {}
         local host_style = {
           span = {
                id = "Host",
                class = "span6"
            }
          }
             
         
         if output_details["hostname"] ~= output_details["mac"] then
         local perspective_warning = {
              alert = {
                  class = "alert-warning",
              },
          }
         html[#html + 1] = ui_helper.createAlertBlock(T"All information is given from the Client perspective", perspective_warning)
         html[#html+1] = ui_helper.createLabel(T"Host Name", output_details["hostname"], host_style )
         end
         local Freq_style = {
           span = {
                id = "freq",
                class = "span6"
            }
          }
          local freq = "2.4GHz"
          if output_details["radio"] == "radio_5G" then 
             freq = "5GHz"
          end
         html[#html+1] = ui_helper.createLabel(T"Frequency",freq , Freq_style )
         local SSID_style = {
           span = {
                id = "ssid",
                class = "span6"
            }
          }
         html[#html+1] = ui_helper.createLabel(T"SSID",output_details["ssid"] , SSID_style )
         local MAC_style = {
           span = {
                id = "MACAddr",
                class = "span6"
            }
          }
         html[#html+1] = ui_helper.createLabel(T"MAC Address", output_details["mac"]:upper(), MAC_style )
         local capa_style = {
           span = {
                id = "capabilities",
                class = "span6"
            }
          }
         html[#html+1] = ui_helper.createLabel(T"Device Capabilities", output_details["capabilities"], capa_style )
         local Active_style = {
           span = {
                id = "Active",
                class = "span6"
            }
          }
         html[#html+1] = ui_helper.createLabel(T"Active", output_details["flags"], Active_style )
         local PS_style = {
           span = {
                id = "PS",
                class = "span6"
            }
          }
         html[#html+1] = ui_helper.createLabel(T"Power Transitions", output_details["ps_off_on_transistions"], PS_style )
         html[#html+1] = "<label class=\"control-label\">RSSI</label><div id=\"chartcontainerwifi\"><div class=\"spacer\"/><div id=\"scale1wifi\" class=\"scalewifi\">-0dBm</div><div id=\"scale2wifi\" class=\"scalewifi\">-100dBm</div><div id=\"rssivalue\" class=\"scalewifi\">-50dBm</div></div>"
         local PHY_style = {
           span = {
                id = "PHY_Rate",
                class = "span6"
            }
          }
         html[#html+1] = ui_helper.createLabel(T"PHY Rate", format("%s %.0f Mbs %s %.0f Mbs",iconUp,output_details["rx_phy_rate"]/1000,iconDown,output_details["rx_phy_rate"]/1000), PHY_style )
         local DATA_style = {
           span = {
                id = "Data_Rate",
                class = "span6"
            }
          }
         html[#html+1] = ui_helper.createLabel(T"Data Rate", format("%s %.0f Mbs %s %.0f Mbs",iconUp,output_details["rx_data_rate"]/1000,iconDown,output_details["rx_data_rate"]/1000), DATA_style )
         local Time_style = {
           span = {
                id = "Time",
                class = "span6"
            }
          }
         html[#html+1] = ui_helper.createLabel(T"Time Connected", secondsToTime(output_details["assoc_time"]) , Time_style )
         ngx.print(html)
         
      %>
    </fieldset>
    <% end
    
     %>
  </form>
</div>

<div class="modal-footer"> 
        <div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal"><%=T"Close"%></div>
        <div id="btn-return" class="btn btn-primary btn-large" ><%=T"Return"%></div> 
        <% 
        --data-toggle="modal" data-remote="/modals/wireless-modal.lp" data-id="wireless-modal"
        %>
</div>
<script>
var timerajax
function getInfo(mac,ap,getpath)
{
  var url = '/modals/wireless-client-modal.lp';
  var checktimer = <%=TIMERJS%>;
  
  var gets =  {}
  gets.relf = "1";
  gets.mac = mac;
  gets.path = getpath;
  gets.ap = ap;
  $.getJSON(url, gets )
   .done(function( data ) {
      var phy_rate_up = (Math.floor(data.tx_phy_rate / 10)/100);
      var phy_rate_down = (Math.floor(data.rx_phy_rate / 10)/100);
      $("#PHY_Rate").html("<i class=\"icon-download icon-small gray\"></i> " + phy_rate_up + " Mbs  <i class=\"icon-upload icon-small gray\"></i> " + phy_rate_down + " Mbs"); 
      var data_rate_up = data.tx_data_rate;
      var data_rate_down = data.rx_data_rate;
      
      var data_rate_up_txt = " Kbs";
      var data_rate_down_txt = " Kbs";
      
      if (data_rate_up > 5000){
         data_rate_up = (Math.floor(data_rate_up / 10)/100);
         data_rate_up_txt = " Mbs";
      }
      if (data_rate_down > 5000){
         data_rate_down = (Math.floor(data_rate_down / 10)/100);
         data_rate_down_txt = " Mbs";
      }
      $("#Data_Rate").html("<i class=\"icon-download icon-small gray\"></i> " + data_rate_up + data_rate_up_txt + " <i class=\"icon-upload icon-small gray\"></i> " + data_rate_down + data_rate_down_txt); 
      $("#Active").html(data.flags);
      $("#PS").html(data.ps_off_on_transistions);
      $("#Time").html(data.assoc_time);
      $("#rssivalue").html(data.rssi + "dBm");
      $("#capabilities").html(data.capabilities);
      $("#freq").html(data.freq);
      $("#ssid").html(data.ssid);
      bars(data.rssi);
   })
   .error(function() { 
      
   });

   
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
         Popup("<%=T"Please wait..."%>");
         if (timerajax){clearTimeout(timerajax)};
         tch.loadModal('/modals/wireless-client-modal.lp', 'device='+client_selected.val());
   });
   btn_refresh.click(function() {
         if (timerajax){clearTimeout(timerajax)};
         Popup("<%=T"Please wait..."%>");
         var devicestr = "";
         if (client_selected.val() != "0"){
            devicestr = 'device='+client_selected.val();
         }
         tch.loadModal('/modals/wireless-client-modal.lp', devicestr);
            
   });

   btn_return.click(function() {
         if (timerajax){clearTimeout(timerajax)};
         Popup("<%=T"Please wait..."%>");
         tch.loadModal('/modals/wireless-modal.lp', '', function() {
            $(".modal").modal();
         });   
   });
    
   <% if dyn_device then %>
   getInfo("<%=output_details["mac"]%>","<%=output_details["ap"]%>","<%=path%>")
   <% end %>
});

</script>
