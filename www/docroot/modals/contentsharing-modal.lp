--pretranslated: do not change this file
 
local istainted = string.istainted

-- Enable localization
gettext.textdomain('webui-contentsharing')

local tinsert = table.insert
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local attributes = { span = { class = "span4" } }
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local get_usb_label = require("usbmap").get_usb_label

local format, find, sub = string.format, string.find, string.sub
local vNES = post_helper.validateNonEmptyString

-- Check availability of file, return true if found, else false
local function file_check(file_name)
  local file_found=io.open(file_name, "r")      
  if file_found==nil then
  	return false
  else
  	return true
  end
end

-- Get the content_info
local mapParams = {}
local content_info = {}
local content = {} 
local helpmsg  = {}

local samba_available = file_check("/etc/init.d/samba")
if samba_available then
	local sambaMapParams = {
		samba_filesharing	= "uci.samba.samba.filesharing",
		samba_name			= "uci.samba.samba.name",
		samba_workgroup		= "uci.samba.samba.workgroup",
		samba_description	= "uci.samba.samba.description",
	}
    for k,v in pairs(sambaMapParams) do
        mapParams[k] = v
    end
	content_info = {
		connecteddevices			= "sys.usb.DeviceNumberOfEntries",
		localdevIP 			= "uci.network.interface.@lan.ipaddr",
	}
	content_helper.getExactContent(content_info)
end


local dlna_available = file_check("/etc/init.d/dlnad")
if dlna_available then
	local dlnaMapParams = {
		dlna_enabled		= "uci.dlnad.config.enabled",
		dlna_friendly_name	= "uci.dlnad.config.friendly_name",
	}
    for k,v in pairs(dlnaMapParams) do
        mapParams[k] = v
    end
end
local mapValid = {
	samba_filesharing = post_helper.validateBoolean,
	samba_name = vNES,
	samba_workgroup = vNES,
	samba_description = vNES,
	dlna_enabled = post_helper.validateBoolean,
	dlna_friendly_name = vNES,
}

if dlna_available or samba_available then
	content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
end

-- usb Devices

local usbdev_columms = {
  {
     header = T"Port",
     type = "text",
     readonly = true,
  },
  {
     header = T"Product Name",
     type = "text",
     readonly = true,
  },
  {
     header = T"Manufacturer",
     type = "text",
     readonly = true,
  },
  {
     header = T"Power",
     type = "text",
     readonly = true,
  },
  {
     header = T"Version",
     type = "text",
     readonly = true,
  },
  {
     header = T"File System",
     type = "text",
     readonly = true,
  },
  {
     header = T"Total Space",
     type = "text",
     readonly = true,
  },
  {
     header = T"Used Space",
     type = "text",
     readonly = true,
  },
  {
     header = T"Free Space",
     type = "text",
     readonly = true,
  },
  {
     header = T"Volume",
     type = "text",
     readonly = true,
  },
  {
     header = T"Share",
     type = "text",
     readonly = true,
  },
}

local usbdev_options = {
    tableid = "usbDev",
    basepath = "sys.usb.device.",
    canAdd = false,
    canEdit = false,
    canDelete = false,
}

