--pretranslated: do not change this file
 ngx.print('\
');  
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local lp = require("web.lp")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local dosProtectionData, dosProtectionPath = {}, {}
local valid
local json = require("dkjson")
local tonumber = tonumber

local dosProtectParams  = {
  globalEnabled         =    "uci.dosprotect.globals.enabled",
  wholeICMPFlood        =    "uci.dosprotect.icmplimits.global_limit",
  perSourceICMPFlood    =    "uci.dosprotect.icmplimits.per_srcip_limit",
  tcpSyncFlood          =    "uci.dosprotect.tcpsynlimits.global_limit",
  tcpPerSyncFlood       =    "uci.dosprotect.tcpsynlimits.per_srcip_limit",
  udpFlood              =    "uci.dosprotect.udplimits.global_limit",
  udpPerFlood           =    "uci.dosprotect.udplimits.per_srcip_limit",
  rpFilter              =    "uci.dosprotect.globals.rpfilter",
  tcpSyncWithData       =    "uci.dosprotect.globals.block_tcpsyn_withdata",
}

local burstValues = {
  icmpBurstLimit        =    "uci.dosprotect.icmplimits.global_burst",
  icmpPerScriptBurst    =    "uci.dosprotect.icmplimits.per_srcip_burst",
  tcpSynPerScriptBurst  =    "uci.dosprotect.tcpsynlimits.per_srcip_burst" ,
  tcpSynGlobalBurst     =    "uci.dosprotect.tcpsynlimits.global_burst",
  udpPerScriptBurst     =    "uci.dosprotect.udplimits.per_srcip_burst",
  udpGlobalBurst        =    "uci.dosprotect.udplimits.global_burst",
}

content_helper.getExactContent(burstValues)

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  local dosProtectionSet
  local postargs = ngx.req.get_post_args()
  -- For Whole System ICMP and Per-Source IP ICMP Flood value from GUI have to be SET to icmplimits and icmpv6limits, GET will be taken from icmplimits

  dosProtectParams["wholeICMPv6Flood"]       =  "uci.dosprotect.icmpv6limits.global_limit"
  dosProtectParams["perSourceICMPv6Flood"]   =  "uci.dosprotect.icmpv6limits.per_srcip_limit"
  dosProtectionData["globalEnabled"]         =  postargs.globalEnabled
  dosProtectionData["rpFilter"]              =  postargs.rpFilter
  dosProtectionData["tcpSyncWithData"]       =  postargs.tcpSyncWithData
  dosProtectionData["wholeICMPFlood"]        =  tonumber(postargs.wholeIcmpFlood) ~= 0 and postargs.wholeICMPFloodVal or postargs.wholeIcmpFlood
  dosProtectionData["wholeICMPv6Flood"]      =  tonumber(postargs.wholeIcmpFlood) ~= 0 and postargs.wholeICMPFloodVal or postargs.wholeIcmpFlood
  dosProtectionData["perSourceICMPFlood"]    =  tonumber(postargs.perSourceICMPFlood) ~= 0 and postargs.perSourceICMPFloodVal or postargs.perSourceICMPFlood
  dosProtectionData["perSourceICMPv6Flood"]  =  tonumber(postargs.perSourceICMPFlood) ~= 0 and postargs.perSourceICMPFloodVal or postargs.perSourceICMPFlood
  dosProtectionData["tcpSyncFlood"]          =  tonumber(postargs.tcpSyncFlood) ~= 0 and postargs.tcpSyncFloodVal or postargs.tcpSyncFlood
  dosProtectionData["tcpPerSyncFlood"]       =  tonumber(postargs.tcpPerSyncFlood) ~= 0 and postargs.tcpPerSyncFloodVal or postargs.tcpPerSyncFlood
  dosProtectionData["udpFlood"]              =  tonumber(postargs.udpFlood) ~= 0 and postargs.udpFloodVal or postargs.udpFlood
  dosProtectionData["udpPerFlood"]           =  tonumber(postargs.udpPerFlood) ~= 0 and postargs.udpPerFloodVal or postargs.udpPerFlood

  if tonumber(dosProtectionData["wholeICMPFlood"]) <= tonumber(burstValues["icmpBurstLimit"]) and
     tonumber(dosProtectionData["perSourceICMPFlood"]) <= tonumber(burstValues["icmpPerScriptBurst"]) and
     tonumber(dosProtectionData["tcpSyncFlood"]) <= tonumber(burstValues["tcpSynGlobalBurst"]) and
     tonumber(dosProtectionData["tcpPerSyncFlood"]) <= tonumber(burstValues["tcpSynPerScriptBurst"]) and
     tonumber(dosProtectionData["udpPerFlood"]) <= tonumber(burstValues["udpPerScriptBurst"]) then
      valid = true
  end

  if valid then
    dosProtectionSet = content_helper.setObject(dosProtectionData, dosProtectParams)
    if dosProtectionSet then
      proxy.apply()
      ngx.print('<input type="hidden" id="post_status" value="success">')
    end
  else
    ngx.print('<input type="hidden" id="post_status" value="error">')
  end
