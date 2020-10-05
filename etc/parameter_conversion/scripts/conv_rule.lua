local uc = require("uciconv")
local o = uc.uci('old')
local n = uc.uci('new')


-- Deleting ekements and reconfig Robustnes increas
o:foreach('firewall', 'rule', function(s)

	if s.name and (string.match(s.name, 'Deny%-Lan%-SIP') or string.match(s.name, 'Deny%-Guest%-SIP')) then
		n:delete('firewall', s[".name"])
	end
	
	if s.name and (string.match(s.name, 'Allow%-restricted%-sip%-from%-wan%-again')) then
		local num =	string.match(s.name, "[%d]+")
		
		if tonumber(num)  <= 10 then 
		local src_ip
			if num == "1" then
				src_ip = '10.247.0.0/24'
			elseif num =="2" then
				src_ip = '10.247.1.0/24'
			elseif num =="3" then
				src_ip = '10.247.5.0/24'
			elseif num =="4" then
				src_ip = '10.247.30.0/24'
			elseif num =="5" then
				src_ip = '10.247.48.0/24'
			elseif num =="6" then
				src_ip = '10.247.49.0/24'
			elseif num =="7" then
				src_ip = '10.252.47.0/24'
			elseif num =="8" then
				src_ip = '10.252.48.0/24'
			elseif num =="9" then
				src_ip = '30.253.253.0/24'
			elseif num =="10" then
				src_ip = '10.252.50.0/24'
			end 	
		n:set('firewall',s[".name"], 'src_ip', src_ip)
		n:set('firewall',s[".name"], 'dest_port', '5060')
		else	
			n:delete('firewall', s[".name"])
		end
	end
	
end)


	
n:commit('firewall')
