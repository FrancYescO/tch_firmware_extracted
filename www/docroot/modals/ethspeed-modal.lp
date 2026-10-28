--pretranslated: do not change this file
 
  -- Localization
  gettext.textdomain('webui-core')

  local ngx = ngx
  local ui_helper = require("web.ui_helper")
  local post_helper = require("web.post_helper")
  local speedValidatation = post_helper.getValidateInEnumSelect
  local proxy = require("datamodel")
  local match = string.match
  local message_helper = require("web.uimessage_helper")

  local mapParams = {
    eth0 = "uci.ethernet.port.@eth0.speed"
  }

  local speedSelect = {
    { "auto", T'Auto'},
    { "100", T'100'}
  }

  local mapValid = {
    eth0 = speedValidatation(speedSelect),
    ethPorts = speedValidatation(speedSelect)
  }

  local portsValue = {}
  local portStatus = proxy.get("sys.eth.port.")
  for _, statusVal in ipairs(portStatus) do
    if statusVal["param"] == "status"  and statusVal["value"] ~= "" then
      portsValue [match(statusVal["path"], "sys.eth.port.@(eth%d)")] = statusVal["value"]
    end
  end
  local ethPorts = {
    {"eth0", "eth0"},
  }
  local ethportCount = 0
  for i = 1, 4 do
    local ethPort = "eth" .. i
    local path = "uci.ethernet.port.@" .. ethPort .. "."
    local speedCheck = proxy.get(path .. "speed")
    if speedCheck ~= nil then
      ethportCount = ethportCount + 1
      table.insert(ethPorts, {ethPort, ethPort})
      mapParams[ethPort] = path .. "speed"
    end
  end
  for i = 1, ethportCount do
    mapValid["eth" .. i] = speedValidatation(speedSelect)
  end
  local params, _ = post_helper.handleQuery(mapParams, mapValid)
  ngx.print(ui_helper.createHeader(T"ETH Linespeed", false, true))
  ngx.print('\
<form class = "modal-body form-horizontal" method = "post" action = "modals/ethspeed-modal.lp">\
  ');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))  ngx.print('\
  <fieldset>\
    <legend>');  ngx.print( T"ETH-WAN Linespeed" ); ngx.print('</legend>\
       ');  for ethVal,v in ipairs(ethPorts) do
         if ethVal == 4 and portsValue["eth" .. ethVal] == "up" then
           ngx.print(ui_helper.createInputSelect(T"ETH Linespeed", "eth" .. ethVal, speedSelect, params["eth" .. ethVal]))
         end
       end   ngx.print('\
  </fieldset>\
  <fieldset>\
    <legend>');  ngx.print( T"ETH-LAN Linespeed" ); ngx.print('</legend>\
      ');  
        local html = {}
          local ethCount = 0
          for _, v in ipairs(ethPorts) do
            if ethCount ~= 4 and portsValue["eth" .. ethCount] == "up"  then
              html[#html+1] = ui_helper.createInputSelect(T"LAN " .. ethCount .. " Linespeed", "eth" .. ethCount, speedSelect, params["eth" .. ethCount])
            end
            ethCount = ethCount+1
          end
        ngx.print(html)
        ngx.print('\
  </fieldset>\
</form>\
');  ngx.print(ui_helper.createFooter())  ngx.print('\
'); 