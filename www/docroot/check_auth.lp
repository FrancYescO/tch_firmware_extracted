--pretranslated: do not change this file

--[[
   Check Page - For Auth
   A:David Relf
   E:david.relf@technicolor.com

   
   V1.0 - Initial version with Change control
]]
local format, match, sub= string.format, string.match, string.sub
local print= ngx.print
-- Enable localization

local session = ngx.ctx.session
local authd = "1"
if session:isdefaultuser() then
  authd = "0"
end
local JSON = {AUTH=authd}
local html = {}
for k,v in pairs(JSON) do 
    html[#html+1] = format("\"%s\":\"%s\"",k,v) 
    html[#html+1] = ","
end
table.remove(html, #html)
ngx.print('{', html, '}')


