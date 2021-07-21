--pretranslated: do not change this file
 
local string = string

-- Enable localization
gettext.textdomain('webui-contentsharing')

local ipairs, ngx, pairs, tonumber, postData = ipairs, ngx, pairs, tonumber
local tinsert = table.insert
local proxy = require("datamodel")
local uiHelper = require("web.ui_helper")
local postHelper = require("web.post_helper")
local attributes = { span = { class = "span4" } }
local samba_fileshare_attributes = { switch = { id = "samba-fileshare" }, span = { class = "span4" } }
local contentHelper = require("web.content_helper")
local messageHelper = require("web.uimessage_helper")
local ajaxHelper = require("web.ajax_helper")
local getUsbLabel = require("usbmap").get_usb_label
local session = ngx.ctx.session
local role = session:getrole()

local format, match = string.format, string.match
local validNonEmpty = postHelper.validateNonEmptyString
local valEnumSel = postHelper.getValidateInEnumSelect
local valStrLength = postHelper.getValidateStringLengthInRange


-- Check availability of file, return true if found, else false
local function fileCheck(fileName)
  if not io.open(fileName,"r") then
    return false
  else
    return true
  end
end
if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "eject" then
  local path = format("sys.usb.device.%d.", ngx.req.get_post_args().ejectIndex)
  if proxy.set(path .. "unmount", "1") then
    proxy.apply()
    --Let ngx wait until complete USB mount successfully, otherwise the GUI table will display the ejected devices.
    local sec = 0
    repeat
      ngx.sleep(5)
      sec = sec + 5
      local result = proxy.get(path)
    until not result or sec >= 60
  else
    messageHelper.pushMessage(T"Error while ejecting USB disk", "error")
  end
end
-- Get the contentInfo
local mapParams = {}
local contentInfo = {}
local content = {}
local helpmsg = {}
local storageList = {
  { "0", T'LAN'},
}

