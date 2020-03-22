--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local web = require("web.web")

local proxy = require("datamodel")

local assistance = require("web.assistance")
local assistant = assistance.getAssistant("remote")

local cui = {
    nsplink = "uci.web.uiconfig.@uidefault.nsplink",
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
    timestamp = "uci.version.version.@version[0].timestamp",
}
content_helper.getExactContent(cui)
local year= cui.timestamp
local current_year = (string.sub(year,1,4))

function proxy_get(path)
  local ret = proxy.get(path)
  if ret then
    return ret[1].value
  else
    return nil
  end
end

if ngx.req.get_method() == "POST" then
  local post_args = ngx.req.get_post_args()
  local redir_URL = "/"
  if post_args.do_signout then
    -- telmex remote user redirection
    local currentuser = ngx.ctx.session:getusername()
    local wanusers = proxy.getPN("uci.web.sessionmgr.@wandefault.users.", true)
    local iswanuser = "0"
    for i,v in ipairs(wanusers) do
      if v and v["path"] then
        local wanuser = proxy_get(v["path"] .. "value")
        local username = proxy_get("uci.web.user.@" .. wanuser .. ".name")
        if username == currentuser then
          iswanuser = "1"
          break
        end
      end
    end
    if iswanuser == "1" then
      local dmz_enabled = proxy_get("uci.firewall.redirectsgroup.@dmzredirects.enabled")
      local port_reserverd = "0"
      if dmz_enabled == nil then
        dmz_enabled = "0"
      end
      if dmz_enabled == "0" then
        local userredirects = proxy.getPN("uci.firewall.userredirect.", true)
        for i,v in ipairs(userredirects) do
          if v and v["path"] then
            local src_dport = proxy_get(v["path"] .. "src_dport")
            local enabled = proxy_get(v["path"] .. "enabled")
            if src_dport == "443" and enabled == "1" then
              port_reserverd = "1"
              break
            end
          end
        end
      end
      if dmz_enabled == "1" or port_reserverd == "1" then
          local wanip = proxy_get("rpc.network.interface.@wan.ipaddr")
          if wanip then
            redir_URL = string.format("https://%s:8090", wanip)
          end
      end
    end
    ngx.ctx.session:logout()
    -- Now we redirect to / until we find a better solution
    -- Otherwise, the current page might be rendered while the default user is not allowed to see it
    -- since the access was checked for the user "before" logging out
    -- TODO: find a more elegant solution, in session module?
    ngx.redirect(redir_URL);
  end
end

--Set the default language to Spanish
local headers = ngx.req.get_headers()
local cookies = headers['cookie']
local cookielanguage
if cookies then
  cookielanguage = string.match(cookies, 'webui_language=([%a%-]+);?')
end
if cookielanguage == nil then
  gettext.language("es-es")
end

