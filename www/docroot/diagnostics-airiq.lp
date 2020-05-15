--pretranslated: do not change this file
 ngx.print('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">\
');  
  local untaint_mt = require("web.taint").untaint_mt

  local airiq = setmetatable({
    channelquality = { title = 'AirIQ Channel Quality', flash = '/flash/LocalApChart.swf'},
    equalizer = { title = 'AirIQ Equalizer', flash = '/flash/equalizer.swf'},
    persistence = { title = 'AirIQ Persistence', flash = '/flash/persistence.swf'},
    spectrogram = { title = 'AirIQ Spectromgram', flash = '/flash/SpectrogramApp.swf'},
  }, untaint_mt)

  local headers = ngx.req.get_headers()
  local user_agent = headers and headers['user-agent']
  local getargs = ngx.req.get_uri_args()
  local chart_name = getargs.chart or 'channelquality'
  local chart = airiq[chart_name] or {}
  local title = chart.title or ''
  local flash = chart.flash or ''
  ngx.print('\
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">\
  <head>\
    <title>');  ngx.print(title); ngx.print('</title>\
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />\
    <script type="text/javascript" src="/js/swfobject-min.js"></script>\
    <script type="text/javascript" src="/js/main-min.js" ></script>\
    <style>\
      *{\
        margin:0;\
        padding:0;\
      }\
      html,body{\
        height:100%;\
        width:100%;\
      }\
    </style>\
  </head>\
  <body>\
    <div id="airiq" style="width:100%;height:100%;line-height:0px;font-size:0px">\
      <div id="playerProductInstall" style="line-height:normal;font-size:medium">\
        <p>You do not have flash plugin installed</p>\
        ');  if user_agent and string.match(user_agent:lower(), 'firefox') then   ngx.print('\
        <p><a href="http://www.adobe.com/go/getflashplayer">Get Adobe Flash player</a></p>\
        ');  else   ngx.print('\
        <p><a href="http://www.adobe.com/go/getflashplayer"><img src="http://www.adobe.com/images/shared/download_buttons/get_flash_player.gif" alt="Get Adobe Flash player" /></a></p>\
        ');  end    ngx.print('\
      </div>\
    </div>\
  </body>\
</html>\
<script type="text/javascript">\
  var so = swfobject.embedSWF("');  ngx.print(flash); ngx.print('", "playerProductInstall", "100%", "100%", "20.0.0");\
  function styleHeight() {\
    var h=window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight;\
    var o = document.getElementById("airiq");\
    o.style.height = (h > 768)?"100%":"768px";\
  }\
  $(document).ready(function(){\
    styleHeight();\
  });\
  $(window).resize(function(){\
    styleHeight();\
  });\
</script>\
'); 