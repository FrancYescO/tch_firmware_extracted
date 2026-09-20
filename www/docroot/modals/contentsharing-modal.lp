<%
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
local format, find, sub = string.format, string.find, string.sub
local vNES = post_helper.validateNonEmptyString

-- Get the content_info
local content_info = {
	connecteddevices			= "uci.samba.status.@info.connecteddevices",
}
content_helper.getExactContent(content_info)

local mapParams = {
	samba_enabled		= "uci.samba.samba.@samba[0].enabled",
	samba_name			= "uci.samba.samba.@samba[0].name",
	samba_workgroup		= "uci.samba.samba.@samba[0].workgroup",
	samba_description	= "uci.samba.samba.@samba[0].description",
	minidlna_enabled	= "uci.minidlna.config.enabled",
	minidlna_friendly_name		= "uci.minidlna.config.friendly_name",
}

local mapValid = {
	samba_enabled = post_helper.getValidateCheckboxSwitch(),
	samba_name = post_helper.validateString,
	samba_workgroup = post_helper.validateString,
	samba_description = post_helper.validateString,
	minidlna_enabled = post_helper.getValidateCheckboxSwitch(),
	minidlna_friendly_name = post_helper.validateString,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)


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
local function createUsbPartitionTable()
    local usbdev_data = proxy.get("sys.usb.")
    if not usbdev_data then
        return
    end

    local path_list = {}
    for _, v in ipairs(usbdev_data) do
      if v.param == "path" and string.match(v.path,"sys.usb.device.%d+.partition.%d+.$") then
         path_list[#path_list+1] = v.path
      end
    end

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
      }
      for _, v in ipairs(usbdev_data) do
        if v.param and v.path and params_t[v.param .. v.path] then
          usbpart_data[i][params_t[v.param .. v.path]] = v.value
        end
        usbpart_data[i][4] = "High Power"
        usbpart_data[i][11] = ""
      end --endof for usbdev_data
    end   --endof for #path_list
end

createUsbPartitionTable()

local pageRefresh = nil

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. uri:match("/([^/]+)%.lp") }
%>

<%= ui_helper.createHeader(T"Content Sharing", true, true, pageRefresh, help_link)%>

<div class="modal-body update">
	<form class="form-horizontal" method="post" action="modals/contentsharing-modal.lp">
		<%
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
			tinsert(html, ui_helper.createCheckboxSwitch("File Server Enabled", "samba_enabled", content["samba_enabled"],attributes))
		    --tinsert(html, ui_helper.createLabel(T"File Server name: ", content["samba_name"], advancedhide))
			tinsert(html, ui_helper.createInputText(T"File Server name: ", "samba_name", content["samba_name"], advanced))
			tinsert(html, ui_helper.createInputText(T"File Server workgroup: ", "samba_workgroup", content["samba_workgroup"], advanced))
			tinsert(html, ui_helper.createInputText(T"File Server description: ", "samba_description", content["samba_description"], advanced))
			tinsert(html, ui_helper.createCheckboxSwitch("DLNA Enabled", "minidlna_enabled", content["minidlna_enabled"],attributes))
		    --tinsert(html, ui_helper.createLabel(T"DLNA name: ", content["minidlna_friendly_name"], advancedhide))
			tinsert(html, ui_helper.createInputText(T"DLNA name: ", "minidlna_friendly_name", content["minidlna_friendly_name"], advanced))
			tinsert(html, "</fieldset>")

            tinsert(html, "<fieldset><legend>" .. T"Hard Disk Information" .. "</legend><p>")
            if content_info.connecteddevices == "0"  or content_info.connecteddevices == '' then
	            tinsert(html, format(T'Currently there are <strong>%s</strong> connected devices', "no"))
	        elseif content_info.connecteddevices == "1" then
	            tinsert(html, format(T'Currently there is <strong>%s</strong> connected device', content_info.connecteddevices))
	        else
	            tinsert(html, format(T'Currently there are <strong>%s</strong> connected devices', content_info.connecteddevices))
	    	end
	    	tinsert(html, "</p></fieldset>")
            tinsert(html, ui_helper.createTable(usbdev_columms, usbpart_data, usbdev_options, nil, usbdev_helpmsg))
			ngx.print(html)
		%>

	</form>
</div>
<% ngx.print(ui_helper.createFooter()) %>