end
content_helper.getExactContent(dosProtectParams)
local resetParams = {
  dosProtect     = "uci.uci-defaults.dos.dosprotect",
  icmpGlobal     = "uci.uci-defaults.dos.icmpglobal_limit",
  icmpPerScript  = "uci.uci-defaults.dos.icmpper_srcip_limit",
  tcpGlobal      = "uci.uci-defaults.dos.tcpglobal_limit",
  tcpPerScript   = "uci.uci-defaults.dos.tcpper_srcip_limit",
  udpGlobal      = "uci.uci-defaults.dos.udpglobal_limit",
  udpPerScript   = "uci.uci-defaults.dos.udpper_srcip_limit",
  IPrpfilter     = "uci.uci-defaults.dos.IPrpfilter",
  tcpSynWithData = "uci.uci-defaults.dos.tcpsyn_withdata",
}
content_helper.getExactContent(resetParams)
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")  ngx.print('\
\
<div id="content-reset-wrap" class="clearfix">\
  <div class="white-background">\
    <form id="dos-form" class="form-horizontal" method="post" action="/modals/internet/dos.lp" autocomplete="off">\
      <input type="hidden" name= "CSRFtoken" id= "CSRFtoken" value = "');  ngx.print(CSRFtoken); ngx.print('"></input>\
      <input type="hidden" name= "action" id= "action" value = "SAVE"></input>\
      <div id="content" class="content-dos">\
        <h1><span>');  ngx.print(T"Denial of Service"); ngx.print('</span></h1>\
        <h2><span>');  ngx.print(T"Placeholder text for category description"); ngx.print('</span></h2>\
        <div class="h3-content no-padding-bottom mobile-no-float vdf-table">\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Denial of Service"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <div id="globalEnabled" class="button ');  if dosProtectParams.globalEnabled == "1" then  ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' toggle-content-button"></div>\
            </div>\
          </div>\
        </div>\
