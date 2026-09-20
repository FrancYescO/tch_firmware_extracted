--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local proxy = require("datamodel")
local match, format, untaint, tonumber = string.match, string.format, string.untaint, tonumber

local USBData = {
  USBDeviceCount = "sys.usb.DeviceNumberOfEntries"
}
content_helper.getExactContent(USBData)
local getproduct
local USBList
if tonumber(USBData["USBDeviceCount"]) and tonumber(USBData["USBDeviceCount"]) > 0 then
    usbList = proxy.get("sys.usb.device.")
    getproduct = content_helper.convertResultToObject("sys.usb.device.", usbList)
    if ngx.req.get_method() == "POST" then
      local postcontent = ngx.req.get_post_args()
      if postcontent["action"] == "reset" then
        proxy.set(format("sys.usb.device.%s.unmount", postcontent.usbindex), "1")
        local a,b = proxy.set(format("sys.usb.device.%s.unmount", postcontent.usbindex), "1")
        proxy.apply()
        ngx.sleep(2)
        require("web.sessioncontrol").reloadUsers()
        ngx.print("success")
        ngx.exit(ngx.HTTP_OK)
      end
    end
end
  ngx.print('\
<form id="usb-form">\
<h1><span>');  ngx.print(T"USB"); ngx.print('</span></h1>\
<h2><span>');  ngx.print(T"The router allows USB devices such as USB sticks, Hard Disk Drivers, UMTS sticks or printers, to be shared over your network. Mass storage devices with the following file system are supported: FAT16, FAT32 and NTFS."); ngx.print('</span></h2>\
<br>\
<h2><span>');  ngx.print(T"Below you find an overview of the currently attached USB devices."); ngx.print('</span></h2>\
<h3><span>');  ngx.print(T"Attached USB Devices"); ngx.print('</span></h3>\
<div class="h3-content vdf-table mobile-padding-bottom-lg">\
');  if tonumber(USBData["USBDeviceCount"]) and tonumber(USBData["USBDeviceCount"]) > 0 then
    for _,v in ipairs(getproduct) do  ngx.print('\
    <input type="hidden" name= "CSRFtoken" id="CSRFtoken" value = "');  ngx.print(CSRFtoken); ngx.print('"></input>\
    <input type="hidden" name= "action" id="action" value = "reset"></input>\
        <div class="vdf-row">\
        <input type="hidden" class="usbindex" name= "usbindex" id="usbindex" value="');  ngx.print(v.paramindex); ngx.print('">\
            <div class="left">\
                <span id="usb-product-name">');  ngx.print(v.product); ngx.print('</span>\
            </div>\
            <div class="right">\
                ');  for _, u in ipairs(usbList) do
                     if match(u.path, "sys.usb.device." .. v.paramindex .. ".interface.%d+.") and
                         u.param == "bInterfaceClass" and
                         u.value == "08" then   ngx.print('\
                          <input class="button-eject usb-btn-unmount" type="button" id="usb-btn-img">\
                    ');  end
                end  ngx.print('\
            </div>\
        </div>\
    ');  end  ngx.print('\
');  end  ngx.print('\
</div>\
</form>\
\
<script src="/js/global.js"> </script>\
<script>\
$(".usb-btn-unmount").click(function() {\
    var postData = [];\
    postData.push({\
      name : "usbindex",\
      value : $(this).closest(".vdf-row").find(".usbindex").val()\
     },{\
      name : "CSRFtoken",\
      value : "');  ngx.print( ngx.ctx.session:getCSRFtoken()); ngx.print('"\
     },{\
      name : "action",\
      value : "reset"\
     });\
    $.post("modals/usb.lp", postData)\
    $(this).closest(".vdf-row").remove();\
});\
\
</script>\
'); 