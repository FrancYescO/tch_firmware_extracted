--pretranslated: do not change this file
 
  local tinsert = table.insert

  gettext.textdomain('webui-core')

  local proxy = require("datamodel")
  local ui_helper = require("web.ui_helper")
  local content_helper = require("web.content_helper")

  local function get_intercept_reasons()
    local intercept_reasons_path = 'rpc.intercept.reason.'
    local data = proxy.get(intercept_reasons_path)
    local results = content_helper.convertResultToObject(intercept_reasons_path, data)
    local reasons = {}
    if results then
      for _, reason in ipairs(results) do
        if reason.reason then
          reasons[string.untaint(reason.reason)] = true
        end
      end
    end
    return reasons
  end

  local function bytes_to_data_volume(val)
    local data_volume_map = {
      {
        value = 1024*1024*1024,
        unit = T"GB"
      },
      {
        value = 1024*1024,
        unit = T"MB"
      },
      {
        value = 1024,
        unit = T"KB"
      }
    }
    for _, data_volume in ipairs(data_volume_map) do
      if val > data_volume.value then
        val = val / data_volume.value
        return string.format("%.0f %s", val, data_volume.unit)
      end
    end
    return string.format("%.0f %s", val, T"B")
  end

  local function get_datausage_volume(condition)
    local datausage_interfaces_path = 'rpc.datausage.interface.'
    local data = proxy.get(datausage_interfaces_path)
    local results = content_helper.convertResultToObject(datausage_interfaces_path, data)
    local interface_data = {}
    if results then
      for key, interface in ipairs(results) do
        if interface[condition] == 'true' then
          local tx_bytes = tonumber(interface.tx_bytes_total)
          local rx_bytes = tonumber(interface.rx_bytes_total)
          if tx_bytes and rx_bytes then
            tinsert(interface_data, { interface = string.gsub(interface.paramindex, '@', ''), data_volume = bytes_to_data_volume(tx_bytes + rx_bytes) })
          end
        end
      end
    end
    return interface_data
  end

  local function get_page_content()
    local html = {}
    local reasons = get_intercept_reasons()
    if reasons['wan_down'] then
      local server_addr = proxy.get("uci.network.interface.@lan.ipaddr")[1].value
      local req_uri = ngx.var.http_host .. ngx.unescape_uri(ngx.var.request_uri)

      tinsert(html, [[<center>
          You have been intercepted for the following destination:<br>
          <i>]])
      tinsert(html, req_uri)
      tinsert(html, [[</i>
          <div>
          <p><b>WAN connection is unavailable.</b><br>
          Please check internet access settings, close your browser and try again.</p>
          <div>
          <p><a href="http://]])
      tinsert(html, server_addr)
      tinsert(html, [[">Click here to access Gateway web interface</a></p>
          </center>]])
    elseif reasons['datausage_limit_reached'] then
      tinsert(html, '<div>')
      tinsert(html, '<form class="form-horizontal" method="post" action="/">')
      for _, interface in ipairs(get_datausage_volume('usage_limit_reached')) do
        tinsert(html, ui_helper.createAlertBlock(string.format(T"You have reached the limit of your configured data volume on %s", interface.interface)))
      end
      tinsert(html, '<div id="ignore_datausage_limit" class="btn pull-right"><i class="icon-ok-sign"></i> ' .. T"Continue" .. '</div></form></div>')
      tinsert(html, '<center style="color: #3a87ad; clear: both;">' .. T"* You may be charged extra by your network operator after clicking continue" .. '</center>')
    elseif reasons['datausage_threshold_reached'] then
      tinsert(html, '<form class="form-horizontal" method="post" action="/">')
      for _, interface in ipairs(get_datausage_volume('usage_threshold_reached')) do
        tinsert(html, ui_helper.createAlertBlock(string.format(T"You have consumed %s of your total data volume on %s", interface.data_volume, interface.interface)))
      end
      tinsert(html, '<div id="ignore_datausage_threshold" class="btn pull-right"><i class="icon-ok-sign"></i> ' .. T"Continue" .. '</div></form>')
    else
      tinsert(html, ui_helper.createAlertBlock(T"You have been intercepted for an unknown reason"))
    end
    return html
  end

  if ngx.req.get_method() == "POST" then
    local args = ngx.req.get_post_args()
    local action = args["action"]
    if action == "ignore_datausage_limit" then
      proxy.set("rpc.datausage_notifier.event", "ignore_limit")
    elseif action == "ignore_datausage_threshold" then
      proxy.set("rpc.datausage_notifier.event", "ignore_threshold")
    end
    ngx.exit(ngx.HTTP_OK)
  end

  local cui = {
    timestamp = "uci.version.version.@version[0].timestamp",
    datausage_interface = "uci.datausage_notifier.interface"
  }
  content_helper.getExactContent(cui)

  local current_year = (string.sub(cui.timestamp, 1, 4))
  ngx.print('\
\
<!DOCTYPE HTML>\
<html>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
  <head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <link href="/css/gw.css" rel="stylesheet">\
    <link href="/css/responsive.css" rel="stylesheet">\
    <link href="/css/TIM.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-min.js" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <title>');  ngx.print( T"Datausage warning" ); ngx.print('</title>\
  </head>\
\
  <body>\
    </div>\
    <div class="container">\
      <div class="row">\
        <div class="header span12">\
          <img class="timlogo" src="/img/TIM.png">\
        </div>\
      </div>\
      ');  ngx.print( get_page_content() ); ngx.print('\
      <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
    </div>\
  </body>\
  <script>\
    $(document).ready(function() {\
      $("#ignore_datausage_limit, #ignore_datausage_threshold").click(function() {\
        var params = [{ name: "action", value: $(this).attr(\'id\')}];\
        $.post("", params, function(data) {\
          setTimeout(function() {\
            location.reload();\
          }, 1000);\
        });\
      });\
    });\
  </script>\
</html>\
\
');  
    ngx.exit(ngx.HTTP_OK)
  ngx.print('\
'); 