local wifi_keys = {}
local wifi_aps = proxy.getPN("uci.wireless.wifi-ap.", true)
if wifi_aps then
  for i,v in ipairs(wifi_aps) do
    if v and v["path"] then
      wifi_keys[#wifi_keys+1] = proxy.get(v["path"] .. "wpa_psk_key")[1].value
    end
  end
end
local default_key = proxy.get("uci.env.var.default_key_r0_s0")[1].value

local wireless_keychange = 0
for i = 1, #wifi_keys do
  if(default_key ~= wifi_keys[i]) then
    wireless_keychange = 1
    break
  end
end

  ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
  <head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
    <meta name="Advanced" content="');  ngx.print( cui.advanced ); ngx.print('">\
    <link href="/css/gw.css" rel="stylesheet">\
    <link href="/css/responsive.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-min.js" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <title>');  ngx.print( T"Gateway" ); ngx.print('</title>\
  </head>\
\
<body>\
    ');  if web.isDemoBuild() then   ngx.print('\
        <div style="color: red; font-weight: bold; text-align: center; font-size:x-large; line-height:150%; background-color: yellow; border: 2px solid; border-color: red; border-radius: 4px;">Demo build, unofficial Technicolor SW, not suitable for deployment!</div>\
    ');  end   ngx.print('\
    ');  if (wireless_keychange ~= 1 ) then   ngx.print('\
        <div style="color: red; font-weight: bold; text-align: center; font-size:x-large; line-height:150%; background-color: yellow; border: 2px solid; border-color: red; border-radius: 4px;">');  ngx.print( T"WPA2 key is not changed. Please change the password." ); ngx.print('</div>\
    ');  end   ngx.print('\
  <div class="feedback">\
\
  </div>\
    <div class="container">\
    <div class="row">\
      <div class="header span12">\
        <a href="');  ngx.print( cui.nsplink ); ngx.print('" target="_blank"><img src="/img/logo.gif"></a>\
        ');  
        local session = ngx.ctx.session
        local html = {}

        html[#html + 1] = [[<div class="pull-right">]]
        if session:isdefaultuser() then
            html[#html + 1] = '<a href="login.lp" class="btn" id="signin">'
            html[#html + 1] = T"Sign in"
            html[#html + 1] = '</a>'
        else
            html[#html + 1] = [[          <div class="btn-group" id="logged">
                    <button class="btn"> ]]
            html[#html + 1] = session:getusername()
            html[#html + 1] = [[ </button>
                    <button class="btn dropdown-toggle" data-toggle="dropdown">
                      <span class="caret"></span>
                    </button>
                    <ul class="dropdown-menu pull-right">]]
            if session:getusername() ~= assistant:username() then
                html[#html + 1] = [[ <li><a tabindex="-1" href="/password.lp" id="changepass">]]
                html[#html + 1] = T"Change my password"
                html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
            end
            html[#html + 1] = [[ <li><a tabindex="-1" href="/" id="signout"> ]]
            html[#html + 1] = T"Sign out"
            html[#html + 1] = [[</a></li></ul></div>]]
        end
        html[#html + 1] = [[</div>]]

        html[#html + 1] = [[<div class="pull-right">]]
        html[#html + 1] = ui_helper.createLanguageSelect('webui-core', gettext.language())
        html[#html + 1] = [[</div>]]

        ngx.print(html)
          ngx.print('\
      </div>\
    </div>\
    <div class="row">\
      ');  
        local lp = require("web.lp")
        local cards = require("cards")
        for _,v in pairs(cards.cards()) do
          lp.include(v)
        end
        ngx.print('\
    </div>\
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print(' </p></div></div>\
  </div>\
  ');  
  if cookielanguage == nil then
     ngx.print('\
   <script type="text/javascript">\
     tch.setCookie("webui_language", "es-es", 30);\
   </script>\
   ');  
  end
    ngx.print('\
\
</body>\
</html>\
<script>\
var processMsg=\'');  ngx.print(T"Processing"); ngx.print('\';\
var openMsg = \'');  ngx.print(T"Model is opening..."); ngx.print('\';\
var waitMsg = \'');  ngx.print(T"Please wait..."); ngx.print('\';\
var loginMsg =\'');  ngx.print(T"Login Expired. Reloading."); ngx.print('\';\
var okButton = \'');  ngx.print(T"Ok"); ngx.print('\';\
var cancelButton = \'');  ngx.print(T"Cancel"); ngx.print('\';\
function httpErrorMessage(err){\
    switch(err.status){\
        case 500:\
            erromsg=\'');  ngx.print(T"Internal Server Error occured, please contact administrator"); ngx.print('\'\
            break;\
        case 404:\
            erromsg=\'');  ngx.print(T"The requested file is not found! Please try again after some time"); ngx.print('\'\
            break;\
        case 503:\
            erromsg=\'');  ngx.print(T"The server is currently unavailable, Please try again after some time"); ngx.print('\'\
            break;\
        case 408:\
            erromsg=\'');  ngx.print(T"The server timed out waiting for the request"); ngx.print('\'\
            break;\
        default:\
             erromsg=\'');  ngx.print(T"The request could not be performed due to some error"); ngx.print('\'\
    }\
    window.setTimeout(function(){\
      erromsg = \'<div style="margin-left:35%;margin-top:9%;"><span class="alert-error">\'+erromsg+\'</span></div>\';\
      var ht = $(\'.modal-body\').height();\
      ht = toString(ht).match(/\\d+/) > 230 ? ht:230;\
      $(\'.modal-body\').height(ht);\
      var tab = $(\'.modal-body ul\').html();\
      if(tab != undefined)\
        erromsg = \'<ul class="nav nav-tabs">\' + tab + \'</ul>\' + erromsg;\
      $(\'.modal-body\').html(erromsg);\
    },400);\
}\
</script>\
'); 