if not postHelper.isFeatureEnabled("NoWanAccessforSamba") then
  storageList[#storageList + 1] = { "1" , T'LAN/WAN'}
end

local sambaAvailable = fileCheck("/etc/init.d/samba")
if sambaAvailable then
  local sambaMapParams = {
    samba     = "uci.samba.samba.enabled",
    sambaFilesharing = "uci.samba.samba.filesharing",
    sambaName        = "uci.samba.samba.name",
    sambaWorkgroup   = "uci.samba.samba.workgroup",
    sambaDescription = "uci.samba.samba.description",
    storageInterface = "uci.samba.userauth.wan_access",
    diskProtection   = "uci.samba.userauth.authentication",
    userName         = "uci.samba.userauth.username1",
    passWord         = "uci.samba.userauth.password1"
  }
  for sambaIndex, sambaValue in pairs(sambaMapParams) do
    mapParams[sambaIndex] = sambaValue
  end
  contentInfo = {
    connecteddevices  = "sys.usb.DeviceNumberOfEntries",
    localdevIP        = "uci.network.interface.@lan.ipaddr",
    usb3Available    = "rpc.system.usb3_available"
  }
  contentHelper.getExactContent(contentInfo)
end


local dlnaAvailable = fileCheck("/etc/init.d/dlnad")
if dlnaAvailable then
  local dlnaMapParams = {
    dlnaEnabled       = "uci.dlnad.config.enabled",
    dlnaFriendlyName = "uci.dlnad.config.friendly_name",
    dlnaDynamic       = "uci.dlnad.config.dynamic"
  }
  for dlnaIndex, dlnaValue in pairs(dlnaMapParams) do
    mapParams[dlnaIndex] = dlnaValue
  end
end

if contentInfo.usb3Available == "1" then
  mapParams.usb3Enabled = "uci.system.config.enable_usb3_support"
end

-- To check if the function does not contain special character or empty string
local function validSambaDlnaString(value)
  local rc, msg = validNonEmpty(value)
  if not rc then
    return rc, msg
  end
  if match(value, "[^%w _%-]") then
    return nil, T"Only alphanumeric, space, underscore and dash characters allowed"
  end
  return true
end

local usb3EnabledConfig = proxy.get("uci.system.config.enable_usb3_support")
usb3EnabledConfig = usb3EnabledConfig and usb3EnabledConfig[1] and usb3EnabledConfig[1].value or "0"
local function validUsb3Enabled(value, object)
  if usb3EnabledConfig == value or (usb3EnabledConfig == "" and value == "1") then
    object.usb3Enabled = nil
  end
  return postHelper.validateBoolean(value)
end

local function diskProtectionCheck(value, object, key)
  if postHelper.validateBoolean(value) then
    if object["storageInterface"] ~= "0" and value == "0" then
      return nil, T"If sharing is enabled on the WAN Interface Disk Protection must be enabled"
    end
  end
  return postHelper.validateBoolean(value)
end

local function dlnaDynamicCheck(value)
  if value == "" then
    value = "0"
  end
  return postHelper.validateBoolean(value)
end

local mapValid = {
  samba = postHelper.validateBoolean,
  sambaFilesharing = postHelper.validateBoolean,
  sambaName = postHelper.getOptionalValidation(validSambaDlnaString),
  sambaWorkgroup = postHelper.getOptionalValidation(validSambaDlnaString),
  sambaDescription = postHelper.getOptionalValidation(validSambaDlnaString),
  storageInterface = valEnumSel(storageList),
  userName = postHelper.getOptionalValidation(valStrLength(1,48)),
  passWord = postHelper.getOptionalValidation(valStrLength(1,64)),
  dlnaEnabled = postHelper.validateBoolean,
  dlnaFriendlyName = postHelper.getOptionalValidation(validSambaDlnaString),
  usb3Enabled = validUsb3Enabled,
  dlnaDynamic = dlnaDynamicCheck,
  diskProtection = diskProtectionCheck
}

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  postData = ngx.req.get_post_args()
  if dlnaAvailable and tonumber(postData.dlnaEnabled) == 1 then
    mapValid.dlnaFriendlyName = validSambaDlnaString
  end
  if sambaAvailable and tonumber(postData.sambaFilesharing) == 1 then
    mapValid.sambaName = validSambaDlnaString
    mapValid.sambaWorkgroup = postHelper.getAndValidation(validSambaDlnaString,valStrLength(1,16))
    mapValid.sambaDescription = validSambaDlnaString
  end
  if sambaAvailable and tonumber(postData.diskProtection) == 1 then
    mapValid.userName = postHelper.getAndValidation(validNonEmpty, valStrLength(1,48))
    mapValid.passWord = postHelper.getAndValidation(validNonEmpty, valStrLength(1,64))
  end
  content, helpmsg = postHelper.handleQuery(mapParams, mapValid)
end

if dlnaAvailable or sambaAvailable then
  content, helpmsg = postHelper.handleQuery(mapParams, mapValid)
end

-- usb Devices

local usbdevColumms = {
  {
    header = T"Product Name",
    type = "text",
    readonly = true
  },
  {
    header = T"Share",
    type = "text",
    readonly = true
  },
  {
    header = T"Volume Size",
    type = "text",
    readonly = true
  },
  {
    header = T"Free Space",
    type = "text",
    readonly = true
  },
  {
    header = T"Eject",
    type = "text",
    readonly = true
  },
}

local usbdevOptions = {
  tableid = "usbDev",
  basepath = "sys.usb.device.",
  canAdd = false,
  canEdit = false,
  canDelete = false
}

local usbDiskNumber = 0
local usbpartData = {}

local function getProfileStatus()
  local profileStatus = T"Idle"
  local usbdevData = proxy.get("sys.usb.")
  if not usbdevData then
    return profileStatus
  end
  local ready = false
  local profiling = false
  local idle = false
  for _, usbdevValue in ipairs(usbdevData) do
    if usbdevValue.param == "path" and match(usbdevValue.path, "sys.usb.device.%d+.partition.%d+.$") then
      -- don't show Extended partition
      local profileStatus = proxy.get(usbdevValue.path.."ProfileStatus")
      for profileIndex, _ in ipairs(profileStatus) do
        if profileStatus ~= nil and profileStatus[profileIndex]["value"] ~= nil and profileStatus[profileIndex]["value"] ~= "" then
          if profileStatus[profileIndex]["value"] == "Profiling" then
            profiling = true
            break
          elseif profileStatus[profileIndex]["value"] == "Ready" then
            ready = true
          elseif profileStatus[profileIndex]["value"] == "Idle" then
            idle = true
          end
        end
      end
      if profiling == true then
        break
      end
    end
  end
  profileStatus  = profiling and "Profiling" or idle and ready and "Profiling" or idle and T"Idle" or ready and T"Ready" or profileStatus
  return profileStatus
end

local function createUsbPartitionTable()
  local usbdevData = proxy.get("sys.usb.")
  if not usbdevData then
    return
  end
    local pathList, partitionCount, mobileIndex = {}, {}, ""
    for _, usbdevValue in ipairs(usbdevData) do
      if usbdevValue.param == "path" and match(usbdevValue.path,"sys.usb.device.%d+.partition.%d+.$") then
        -- don't show Extended partition
        local filesystem = proxy.get(usbdevValue.path.."FileSystem")
        if filesystem ~= nil and filesystem[1]["value"] ~= nil and filesystem[1]["value"] ~= "" then
           pathList[#pathList + 1] = usbdevValue.path
           local idx = match(usbdevValue.path, "sys.usb.device.(%d+).partition.%d+.$")
           partitionCount[idx] = partitionCount[idx] and partitionCount[idx] + 1 or 1
        end
      end
     if usbdevValue.param == "partitionOfEntries" and usbdevValue.value == "0" then
        mobileIndex = match(usbdevValue.path,"sys%.usb%.device%.(%d+)%.")
      end
      -- Device class "08":It will be considered as a Mass storage device if it contains partitions.
      if usbdevValue.param == "bInterfaceClass" and usbdevValue.value == "08" and mobileIndex ~= match(usbdevValue.path, "sys%.usb%.device%.(%d+)")then
        usbDiskNumber = usbDiskNumber + 1
      end
    end

  for pathlistIndex = 1, #pathList+usbDiskNumber do
    usbpartData[pathlistIndex] = {}
    for usbdevColumns = 1, #usbdevColumms, 1 do
      usbpartData[pathlistIndex][usbdevColumns] = " "
    end
  end

  local deviceIndex, port, isduplicatePath, index  = "", 0, {}, 0
  for pathlistIndex = 1, #pathList do
    index = index + 1
    local path = match(pathList[pathlistIndex], "(sys.usb.device.%d+.)partition.%d+.$")
    -- accorinding to isduplicatepath[path] to indicated if the eject line and project info had been added
    if not isduplicatePath[path] then
      local pathIndex = match(path, "sys.usb.device.(%d+).")
      -- Create eject button on 12th(last) Column of the table
      usbpartData[index][5] = uiHelper.createSimpleButton(T"Eject", "icon-eject", {button = {class = "eject", index = pathIndex}})
      index = index + 1
    end
    local params =
    {
      [ "product" .. path ] = 1,
      [ "Share".. pathList[pathlistIndex] ] = 2,
      [ "TotalSpace"..pathList[pathlistIndex] ] = 3,
      [ "AvailableSpace"..pathList[pathlistIndex] ] = 4,
    }
    for _, usbdevValue in ipairs(usbdevData) do
      if usbdevValue.param and usbdevValue.path and params[usbdevValue.param .. usbdevValue.path] then
        if usbdevValue.param == "path" then
          if deviceIndex =="" or deviceIndex == match(usbdevValue.path, "%d+") then
            port = port + 1
          else
            port = 1
          end
          usbpartData[index][params[usbdevValue.param .. usbdevValue.path]] = format("%s-%s", getUsbLabel(usbdevValue.value), port)
          deviceIndex = match(usbdevValue.path, "%d+")
        else
          --Set the product name on the row of eject button for the USB which contain partitions.
          --The params[usbdevValue.param .. usbdevValue.path] will return 2 if usbdevValue.path value is path of product.
          if not isduplicatePath[path] and params[usbdevValue.param .. usbdevValue.path] == 1 then
            usbpartData[index-1][params[usbdevValue.param .. usbdevValue.path]] = usbdevValue.value
            isduplicatePath[path] = true
          end
          usbpartData[index][params[usbdevValue.param .. usbdevValue.path]] = usbdevValue.value
        end
      end
    end --endof for usbdevData
    usbpartData[index][2] = format("\\\\%s\\%s", contentInfo.localdevIP, usbpartData[index][2])
  end   --endof for #pathList
end

createUsbPartitionTable()

local function convertReceivedData(content)
  if content.connecteddevices then
    if usbDiskNumber == 0 then
      content.connecteddevices = format(T'Currently there are <strong>%s</strong> connected devices', T"no")
    elseif usbDiskNumber == 1 then
      content.connecteddevices = format(T'Currently there is <strong>%d</strong> connected device', usbDiskNumber)
    else
      content.connecteddevices = format(T'Currently there are <strong>%d</strong> connected devices', usbDiskNumber)
    end
  end
end

ajaxHelper.handleAjaxQuery({
  connecteddevices = "sys.usb.DeviceNumberOfEntries",
}, function(content)
  convertReceivedData(content)
end)

convertReceivedData(contentInfo)

--local pageRefresh = nil
  ngx.print('\
\
');  ngx.print( uiHelper.createHeader(T"Sharing", true, true)); ngx.print('\
\
<div class = "modal-body update">\
  ');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-sharing.lp")
    ngx.print('\
  <form class = "form-horizontal" method = "post" action = "modals/contentsharing-modal.lp">\
    ');  
      ngx.print(uiHelper.createMessages(messageHelper.popMessages()))
      local html = {}
      local changes = {
        alert = {
          class = "alert alert-success hide",
          id = "success-msg"
        }
      }
      tinsert(html, uiHelper.createAlertBlock(T"Changes saved successfully", changes))
      tinsert(html, "<fieldset><legend>" .. T"General status" .. "</legend>")
      local advanced = {
	group = { class = "advanced hide"},
	span = { class = "span4" }
      }
      local advancedhide = {
	group = { class = "advanced show"},
	span = { class = "span4" }
      }
      local toggle = {
	span = { class = "span4" },
	input = {
	  id = "toggle-usb3",
        }
      }
      local warning = {
	span = { class = "span4" },
	alert = {
          class = "alert-warning hide",
	  id = "warning-msg"
      },
      }
      local rebootWarning = {
	span = { class = "span4" },
	alert = {
          class = "alert-warning hide",
	  id = "reboot-warning-msg"
        },
      }
      local rebooting = {
	alert = {
          class = "alert-warning hide",
	  id = "rebooting-msg"
	}
      }
      local sambamsg = {
        alert = {
          class = "alert-warning show",
          id = "samba-msg"
        }
      }
      local flagattr = {
	input = {
	  class = "hide",
	  id = "cs-flag"
        }
      }
      local samba_warning = {
        span = { class = "span4" },
        alert = {
          class = "alert-warning hide",
          id = "samba-warning-msg"
        },
      }
      local samba_fileshare_warning = {
        span = { class = "span4" },
        alert = {
          class = "alert-warning hide",
          id = "samba-fileshare-msg"
        }
      }
      local diskattr = {
	span = { class = "span4" },
	input = {
	  id = "disk-protection"
	}
      }
      local username = {
	input = {
	  maxlength = "48",
	  id = "disk-username",
	  class = "span4"
	}
      }
      local password = {
	input = {
	  maxlength = "64",
	  id = "disk-password",
	  class = "span4"
	}
      }

      if sambaAvailable then
        if content["sambaFilesharing"] == "1" and content["diskProtection"] == "0" then
           tinsert(html, uiHelper.createAlertBlock(T"If your device does not support unauthenticated Samba Access you will need to activate authentication to access your files.", sambamsg))
        end
        tinsert(html, uiHelper.createSwitch(T"Samba", "samba", (content["samba"] ~= "0" and "1" or "0"), attributes))
        tinsert(html, uiHelper.createAlertBlock(T"Toggling Samba support will disable and turn off Samba Filesharing", samba_warning))
        tinsert(html, uiHelper.createSwitch(T"Samba Filesharing", "sambaFilesharing", (content.sambaFilesharing ~= "0" and "1" or "0"), samba_fileshare_attributes))
        tinsert(html, uiHelper.createAlertBlock(T"Please enable Samba to turn on Samba Filesharing", samba_fileshare_warning))
	tinsert(html, uiHelper.createLabel(T"Samba name: ", content.sambaName, advancedhide))
	tinsert(html, uiHelper.createInputText(T"Samba name: ", "sambaName", content.sambaName, advanced, helpmsg.sambaName))
	tinsert(html, uiHelper.createInputText(T"Samba workgroup: ", "sambaWorkgroup", content.sambaWorkgroup, advanced, helpmsg.sambaWorkgroup))
	tinsert(html, uiHelper.createInputText(T"Samba description: ", "sambaDescription", content.sambaDescription, advanced, helpmsg.sambaDescription))
	tinsert(html, uiHelper.createInputSelect(T"Storage Interface", "storageInterface", storageList, (content["storageInterface"]), attributes))
	tinsert(html, uiHelper.createSwitch(T"Disk Protection", "diskProtection", content["diskProtection"] ~= "0" and "1" or "0", diskattr, helpmsg["diskProtection"]))
	tinsert(html, uiHelper.createInputText(T"ID:", "userName", content.userName, username, helpmsg.userName))
	tinsert(html, uiHelper.createInputText(T"Password:", "passWord", content.passWord, password, helpmsg.passWord))
      end
      if dlnaAvailable then
	tinsert(html, uiHelper.createSwitch(T"DLNA Enabled", "dlnaEnabled", content["dlnaEnabled"],attributes))
	tinsert(html, uiHelper.createLabel(T"DLNA name: ", content["dlnaFriendlyName"], advancedhide))
	tinsert(html, uiHelper.createInputText(T"DLNA name: ", "dlnaFriendlyName", content["dlnaFriendlyName"], advanced, helpmsg["dlnaFriendlyName"]))
        if postHelper.isFeatureEnabled("dlna", role) then
	  tinsert(html, uiHelper.createLabel(T"Profiler status: ", getProfileStatus()))
          local dlnaEnabled = proxy.get("uci.dlnad.config.enabled")[1].value
          if dlnaEnabled == "1" then
            tinsert(html, uiHelper.createSwitch(T"DLNA Dynamic", "dlnaDynamic", content["dlnaDynamic"],advanced))
          end
        end
      end
      if postHelper.isFeatureEnabled("usb3", role) then
        if contentInfo.usb3Available == "1" then
          tinsert(html, uiHelper.createSwitch(T"USB 3.1 Enabled", "usb3Enabled", (content.usb3Enabled ~= "" and content.usb3Enabled or "1"), toggle))
          tinsert(html, uiHelper.createAlertBlock(T"It is recommended to use the USB in the 2.0 standard. The use of USB in 3.1 standard can remarkably affect the Wi-Fi performance at 2.4 Ghz band.", warning))
          tinsert(html, uiHelper.createAlertBlock(T"Toggling USB3.1 support will reboot the Gateway", rebootWarning))
          tinsert(html, uiHelper.createAlertBlock(T"Restarting, please wait...", rebooting))
          tinsert(html, uiHelper.createSimpleInputText("csFlag", "0", flagattr))
        end
      end
      tinsert(html, "</fieldset>")

      if sambaAvailable then
	tinsert(html, "<fieldset><legend>" .. T"Hard Disk Information" .. "</legend>")
	tinsert(html, format("<div><div id=\"connecteddevices\" class=\" simple-desc span3 monitor-changes\" data-ajaxrefresh=\"5\">%s</div>", contentInfo["connecteddevices"]))
	tinsert(html, uiHelper.createTable(usbdevColumms, usbpartData, usbdevOptions, nil))
	tinsert(html, "</fieldset>")
      end
      ngx.print(html)
      ngx.print('\
  </form>\
</div>\
');  ngx.print(uiHelper.createFooter())   ngx.print('\
<script>\
var refreshTimeOut = 5000;\
var refreshDelay = 3000;\
var target = $(".modal form").attr("action");\
var usb3Support = "');  ngx.print(usb3EnabledConfig); ngx.print('";\
var rebootMsg = \'');  ngx.print( T"Rebooting..." ); ngx.print('\';\
\
var sambaChanged = function(hideWarning) {\
  if($("#samba").val() == "1") {\
    $("#samba-fileshare").addClass("enabled").removeClass("disabled");\
    if (hideWarning != true) {\
      $("#samba-warning-msg, #samba-fileshare-msg").addClass("hide");\
    }\
  } else {\
    if (hideWarning != true) {\
      $("#samba-warning-msg").removeClass("hide");\
    }\
    $("#samba-fileshare-msg").removeClass("hide");\
    $("#samba_filesharing").val("0");\
    $("#samba-fileshare").addClass("disabled").removeClass("enabled");\
  }\
}\
\
sambaChanged(true);\
$("#samba").change(sambaChanged);\
\
$("#usbDev .eject").click(function(){\
  var index = $(this).attr("index");\
  var tparam = [];\
  tparam.push({\
    name: "action",\
    value :"eject"\
  });\
  tparam.push({\
    name:  "ejectIndex",\
    value: index\
  });\
  tparam.push(tch.elementCSRFtoken());\
  tch.loadModal("/modals/contentsharing-modal.lp", tparam, function(){\
     tch.scrollRowIntoView("usbDev", 1);});\
});\
\
function warningMsg() {\
  if($("#toggle-usb3").val() === "1") {\
    $("#warning-msg").removeClass("hide");\
  } else {\
    $("#warning-msg").addClass("hide");\
  }\
  $("#reboot-warning-msg").removeClass("hide");\
  $("#cs-flag").val("1");\
  if(usb3Support === $("#toggle-usb3").val()) {\
    $("#warning-msg").addClass("hide");\
    $("#reboot-warning-msg").addClass("hide");\
  }\
}\
$("#toggle-usb3").change(function() {\
  warningMsg();\
});\
\
//Displaying disk credentials if disk-protection is enabled\
function disk_security() {\
  if ($("#disk-protection").val() === "1") {\
    $("#disk-username, #disk-password").parent().parent().removeClass("hide");\
  }\
  else {\
    $("#disk-username, #disk-password").parent().parent().addClass("hide");\
  }\
}\
\
disk_security();\
$("#disk-protection").change(function() {\
 disk_security();\
});\
\
$(document).on("click", "#save-config", function() {\
  if (($("#cs-flag").val() === "1") && (usb3Support !== $("#toggle-usb3").val())) {\
    $("#rebooting-msg").removeClass("hide");\
    $("#warning-msg").addClass("hide");\
    $("#reboot-warning-msg").addClass("hide");\
    $("#success-msg").addClass("hide");\
  }\
  else {\
    $("#success-msg").removeClass("hide");\
  }\
  $("#samba-warning-msg, #samba-fileshare-msg").addClass("hide");\
});\
\
$(function(){\
if(usb3Support != $("#toggle-usb3").val()){ \
  $("#cs-flag").val("1");\
  warningMsg();\
}\
});\
</script>\
'); 