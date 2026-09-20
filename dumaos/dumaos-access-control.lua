#!/usr/bin/lua
package.path=package.path..";/dumaos/api/?.lua;/dumaos/api/libs/?.lua"require"ubus"json=require"json"local l="com.netdumasoftware.devicemanager"local i=ubus.connect()function process_device(n,e)return{wireless=e.wifi==1,name=e.ghost,mac=e.mac,id=n.devid,blocked=n.block and true or false}end
function case_insensetive_compare(n,e)return string.lower(n)==string.lower(e)end
function rpc_call(l,n,e)e=e or{}local n={proc=n}for r,e in ipairs(e)do
n[tostring(r)]=e
end
local e=i:call(l,"rpc",n)if e.eid then
return false
else
return true,e.result
end
end
function get_all_devices()local e,n=rpc_call(l,"get_all_devices")assert(e,"Error fetching devices")local e={}for r,n in ipairs(n[1])do
for l,r in ipairs(n.interfaces)do
table.insert(e,process_device(n,r))end
end
return e
end
function get_blocked_devices()local e=get_all_devices()local n={}for r,e in ipairs(e)do
if e.blocked then
table.insert(n,e)end
end
return n
end
function get_allowed_devices()local n=get_all_devices()local e={}for r,n in ipairs(n)do
if not n.blocked then
table.insert(e,n)end
end
return e
end
function is_device_blocked(e)local n=get_blocked_devices()for r,n in ipairs(n)do
if case_insensetive_compare(n.mac,e)then
return true
end
end
return false
end
function change_device_blocked_status(r,n)local e=get_all_devices()for i,e in ipairs(e)do
if case_insensetive_compare(e.mac,r)then
return rpc_call(l,"block_device",{e.id,n and"true"or"false"})end
end
return false
end
function block_device(e)return change_device_blocked_status(e,true)and"1"or"0"end
function allow_device(e)return change_device_blocked_status(e,false)and"1"or"0"end
function allow_all_devices()local n=get_blocked_devices()local e=true
for r,n in ipairs(n)do
local n,r=rpc_call(l,"block_device",{n.id,"false"})e=e and n
end
return e
end
function stringify_devices(e)local n=tostring(#e)for r,e in ipairs(e)do
n=n..string.format("@%s;%s;%s;%s",r-1,e.mac,e.name,e.wireless and"wireless"or"wired")end
return n
end
local function n(e)e=e or""if(string.match(e,"^%s+$"))then
return true
end
return e==""end
require"libtable"local function r(...)local e={...}for r,e in pairs(e)do
if(not n(e))then
return e
end
end
return""end
local function a(n,l)assert(#n.interfaces==1)local e=n.interfaces[1]local n={name=r(n.uhost,e.dhost,e.ghost),type=r(n.utype,e.dtype,e.gtype),id=n.devid,mac=e.mac,connectType=e.wifi==0 and"wired"or"wireless",status=n.block and"Block"or"Allow",online=false}for l,r in pairs(l)do
if(string.lower(r.mac)==string.lower(e.mac))then
n.ips=r.ips
n.online=(#r.ips)>0
n.ssid=r.ssid
n.wireless_speed=r.freq
break
end
end
return n
end
local function o()local e,n,i,r
local c={}e,n=rpc_call(l,"get_all_devices")assert(e,"Error fetching devices")i=n[1]e,n=rpc_call(l,"get_online_interfaces")assert(e,"Error fetching online interfaces")r=n[1]for n,e in pairs(i)do
table.insert(c,a(e,r))end
return c
end
function get_handler(e)if e=="all-block"then
return stringify_devices(get_blocked_devices())elseif e=="all-allow"then
return stringify_devices(get_allowed_devices())elseif e=="attachDevice"then
return json.encode(o())else
if is_device_blocked(e)then
return"block"else
return"allow"end
end
end
local e={{command="get",handler=get_handler},{command="block",handler=block_device},{command="allow",handler=allow_device},{command="delete-all-block",handler=allow_all_devices}}for e,n in ipairs(e)do
if n.command==arg[1]then
local e={}for n=2,#arg do
table.insert(e,arg[n])end
print(n.handler(unpack(e)))return
end
end
print("0")