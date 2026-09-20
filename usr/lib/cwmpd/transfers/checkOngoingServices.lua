local ubus = require("ubus")
local conn = ubus.connect()
local next = next
if not conn then return end

local function callOngoing()
	local calls = {}
	calls = conn:call("mmpbx.call", "get", {})
	if type(calls) == "table" then
		if next(calls) ~= nil then
			return true
		end
	end
	return false
end

-- see if the file exists                                                                                                                                      
function file_exists(file)                                                                                                                                     
  local f = io.open(file, "rb")                                                                                                                                
  if f then f:close() end                                                                                                                                      
  return f ~= nil                                                                                                                                              
end                                                                                                                                                            
                                                                                                                                                               
function vodOngoing(file)                                                                                                                                     
  if not file_exists(file) then return false end                                                                                                               
  for line in io.lines(file) do                                                                                                                                
    if string.find(line, "dport=5055") ~= nil then                                                                                                             
        return true                                                                                                                                            
    end                                                                                                                                                        
  end                                                                                                                                                          
                                                                                                                                                               
  return false                                                                                                                                                 
end                                                                                                                                                            
                                                                                                                                                               
while(callOngoing() or vodOngoing("/proc/net/nf_conntrack")) do
	os.execute("sleep 5")
end
