local ngx = ngx
local format, find, gsub, gmatch, sub = string.format, string.find, string.gsub, string.gmatch,string.sub
local content_helper = require("web.content_helper")


local M = {}
function M.get()
   --Path based to get the port from the active config
   local portlist =  {
       cwmpd = "uci.cwmpd.cwmpd_config.connectionrequest_port"
   } 
   content_helper.getExactContent(portlist)
   --Manual Port additions to block
   --portlist.ssh = "22"
   return portlist
end

return M