local usbpart_data = {}
local usb_disk_number = 0
local function createUsbPartitionTable()
    local usbdev_data = proxy.get("sys.usb.")
    if not usbdev_data then
        return
    end

    local path_list = {}
    for _, v in ipairs(usbdev_data) do
      if v.param == "path" and string.match(v.path,"sys.usb.device.%d+.partition.%d+.$") then
         -- don't show Extended partition
         local filesystem = proxy.get(v.path.."FileSystem")
         if filesystem ~= nil and filesystem[1]["value"] ~= nil and filesystem[1]["value"] ~= "" then
            path_list[#path_list+1] = v.path
         end
      end
      -- Device class "08": Mass storage (MSC or UMS). It indicates the device is a disk.
      if v.param == "bInterfaceClass" and v.value == "08" then
        usb_disk_number = usb_disk_number + 1
      end
    end

    local deviceIndex, port = "",0
    for i=1, #path_list do
      usbpart_data[i]={}
      for j=1,#usbdev_columms,1 do
        usbpart_data[i][j] = " "
      end
      local path = string.match(path_list[i],"(sys.usb.device.%d+.)partition.%d+.$")
      local params_t =
      {
        [ "path" ..path ]  = 1,
        [ "product" .. path ] = 2,
        [ "manufacturer" .. path ] = 3,
        [ "power" .. path ] = 4,
        [ "version" .. path ] = 5,
        [ "FileSystem" .. path_list[i] ] = 6,
        [ "TotalSpace" .. path_list[i] ] = 7,
        [ "UsedSpace" ..  path_list[i] ] = 8 ,
        [ "AvailableSpace" .. path_list[i] ] = 9,
        [ "Volume".. path_list[i] ] = 10,
        [ "Share".. path_list[i] ] = 11,
      }
      for _, v in ipairs(usbdev_data) do
        if v.param and v.path and params_t[v.param .. v.path] then
          if v.param == "path" then
            if deviceIndex =="" or deviceIndex == string.match(v.path,"%d+") then
              port=port+1
            else
              port=1
            end
            usbpart_data[i][params_t[v.param .. v.path]] = format("%s-%s",get_usb_label(v.value),port)
            deviceIndex = string.match(v.path,"%d+")
          else
            usbpart_data[i][params_t[v.param .. v.path]] = v.value
          end
      end
        usbpart_data[i][4] = "High Power"
      end --endof for usbdev_data
      usbpart_data[i][11]=string.format("\\\\%s\\%s", content_info.localdevIP, usbpart_data[i][11])
    end   --endof for #path_list
end

createUsbPartitionTable()

function convertReceivedData(content)
	if content["connecteddevices"] then
		if usb_disk_number == 0 then
			content["connecteddevices"] = format(T'Currently there are <strong>%s</strong> connected devices', "no")
		elseif usb_disk_number == 1 then
			content["connecteddevices"] = format(T'Currently there is <strong>%d</strong> connected device', usb_disk_number)
		else
			content["connecteddevices"] = format(T'Currently there are <strong>%d</strong> connected devices', usb_disk_number)
		end
	end
end

ajax_helper.handleAjaxQuery({
		connecteddevices = "sys.usb.DeviceNumberOfEntries",
	}, function(content)
		convertReceivedData(content)
	end)

convertReceivedData(content_info)

--local pageRefresh = nil
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Content Sharing", true, true)); ngx.print('\
\
<div class="modal-body update">\
	<form class="form-horizontal" method="post" action="modals/contentsharing-modal.lp">\
		');  
			ngx.print(ui_helper.createMessages(message_helper.popMessages()))
			local html = {}

			tinsert(html, "<fieldset><legend>" .. T"General status" .. "</legend>")
			local advanced = {
				group = { class = "advanced hide"},
				span = { class = "span4" } 
			}
			local advancedhide = {
				group = { class = "advanced show"},
				span = { class = "span4" } 
			}
			if samba_available then
				tinsert(html, ui_helper.createSwitch(T"Samba Filesharing", "samba_filesharing", content["samba_filesharing"],attributes))
				tinsert(html, ui_helper.createLabel(T"Samba name: ", content["samba_name"], advancedhide))
				tinsert(html, ui_helper.createInputText(T"Samba name: ", "samba_name", content["samba_name"], advanced))
				tinsert(html, ui_helper.createInputText(T"Samba workgroup: ", "samba_workgroup", content["samba_workgroup"], advanced))
				tinsert(html, ui_helper.createInputText(T"Samba description: ", "samba_description", content["samba_description"], advanced))
			end
			if dlna_available then
				tinsert(html, ui_helper.createSwitch(T"DLNA Enabled", "dlna_enabled", content["dlna_enabled"],attributes))
				tinsert(html, ui_helper.createLabel(T"DLNA name: ", content["dlna_friendly_name"], advancedhide))
				tinsert(html, ui_helper.createInputText(T"DLNA name: ", "dlna_friendly_name", content["dlna_friendly_name"], advanced))
			end
			tinsert(html, "</fieldset>")

			if samba_available then
				tinsert(html, "<fieldset><legend>" .. T"Hard Disk Information" .. "</legend>")
				tinsert(html, T"Supported format" .. ": <strong>FAT16, FAT32, NTFS, HFS+, EXT2, EXT3</strong>")
				tinsert(html, format("<div><div id=\"connecteddevices\" class=\" simple-desc span3 monitor-changes\" data-ajaxrefresh=\"5\">%s</div>", content_info["connecteddevices"]))
				tinsert(html, ui_helper.createTable(usbdev_columms, usbpart_data, usbdev_options, nil, usbdev_helpmsg))
				tinsert(html, "</fieldset>")
			end
			ngx.print(html)
		  ngx.print('\
	</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 