\
        <div id="dos-enabled-option" class="dosexposed" ');  if dosProtectParams.globalEnabled == "0" then  ngx.print('style="display:none"');  end  ngx.print('>\
          <div class="h3-content dos mobile-no-float vdf-table">\
            <div class="vdf-row">\
              <div class="left">\
                <span>');  ngx.print(T"Whole System ICMP Flood"); ngx.print('</span>\
              </div>\
              <div class="right">\
                <input type="text" name="wholeICMPFloodVal" class="max4 wsif doswholeIcmpFlood" id="wholeICMPFloodVal" value = "');  ngx.print(dosProtectParams.wholeICMPFlood); ngx.print('" ');  if dosProtectParams.wholeICMPFlood == "0" then   ngx.print(' style="display:none" ');  end  ngx.print('>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\
                <label for="pks" class="wsif doswholeIcmpFlood" ');  if dosProtectParams.wholeICMPFlood == "0" then   ngx.print(' style="display:none" ');  end  ngx.print('> <span>');  ngx.print(T"Packets per Second"); ngx.print('</span>\
                </label>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\
                <div id="wholeIcmpFlood" class="button ');  if dosProtectParams.wholeICMPFlood ~= "0" then   ngx.print('button-on ');  else  ngx.print(' button-off ');  end  ngx.print('toggle-content-button"></div>\
              </div>\
            </div>\
            <div class="vdf-row">\
              <div class="left">\
                <span>');  ngx.print(T"Per-Source IP ICMP Flood"); ngx.print('</span>\
              </div>\
              <div class="right">\
                <input type="text" name="perSourceICMPFloodVal" class="max4 psisf dosperSourceICMPFlood" id="perSourceICMPFloodVal" value = "');  ngx.print(dosProtectParams.perSourceICMPFlood); ngx.print('" ');  if dosProtectParams.perSourceICMPFlood == "0" then   ngx.print(' style="display:none"  ');  end  ngx.print(' >&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\
                <label for="pks" class="psisf dosperSourceICMPFlood" ');  if dosProtectParams.perSourceICMPFlood == "0" then   ngx.print(' style="display:none" ');  end  ngx.print('> <span>');  ngx.print(T"Packets per Second"); ngx.print('</span>\
                </label>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\
                <div id="perSourceICMPFlood" class="button ');  if dosProtectParams.perSourceICMPFlood ~= "0" then   ngx.print('button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' toggle-content-button"></div>\
              </div>\
            </div>\
            <div class="vdf-row">\
              <div class="left">\
                <span>');  ngx.print(T"Whole System TCP-SYN Flood"); ngx.print('</span>\
              </div>\
              <div class="right">\
                <input type="text" name="tcpSyncFloodVal" class="max4 wstsf dostcpSyncFlood" id="tcpSyncFloodVal" value="');  ngx.print(dosProtectParams.tcpSyncFlood); ngx.print('" ');  if dosProtectParams.tcpSyncFlood == "0" then   ngx.print(' style="display:none"  ');  end  ngx.print('>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\
                <label for="pks" class="wstsf dostcpSyncFlood" ');  if dosProtectParams.tcpSyncFlood == "0" then   ngx.print(' style="display:none"  ');  end  ngx.print('> <span>');  ngx.print(T"Packets per Second"); ngx.print('</span>\
                </label>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\
                <div id="tcpSyncFlood" class="button  ');  if dosProtectParams.tcpSyncFlood ~= "0" then   ngx.print('button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' toggle-content-button" id="wstsf"></div>\
              </div>\
            </div>\
            <div class="vdf-row">\
              <div class="left">\
                <span>');  ngx.print(T"Per-Source IP TCP-SYN Flood"); ngx.print('</span>\
              </div>\
              <div class="right">\
                <input type="text" name="tcpPerSyncFloodVal" class="max4 wstsf dostcpPerSyncFlood" id="tcpPerSyncFloodVal" value="');  ngx.print(dosProtectParams.tcpPerSyncFlood); ngx.print('" ');  if dosProtectParams.tcpPerSyncFlood == "0" then   ngx.print(' style="display:none"  ');  end  ngx.print('>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\
                <label for="pks" class="wstsf dostcpPerSyncFlood" ');  if dosProtectParams.tcpPerSyncFlood == "0" then   ngx.print(' style="display:none"  ');  end  ngx.print('> <span>');  ngx.print(T"Packets per Second"); ngx.print('</span>\
                </label>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\
                <div id="tcpPerSyncFlood" class="button  ');  if dosProtectParams.tcpPerSyncFlood ~= "0" then   ngx.print('button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' toggle-content-button" id="wstsf"> </div>\
              </div>\
            </div>\
            <div class="vdf-row">\
              <div class="left">\
                <span>');  ngx.print(T"Whole System UDP Flood"); ngx.print('</span>\
              </div>\
              <div class="right">\
                <input type="text" name="udpFloodVal" class="max4 wstsf dosudpFlood" id="udpFloodVal" value="');  ngx.print(dosProtectParams.udpFlood); ngx.print('" ');  if dosProtectParams.udpFlood == "0" then   ngx.print(' style="display:none"  ');  end  ngx.print('>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\
                <label for="pks" class="wstsf dosudpFlood" ');  if dosProtectParams.udpFlood == "0" then   ngx.print(' style="display:none"  ');  end  ngx.print('> <span>');  ngx.print(T"Packets per Second"); ngx.print('</span>\
                </label>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\
                <div id="udpFlood" class="button  ');  if dosProtectParams.udpFlood ~= "0" then   ngx.print('button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' toggle-content-button" id="wstsf"></div>\
              </div>\
            </div>\
            <div class="vdf-row">\
              <div class="left">\
                <span>');  ngx.print(T"Per-Source IP UDP Flood"); ngx.print('</span>\
              </div>\
              <div class="right">\
                <input type="text" name="udpPerFloodVal" class="max4 wstsf dosudpPerFlood" id="udpPerFloodVal" value="');  ngx.print(dosProtectParams.udpPerFlood); ngx.print('" ');  if dosProtectParams.udpPerFlood == "0" then   ngx.print(' style="display:none"  ');  end  ngx.print('>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\
                <label for="pks" class="wstsf dosudpPerFlood" ');  if dosProtectParams.udpPerFlood == "0" then   ngx.print(' style="display:none"  ');  end  ngx.print('> <span>');  ngx.print(T"Packets per Second"); ngx.print('</span>\
                </label>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\
                <div id="udpPerFlood" class="button  ');  if dosProtectParams.udpPerFlood ~= "0" then   ngx.print('button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' toggle-content-button" id="wstsf"></div>\
              </div>\
            </div>\
            <div class="vdf-row">\
              <div class="left">\
                <span>');  ngx.print(T"ICMP Smurf"); ngx.print('</span>\
              </div>\
              <div class="right">\
                <span id="dosProtectICMPSmurf">Enabled</span>\
              </div>\
            </div>\
            <div class="vdf-row">\
              <div class="left">\
                <span>');  ngx.print(T"IP Fragmentation"); ngx.print('</span>\
              </div>\
              <div class="right">\
                <span id="dosProtectIPFragment">Enabled</span>\
              </div>\
            </div>\
            <div class="vdf-row">\
              <div class="left">\
                <span>');  ngx.print(T"IP Land/IP Spoof"); ngx.print('</span>\
              </div>\
              <div class="right">\
                <div id="rpFilter" class="button ');  if dosProtectParams.rpFilter == "1" then  ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' toggle-content-button"></div>\
              </div>\
            </div>\
            <div class="vdf-row">\
              <div class="left">\
                <span>');  ngx.print(T"TCP SynWithData"); ngx.print('</span>\
              </div>\
              <div class="right">\
                <div id="tcpSyncWithData" class="button ');  if dosProtectParams.tcpSyncWithData == "1" then  ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' toggle-content-button"></div>\
              </div>\
            </div>\
          </div>\
        </div>\
      </div>\
    </form>\
  </div>\
</div>\
\
');  
  lp.include("apply-cancel.lp")
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
\
<script>\
  var icmpBurstLimit       = "');  ngx.print(burstValues.icmpBurstLimit); ngx.print('"\
  var icmpPerScriptBurst   = "');  ngx.print(burstValues.icmpPerScriptBurst); ngx.print('"\
  var tcpSynGlobalBurst    = "');  ngx.print(burstValues.tcpSynGlobalBurst); ngx.print('"\
  var tcpSynPerScriptBurst = "');  ngx.print(burstValues.tcpSynPerScriptBurst); ngx.print('"\
  var udpGlobalBurst       = "');  ngx.print(burstValues.udpGlobalBurst); ngx.print('"\
  var udpPerScriptBurst    = "');  ngx.print(burstValues.udpPerScriptBurst); ngx.print('"\
  var resetParams          = ');  ngx.print(json.encode(resetParams)); ngx.print('\
</script>\
<script src="/js/global-min.js" ></script>\
<script src="js/internet/dos.js"></script>\
\
'); 