--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-contentsharing')

local proxy = require("datamodel")
local uiHelper = require("web.ui_helper")
local postHelper = require("web.post_helper")
local contentHelper = require("web.content_helper")
local attributes = { span = { class = "span4" } }
local messageHelper = require("web.uimessage_helper")
local format = string.format


local mapParams = {
  printersharingEnabled = "uci.printersharing.config.enabled",
  sambasharingEnabled = "uci.samba.sambashare.@printers.enabled"
}

local mapValid = {
  printersharingEnabled = postHelper.validateBoolean,
  sambasharingEnabled = postHelper.validateBoolean
}

local content = postHelper.handleQuery(mapParams, mapValid)

local contentSamba = {
  sambaEnabled   = "uci.samba.sambashare.@printers.enabled",
  hostname        = "uci.system.system.@system[0].hostname",
  localdevIP      = "uci.network.interface.@lan.ipaddr"
}

contentHelper.getExactContent(contentSamba)
-- usb Devices
local usbdevColumms = {
  {
    header = T"Port",
    type = "text",
    readonly = true
  },
  {
    header = T"Product Name",
    type = "text",
    readonly = true
  },
  {
    header = T"Manufacturer",
    type = "text",
    readonly = true
  },
  {
    header = T"Version",
    type = "text",
    readonly = true
  }
}

local usbdevOptions = {
  tableid = "usbDev",
  basepath = "sys.usb.device.",
  canAdd = false,
  canEdit = false,
  canDelete = false
}

local usbpartData = {}
local function createUsbPartitionTable()
  local usbdevData = proxy.get("sys.usb.")
  if not usbdevData then
    return
  end

  local pathList = {}
  for _, usbdevValue in ipairs(usbdevData) do
    if usbdevValue.param == "bInterfaceClass" and usbdevValue.value == "07" then
      pathList[#pathList+1] = string.match(usbdevValue.path, "(sys.usb.device.%d+.)interface.%d+.$")
    end
  end

  for pathListIndex = 1, #pathList do
    usbpartData[pathListIndex] = {}
    for usbdevColumns = 1, #usbdevColumms, 1 do
      usbpartData[pathListIndex][usbdevColumns] = " "
    end
    local params =
    {
      [ "path" .. pathList[pathListIndex] ]  = 1,
      [ "product" .. pathList[pathListIndex] ] = 2,
      [ "manufacturer" .. pathList[pathListIndex] ] = 3,
      [ "version" .. pathList[pathListIndex] ] = 4
    }
    for _, usbdevValue in ipairs(usbdevData) do
      if usbdevValue.param and usbdevValue.path and params[usbdevValue.param .. usbdevValue.path] then
        usbpartData[pathListIndex][params[usbdevValue.param .. usbdevValue.path]] = usbdevValue.value
      end
    end --endof for usbdevData
  end   --endof for #pathList
end

createUsbPartitionTable()

local function concatPrinter(printerTable, delimiter)
  local result = ""
  for _, printerValue in ipairs(printerTable) do
    result = result .. delimiter .. printerValue
  end
  return result
end

local function removeDuplicateEntry(usbpartData)
  local tableDict, duplicateIndices = {}, {}
  -- Converts all nested tables into string and also to find all duplicate indices
  for usnpartIndex, usnpartValue in ipairs(usbpartData) do
    local key = concatPrinter(usnpartValue, "|")
    if not tableDict[key] then
      tableDict[key] = true
    else
      duplicateIndices[#duplicateIndices+1] = usnpartIndex
    end
  end
  -- Iteration over duplicate indices from backwards and removed the value
  for usnpartIndex = #duplicateIndices, 1, -1 do
    table.remove(usbpartData, duplicateIndices[usnpartIndex])
  end
  return usbpartData
end

removeDuplicateEntry(usbpartData)

  ngx.print('\
\
');  ngx.print( uiHelper.createHeader(T"Sharing", false, true, nil)); ngx.print('\
<div class = "modal-body update">\
  ');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-sharing.lp")
    ngx.print('\
  <form class = "form-horizontal" method = "post" action = "modals/printersharing-modal.lp">\
    ');  ngx.print( uiHelper.createMessages(messageHelper.popMessages())); ngx.print('\
    ');  
      local html = {}
      html[#html+1] = uiHelper.createSwitch(T"Enabled", "printersharingEnabled", ((content.printersharingEnabled ~= "0" and content.sambasharingEnabled ~= "0") and "1" or "0"), attributes)
      html[#html+1] = "<div class='control-group hide'><label class='control-label'>Enabled</label><div class='controls'><div id='personal-wireless-switch' class='switch {switchOn} pull-left'> <div class='switcher {switcherOn}'></div><input type='hidden' name='sambasharingEnabled' id = 'sambasharingEnabled'></div></div></div>"
      html[#html+1] = "<fieldset><legend>" .. T"Printer Information" .. "</legend>"
      html[#html+1] = uiHelper.createTable(usbdevColumms, usbpartData, usbdevOptions, nil)
      if content.printersharingEnabled == '1' then
        html[#html+1] = contentSamba.sambaEnabled == '1' and format(T'<div class=\" simple-desc span4\">To connect: \\\\%s\\ or \\\\%s\\</div>', contentSamba.localdevIP, contentSamba.hostname) or format(T'<div class=\" simple-desc span4\">Samba is disabled</div>')
      end
      html[#html+1] = "</fieldset>"
      ngx.print(html)
      ngx.print('\
  </form>\
</div>\
');  ngx.print(uiHelper.createFooter())   ngx.print('\
<script>\
  $("#printersharingEnabled").change("switcher" ,function() {\
    $("#sambasharingEnabled").val(document.getElementById("printersharingEnabled").value);\
  });\
</script>\
'); 