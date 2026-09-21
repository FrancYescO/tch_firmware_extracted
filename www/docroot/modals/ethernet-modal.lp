<%
--NG-????? ResetButton and friendlyName on LAN-Interface Page
--NG-71196 IPv6 Button pppoe realm
--NG-71457
--NG-73647 changes reloads pppoe
--NG-78292 DHCP server disabled after reset
--NG-72728
--NG-68986 a revert been done
--NG-83015 IPv6
-- Localization
gettext.textdomain('webui-core')

-- Process POST query
local bit = require("bit")
local proxy = require("datamodel")
local pairs, string ,ipairs, ngx = pairs, string, ipairs, ngx
local session = ngx.ctx.session
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local uinetwork = require("web.uinetwork_helper")
--NG-68986 local hosts_ac = uinetwork.getAutocompleteHostsList()  and next line added 
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()

local tonumber, tostring = tonumber, tostring
local content, helpmsg
local match, format  = string.match, string.format
local find, untaint = string.find, string.untaint
local ipv42num = post_helper.ipv42num
local broadcast_ip =post_helper.ipv42num("255.255.255.255")

local clear_network_stats = {
    controls = {
      class = "clear_network_stats"
    },
	group = {
       class = "advanced hide"
    },
    button = {
      ["data-name"] = "action",
      ["data-value"] = "RESET"
    }
}
-- Shortcuts to validation helpers to make lines shorter
local aIPV = post_helper.advancedIPValidation
local vB = post_helper.validateBoolean
local vIP4N = post_helper.validateIPv4Netmask
local vQTN = post_helper.validateQTN
local gAV = post_helper.getAndValidation

--NG-68986 starting
local ww = require("web.web")
local ipv6_pattern = "%x*:%x*:%x*:%x*:%x*:%x*:%x*:%x*"

function getAutocompleteHostsList(hosts)
    local ipv4hosts={}
    local ipv6hosts={}

    for i,v in ipairs(hosts) do
        if v.FirewallZone == "LAN" then
            local name = ww.html_escape(v.HostName)
            local iplist = ww.html_escape(v.IPAddress)
            local macaddr = ww.html_escape(v.MACAddress)
            local friendlyName

            --Get the IPv4 hosts
            local ip = iplist:match("%d+%.%d+%.%d+%.%d+") -- match first IPv4 in list (will have to do for now)
            if ip then
                if name == "" then
                        friendlyName = ip
                else
                        friendlyName = name .. " (" .. ip .. ")"
                end
                friendlyName = friendlyName .. " [" .. macaddr .. "]"
                ipv4hosts[friendlyName] = ip
            end

            --Get the IPv6 hosts
            for ipv6 in iplist:gmatch(ipv6_pattern) do
                if ipv6 then
                    if name == "" then
                        friendlyName = ipv6
                    else
                        friendlyName = name .. "(" .. ipv6 .. ")"
                    end
                    friendlyName = friendlyName .. " [" .. macaddr .. "]"
                    ipv6hosts[friendlyName] = ipv6
                end
            end
        end
    end
    return ipv4hosts, ipv6hosts
end

--NG-68986 ending

local hosts_mac = {}
--NG-68986for k, v in pairs(hosts_ac) do
--NG-68986    local mac = match(k, "%[(.*)%]")
--NG-68986    hosts_mac[#hosts_mac+1] = {mac, mac}
local hosts_ac = {}
local syshosts_data = proxy.get("sys.hosts.host.")

if type(syshosts_data) == "table" then
    hostlist = content_helper.convertResultToObject("sys.hosts.host.", syshosts_data)
    if hostlist then
        hosts_ac = getAutocompleteHostsList(hostlist)
        for k, v in pairs(hosts_ac) do
            local mac = match(k, "%[(.*)%]")
            hosts_mac[#hosts_mac+1] = {mac, mac}
        end
     end
end

hosts_mac[#hosts_mac+1] = {"custom",T"custom"}

local function num2ipv4(ip)
    local ret = bit.band(ip, 255)
    ip = bit.rshift(ip,8)
    for i=1,3 do
        ret = bit.band(ip,255) .. "." .. ret
        ip = bit.rshift(ip,8)
    end
    return ret
end

local getargs = ngx.req.get_uri_args()
local getintf = getargs.intf

local curintf = "lan"
-- Get all the LAN interfaces
local net_intfs_path = "rpc.network.interface."
local all_intfs = content_helper.convertResultToObject(net_intfs_path .. "@.", proxy.get(net_intfs_path))
local wireless_radio = {}
for i,v in ipairs(proxy.getPN("rpc.wireless.ssid.", true)) do
  local radios = match(v.path, "rpc%.wireless%.ssid%.@([^%.]+)%.")
  if radios then
    wireless_radio[radios] = true
  end
end
local lan_intfs = {}
local pppIntf, pppDev
for k,v in ipairs(all_intfs) do
    if v.type == "lan" and (not find(v["ppp.ll_intf"], "wl") or wireless_radio[untaint(v["ppp.ll_intf"])])then
         if v.name and v.name ~= "" then
            lan_intfs[#lan_intfs + 1] = {name = v.name, index = v.paramindex}
         else
            lan_intfs[#lan_intfs + 1] = {name = v.paramindex, index = v.paramindex}
         end
    end
    if v.paramindex == getintf then
        curintf = v.paramindex
        pppDev = v["ppp.ll_dev"]
        pppIntf = v["ppp.ll_intf"]
    end
end

----------------------------------reset function-------------------------------------
local function restdhcp()
local file = io.open("/rom/etc/uci-defaults/tch_0035-network-lan","r")
io.input(file)
local lanip = ""
local lanmask = ""
local checkup = 0
	while checkup == 0 do
	local line = io.read()
		if line ~= nil and (lanip == "" or lanip == nil) then
			lanip=match(line,"uci set network%."..curintf.."%.ipaddr%=([%d]+%.[%d]+%.[%d]+%.[%d]+)")
		end
		if line ~= nil and (lanmask == "" or lanmask == nil) then
			lanmask=match(line,"uci set network%."..curintf.."%.netmask%=([%d]+%.[%d]+%.[%d]+%.[%d]+)")
		end
		if lanip ~= "" and lanip ~= nil and lanmask ~= "" and lanmask ~= nil  then
			checkup=1
			io.close(file)
		elseif line == nil then
			checkup=2
			io.close(file)
		end
	end
	if checkup == 2 then
	local file2 = io.open("/lib/functions/uci-defaults.sh","r")
	io.input(file2)
		while checkup == 2 do
			local line = io.read()
			if line ~= nil and (lanip == "" or lanip == nil) then
				lanip=match(line,"set network%."..curintf.."%.ipaddr%=%'([%d]+%.[%d]+%.[%d]+%.[%d]+)%'")
			end
			if line ~= nil and (lanmask == "" or lanmask == nil) then
				lanmask=match(line,"set network%."..curintf.."%.netmask%=%'([%d]+%.[%d]+%.[%d]+%.[%d]+)%'")
			end
			if lanip and lanip ~= "" and lanmask and lanmask ~= "" or line == nil then
				checkup=5
				io.close(file2)
			end
		end
	end
	
	local founddev = 0
	local ipstart = ""
	local ipend = ""
	local ltime = ""
	local dhcpign = ""
	local fp = io.open("/rom/etc/config/dhcp", "r")
	local pattern = format("config dhcp %s",curintf)
	io.input(fp)
		while founddev == 0 do
			local line =io.read()
			if match(line,pattern) then
				while founddev == 0 do
				line =io.read()
					if line ~= nil and (ipstart == "" or ipstart == nil) then
						ipstart= match(line,"option start[%s]+'([%d]+)'")
					end
					if line ~= nil and (ipend == "" or ipend == nil) then
						ipend= match(line,"option limit[%s]+'([%d]+)'")
					end
					if line ~= nil and (ltime == "" or ltime == nil) then
						ltime= match(line,"option leasetime[%s]+'([%w]+)'")
					end
					if line ~= nil and (dhcpign == "" or dhcpign == nil) then
						dhcpign= match(line,"option ignore[%s]+'([%d]+)'")
					end
					if line == nil or match(line, "config dhcp") or ipstart~= nil and ipstart~="" and ipend ~= nil and ipend ~="" and ltime ~= nil and ltime ~="" and dhcpign ~= nil and dhcpign ~="" then
						founddev = 1
					end
				end
			end
			if line == nil then
				founddev = 1
				
			end
		end
		io.close(fp)
		if dhcpign == nil or dhcpign == "" then
			dhcpign = "0"
		end
	return lanip, lanmask, ipstart, ipend, ltime, dhcpign
end
------------------------------------reset end-----------------------------------------------------------------

-- Static leases
local sleases_columns = {
  {
    header = T"Hostname",
    name = "sleases_name",
    param = "name",
    type = "text",
    attr = { input = { class="span2", maxlength="63" } },
  },
  {
    header = T"MAC address",
    name = "sleases_mac",
    param = "mac",
    type = "select",
    values = hosts_mac,
    attr = { input = { class="span2", maxlength="17", id= "lease_mac" }, autocomplete=hosts_mac },
    unique = true,
  },
  {
    header = T"IP",
    name = "sleases_ip",
    param = "ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15"}, autocomplete=hosts_ac },
    unique = true,
  },
  {
    header = "",
    name = "sleases_owner",
    param = "owner",
    type = "hidden",
    readonly = true,
    attr = { },
  },
}

local function sleases_name_validation(value)
  if #value == 0 or #value > 63 then
    return nil, T"A hostname must be between 1 and 63 characters"
  end
  if match(value, "[^%w%-]") or not match(value, "%w") then
    return nil, T"A hostname must contain only alphanumeric characters with/without dash"
  end
  return true
end

local function sleases_mac_validation(value, object, key)
  local r1, r2 = post_helper.validateStringIsMAC(value)
  if r1 then
    if string.lower(value) == "ff:ff:ff:ff:ff:ff" then
        return nil, T"The requested MAC address can't be the broadcast MAC"
    else
        object[key] = string.lower(value)
    end
  end
  return r1, r2
end

local function sleases_ip_validation(value, object, key)
    local errCode, errMsg = post_helper.validateStringIsIP(value, object, key)
    if(errCode == nil) then
        return errCode, errMsg
    end

    local result = proxy.get("uci.network.interface.@" .. curintf .. ".ipaddr")[1].value
    if(value == result) then
        return nil, T"The requested IP can't be the same as the gateway IP"
    end

    local networkAddress = session:retrieve("networkAddr")

    if value == networkAddress then
        return nil, T"The requested IP can't be the Network Address"
    end

    local baseip = ipv42num(result)

    result = proxy.get("uci.network.interface.@" .. curintf .. ".netmask")[1].value
    local mask = ipv42num(result)

    local ip = ipv42num(value)

    if(bit.band(ip, 255) == 255) then
        return nil, T"The requested IP can't be the broadcast IP"
    end

    if(bit.band(ip, mask) == bit.band(baseip, mask)) then
        return true
    end
    return nil, T"The requested IP is not in the same subnet as the gateway"
end

local sleases_valid = {
    sleases_name = sleases_name_validation,
    sleases_mac = gAV(sleases_mac_validation,vQTN),
    sleases_ip = gAV(sleases_ip_validation,vQTN),
}

local sleases_options = {
    tableid = "sleases",
    basepath = "uci.dhcp.host.",
    createMsg = T"Add new static lease",
}


local sleases_filter = function(data)
    if data['owner'] == "portforward" then
        local path
        if syshosts_data then
            for _, v in pairs(syshosts_data) do
                if v.value == data['mac'] then
                    path = v.path
                    break
                end
            end
            for _, v in pairs(syshosts_data) do
                if v.path == path and v.param == "HostName" then
                    data['name'] = v.value
                    break
                end
            end
        end
        return { canEdit = false, canDelete = false }
    end
    return true
end

local sleases_data, sleases_helpmsg = post_helper.handleTableQuery(sleases_columns, sleases_options, sleases_filter, nil, sleases_valid)

if ngx.var.request_method == "POST" then
  post_data = ngx.req.get_post_args()
  if ( post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-EDIT"  or  post_data.action == "TABLE-ADD") then
    local text_mac_index = tonumber(post_data.index)
    local text_mac
    if  post_data.action == "TABLE-ADD" then
      text_mac = post_data["sleases_mac"]
    else
      text_mac = sleases_data[text_mac_index][2]
    end
    local flag = true
    for _,j in ipairs(hosts_mac) do
      if text_mac == j[1] then
        flag = false
        break
      end
    end
    if flag   then
      sleases_columns[2] = {
        header = T"MAC address",
        name = "sleases_mac",
        param = "mac",
        type = "text",
        attr = { input = { class="span2", maxlength="17", id= "lease_mac", value = text_mac }},
        unique = true,
      }
    end
  end

end

local cur_dhcp_intf = "lan"
local dhcp_intfs_path = "uci.dhcp.dhcp."
local all_dhcp_intfs = content_helper.convertResultToObject(dhcp_intfs_path .. "@.", proxy.get(dhcp_intfs_path))

for k,v in ipairs(all_dhcp_intfs) do
    if v.interface == curintf then
        cur_dhcp_intf = v.paramindex
        break
    end
end
-- Standard parameters
local mapParams = {
    dhcpStart = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".start",
    dhcpLimit = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".limit",
    dhcpState = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".ignore",
    leaseTime = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".leasetime",
    localdevIP = "uci.network.interface.@" .. curintf .. ".ipaddr",
    localdevmask = "uci.network.interface.@" .. curintf .. ".netmask",
}

if curintf == "lan" then
	mapParams.localIPv6 = "uci.network.interface.@" .. curintf .. ".ipv6"
end

localIP6assign = "uci.network.interface.@" .. curintf .. ".ip6assign"

local dnsIndex
local dhcp = {}
local baseDHCPOptions = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcp_option."
local dnsRemoved = false

-- Check if there is a custom DNS server, if so, then retrieve its index
-- we'll update the parameters list to include it for retrieval
dhcp.options = proxy.get(baseDHCPOptions)
dnsIndex = #dhcp.options + 1 -- by default index is end of list

for i,v in ipairs(dhcp.options) do
    if v.value:find("^6,") == 1 then
        dnsIndex = tonumber(string.match(v.path, "%.@(%d+)%.$"))
    end
end

local function validateDNS(value, object, key)
    -- If there is no value, then we want to delete the dhcp_option if it exists
    -- Otherwise, we want to check the value is an IP
    if value == "" then
        -- if the key does not exist, no harm done
        proxy.del(mapParams[key]:sub(1,-6))
        -- remove the value, there is nothing to set
        object[key] = nil
        dnsRemoved = true
        return true
    else
        local dns = {}
        for ip_Address in string.gmatch(value, '([^,]+)') do
          dns[#dns + 1] = ip_Address
	  local valid, helpmsg_validip = post_helper.validateStringIsIP(ip_Address, object, key)
	  if valid then
	     -- Check for Limited Broadcast IP Address and "0.0.0.0" IP Address
             local ipAddr = ipv42num(ip_Address)
	     if ipAddr == broadcast_ip or ipAddr == 0 then
		return nil, T"Invalid IP Address"
            end
          else
	    return nil, helpmsg_validip
          end
        end
        if #dns > 3 then
            return nil, nil
        end
        object[key] = "6," .. value -- DHCP option for DNS server is option 6
        return true
    end
end

function isQtnGuestWiFi(intf)
  if wireless_radio[untaint(intf)] then
     local radio = proxy.get(format("rpc.wireless.ssid.@%s.radio", intf))
     local isRemote = proxy.get(format("rpc.wireless.radio.@%s.remotely_managed", radio[1].value))
     if isRemote and isRemote[1].value == "1" then
        for _, v in ipairs(proxy.getPN("rpc.wireless.ap.", true)) do
          local isGuest = proxy.get(v.path.."ap_isolation")
          if isGuest and isGuest[1].value == "1" then
            return true
          end
        end
     end
  end
end

local function validateIPv6(value, object, key)
    local valid, msg = post_helper.validateBoolean(value, object, key)
    if valid and value ~= proxy.get("uci.network.interface.@" .. curintf .. ".ipv6")[1].value then
	local envIPv6 = proxy.get("uci.env.var.ppp_realm_ipv6")[1].value
	local envIPv4 = proxy.get("uci.env.var.ppp_realm_ipv4")[1].value
	local pppuser = "uci.network.interface.@wan.username"
	local device = proxy.get("uci.network.device.")
	local devifn = content_helper.convertResultToObject("uci.network.device.",device)
	local devindex = {}
	for i,v in ipairs(devifn) do
			devindex[#devindex+1] = v.paramindex
	end
        if value == "0" then
			proxy.set(pppuser, envIPv4)
			proxy.set("uci.network.interface.@wan.ipv6", value)
			proxy.set("uci.network.interface.@wan6.auto", value)
			proxy.apply()
			for i, v in ipairs(devindex) do
				proxy.set("uci.network.device."..v..".ipv6", value)
			end
			for i,v in pairs(lan_intfs) do
				if curintf ~= v.index then
				proxy.set("uci.network.interface.@"..v.index..".ipv6", value)
				end
			end
            -- In case we disable IPv6, we must first invalidate the existing prefix so that local devices know not to use IPv6 anymore
            -- Do this here by set the ip6assign pref and only on ipv6 state change
            local ipv6 = proxy.get(mapParams["localIPv6"]) -- get current value in datamodel to know if we're switching state
            if ipv6 and ipv6.value ~= "0" then -- default is enabled so anything non 0 is enabled
                proxy.set(IP6assign, "0") -- the value will be set back to its current value by process_query
                proxy.apply()
                ngx.sleep(3) -- ugly but need to give it the time to complete
            end
        elseif value == "1" then
			proxy.set(pppuser, envIPv6)
			proxy.set("uci.network.interface.@wan.ipv6", value)
			proxy.set("uci.network.interface.@wan6.auto", value)
						for i, v in ipairs(devindex) do
				proxy.set("uci.network.device."..v..".ipv6", value)
			end
			for i,v in pairs(lan_intfs) do
				if curintf ~= v.index then
				proxy.set("uci.network.interface.@"..v.index..".ipv6", value)
				end
			end
		end
        if isQtnGuestWiFi(pppDev) then
            local ucipath = content_helper.getMatchedContent("uci.network.device.",{ifname = pppIntf})
            if ucipath and #ucipath > 0 then
               proxy.set(ucipath[1].path .. "ipv6", value)
            end
        end
        -- Modify IPv6 at WAN-side accordingly:
        -- this is especially necessary to make sure Neighbor Solicitation (for DAD etc.) messages are sent upon network reload
        proxy.apply()
    end
    return valid, msg
end

local function validateLeaseTime(value, postdata, key)
   local success, msg = post_helper.validateStringIsLeaseTime(value)
   if success then
     postdata["leaseTime"] = match(untaint(value), "^0*([1-9]%d*[smhdw]?)$")
     return true
   else
     return nil, msg
   end
end
--[[
Function calculateDHCPStartAddress, Calculating DHCPStartaddress using localdeviceip, netmask, newstart and newlimit value. function returns DHCPStartAddress, DHCPEndAddress  and NetworkAddress
]]
local function calculateDHCPStartAddress (baseip, netmask, start, numips)
    local network = bit.band(baseip, netmask)
    local ipmax = bit.bor(network, bit.bnot(netmask)) - 1
    local ipstart = bit.bor(network, bit.band(start, bit.bnot(netmask)))
    local ipend = ipstart+numips-1
    ipstart = num2ipv4(ipstart)
    if ipend > ipmax then
      ipend = ipmax
    end
    ipend = num2ipv4(ipend)
    network = num2ipv4(network)
  return ipstart,ipend,network
end

local function getDHCPData(object)
  -- Check the entered IP is valid IP and convert it to number
  local baseip = post_helper.validateStringIsIP(object["localdevIP"]) and ipv42num(object["localdevIP"])
  local netmask = post_helper.validateStringIsIP(object["localdevmask"]) and ipv42num(object["localdevmask"])
  local dhcpstart = post_helper.validateStringIsIP(object["dhcpStartAddress"]) and ipv42num(object["dhcpStartAddress"])
  local dhcpend = post_helper.validateStringIsIP(object["dhcpEndAddress"]) and ipv42num(object["dhcpEndAddress"])

  return baseip, netmask, dhcpstart, dhcpend
end

-- Validation is done for the dhcpLimit for the particular subnet
-- If different subnet mask is given other than 255.255.255.0, then the
-- DHCP Range limit has to be calculated from the new subnet and the validation
-- has to be done for the new limit.
local function validateLimit(value, object)
  if match(value, "^[0-9]*$") then
    local baseip, netmask, dhcpstart, dhcpend = getDHCPData(object)

    if not dhcpend then
       return nil, T"DHCP End Address is Invalid"
    end

    if baseip and netmask and dhcpstart then
      local network = bit.band(baseip, netmask)
      local ipmax = bit.bor(network, bit.bnot(netmask))
      local numips = dhcpend - dhcpstart + 1
      local limit = ipmax - network - 1

      if dhcpend == ipmax then
          return nil, T"Broadcast Address should not be used"
      end

      local validatorNumberInRange = post_helper.getValidateNumberInRange(1,limit)
      local limitvalue =  validatorNumberInRange(numips)
      if not limitvalue then
          return nil, T"DHCP End Address is not valid in Subnet Range"
      end
      return true
    else
      return nil
    end
  else
    return nil, T"DHCP End Address is Invalid"
  end
end

-- Validation is done for the DHCP start Address for the particular subnet
-- For different subnets, validation for dhcpStart Address has to be done
-- from the new DHCP Range with respect to the subnet mask & Network Address
local function validateDHCPStart(value, object)
  -- If changing only the Local IP Address in basic mode, do not validate the start Address
  -- and proceed with the existing start offset and dhcpLimit for DHCP Range calculations.
  if object["isAdvanced"] == "0" then
     return true
  else
    if match(value, "^[0-9]*$") then
      local baseip, netmask, dhcpstart, dhcpend = getDHCPData(object)

      if not dhcpstart then
         return nil, T"DHCP Start Address is Invalid"
      end

      if baseip and netmask and dhcpend then
        local network = bit.band(baseip, netmask)
        local ipmax = bit.bor(network, bit.bnot(netmask))
        local start = dhcpstart - network
        local numips = dhcpend - dhcpstart + 1

        local limit = ipmax - network - 1

        local validatorNumberInRange = post_helper.getValidateNumberInRange(1,limit)

        if dhcpstart == baseip then
           return nil, T"DHCP Start Address should not be Local Device IP Address"
        elseif dhcpstart == network then
           return nil, T"DHCP Start Address should not be a Network Address"
        end

        local val = validatorNumberInRange(start)
        if not val then
            return nil, T"DHCP Start Address is not valid in Subnet Range"
        end

        -- Setting the dhcpStart and dhcpLimit from the calculated DHCP Range
        object["dhcpStart"] = tostring(start)
        object["dhcpLimit"] = tostring(numips)

        return true
      else
        return nil
      end
    else
      return nil, T"DHCP Start Address is Invalid"
    end
  end
end

-- This function will validate the Modem IP Address and check for
-- Valid IP Format, Limited Broadcast Address, Public IP Range, Multicast Address Range
local function validateGWIP(value, object, key)
   local val, errmsg = aIPV(value, object, key)

   if not val then
      return nil, errmsg
   end

   local ip = ipv42num(value)

    for _,intf in pairs(lan_intfs) do
      if intf.index ~= curintf then
        local ipaddr = proxy.get("uci.network.interface.@" .. intf.index .. ".ipaddr")[1].value
        local mask = proxy.get("uci.network.interface.@" .. intf.index .. ".netmask")[1].value
        local baseip = post_helper.validateStringIsIP(ipaddr) and ipv42num(ipaddr)
        local netmask = post_helper.validateStringIsIP(mask) and ipv42num(mask)

        local network, ipmax
        if baseip and netmask then
          network = bit.band(baseip, netmask)
          ipmax = bit.bor(network, bit.bnot(netmask))
        end

	if network and ipmax then
	  if ip >= network and ip <= ipmax then
          return nil, T"Gateway IP should not be in " .. intf.name .. T" IP Range"
    end
	end
      end
   end

   if ip >= ipv42num("10.0.0.0") and ip <= ipv42num("10.255.255.255") or
      ip >= ipv42num("172.16.0.0") and ip <= ipv42num("172.31.255.255") or
      ip >= ipv42num("192.168.0.0") and ip <= ipv42num("192.168.255.255") then
        return true
   else
      return nil, T"Public IP Range should not be used"
   end
end

local mapValid = {
    localdevIP = validateGWIP,

    dnsServer = validateDNS,
    leaseTime = validateLeaseTime,
    localdevmask = post_helper.getAndValidation(vIP4N,post_helper.validateStringIsIP),
    dhcpStart = validateDHCPStart,
    dhcpLimit = validateLimit,
    dhcpState = vB,
}
if curintf == "lan" then
	mapParams.localIPv6 = "uci.network.interface.@" .. curintf .. ".ipv6"
	mapValid.localIPv6 = validateIPv6
end


-- This is quite convoluted but I only found this way to get it to work.
-- getExactContent will return an error if we access an unknown instance
-- so we cannot load from uci an option if it does not exist
-- in the end we only add the parameter to the parameters list if:
--    - it exists (get or post)
--    - we're doing a post -> in this case, we add an entry and delete it if validation fails
if (dnsIndex < #dhcp.options +1) or ( (ngx.var.request_method == "POST") and (ngx.req.get_post_args().action == "SAVE") ) then
    mapParams["dnsServer"] = baseDHCPOptions .. "@" .. dnsIndex .. ".value"
end
if (dnsIndex == #dhcp.options + 1) and (ngx.var.request_method == "POST") and (ngx.req.get_post_args().action == "SAVE") then
    proxy.add(baseDHCPOptions)
end

if ngx.var.request_method == "POST" then
local post_data = ngx.req.get_post_args()
	if post_data["action"] == "RESET" then
	local lanip, lanmask, ipstart, iplimit, ltime, dhcpig = restdhcp()
		proxy.set("uci.network.interface.@"..curintf..".ipaddr",lanip)
		proxy.set("uci.network.interface.@"..curintf..".netmask",lanmask)
		proxy.set("uci.dhcp.dhcp.@"..curintf..".start", ipstart)
		proxy.set("uci.dhcp.dhcp.@"..curintf..".limit", iplimit)
		proxy.set("uci.dhcp.dhcp.@"..curintf..".leasetime", ltime)
		proxy.set("uci.dhcp.dhcp.@"..curintf..".ignore", dhcpig)
		if (dnsIndex < #dhcp.options +1) then
			proxy.set(baseDHCPOptions .. "@" .. dnsIndex .. ".value", "6,"..lanip)
		end
	proxy.apply()
	end
end

content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

if (ngx.var.request_method == "POST")  and not next(helpmsg) then
   local dhcp_options_path = "uci.dhcp.dhcp.@"..cur_dhcp_intf..".dhcp_option."
   local dhcp_options = content_helper.convertResultToObject(dhcp_options_path,proxy.get(dhcp_options_path))
    for _,v in ipairs(dhcp_options) do
      if v.value:match("^3,") then
        proxy.del(dhcp_options_path..v.paramindex..".")
      end
    end
end

-- because we do the localdevmask validation in localdevIP validation, we check if local ip starts with error msg "[netmask]".
-- If so move it to localdevmask
if helpmsg["localdevIP"] then
  local msg = match(helpmsg["localdevIP"], '^%[netmask%] (.*)')
  if msg then
    helpmsg["localdevIP"] = nil
    helpmsg["localdevmask"] = msg
  end
end
if helpmsg["dhcpLimit"] then
    local msg = match(helpmsg["dhcpLimit"], '^%[dhcpStart%] (.*)')
    if msg then
        helpmsg["dhcpLimit"] = nil
        helpmsg["dhcpStart"] = msg
    end
end

-- post_helper restores values that have been removed during validation
-- so if you remove the dns server, it will still be displayed on the page (though correctly set in datamodel)
-- this handles this case
if dnsRemoved then
    content["dnsServer"] = ""
end
if content["dnsServer"] == nil then
    local localIP = proxy.get("uci.network.interface.@" .. curintf .. ".ipaddr")[1].value
    content["dnsServer"] = localIP
else
    if content["dnsServer"]:find("^6,") == 1 then
      content["dnsServer"] = (content["dnsServer"] or ""):sub(3) -- the dhcp option will contain "6," at the start
   end
end

if content["dhcpState"] == "" then
    content["dhcpState"] = "0"
end

if not match(content["leaseTime"],"^0*([1-9]%d*[smhdw])$") then
  content["leaseTime"] = content["leaseTime"] .. "s"
end
local baseip = ipv42num(content["localdevIP"])
local netmask = ipv42num(content["localdevmask"])
local start = tonumber(content["dhcpStart"])
local numips = tonumber(content["dhcpLimit"])
local ipstart,ipend,network
if start and numips and not helpmsg["localdevIP"] and not helpmsg["localdevmask"] and not helpmsg["dhcpStart"] and not helpmsg["dhcpLimit"] then
  ipstart,ipend,network = calculateDHCPStartAddress(baseip,netmask,start,numips)
  session:store("dhcpStartAddr",ipstart)
  session:store("dhcpEndAddr",ipend)
  session:store("networkAddr",network)
else
  ipstart = ngx.req.get_post_args().dhcpStartAddress
  ipend = ngx.req.get_post_args().dhcpEndAddress
  network = session:retrieve("networkAddr")
 end
if helpmsg["leaseTime"] then
  content["leaseTime"] = ngx.req.get_post_args().leaseTime
end
  if ngx.var.request_method == "POST" then
    local gwIP = session:retrieve("old_ip")
    session:store("old_ip",(content["localdevIP"]))

  -- Redirect the GUI only if the local GW device IP address is changed for the "lan" interface
  if curintf == "lan" and content["localdevIP"]~= gwIP and not next(helpmsg) then%>
    <script type="text/javascript">
      window.location="http://<%=content["localdevIP"]%>";
    </script>
    <%session:logout()
  end
else
  session:store("old_ip",(content["localdevIP"]))
end
%>

<% ngx.print(ui_helper.createHeader(T"Local Network", true, false)) %>

   <div class="modal-body update">
     <form class="form-horizontal" method="post" action="<%= ngx.var.request_uri %>">
     <%
     -- Do not display the navlist on the list if only 1 lan interface
     if #lan_intfs> 1 then
     %>
     <div class="span2">
        <ul class="nav nav-list">
        <%
        local html = { format('<li class="nav-header">%s</li>', T"LAN Interfaces") }
        for k,v in ipairs(lan_intfs) do
            local active = ""
            if v.index == curintf then
                active = "active"
            end
            local url = "modals/ethernet-modal.lp?intf=" .. v.index
            html[#html+1] = format('<li class="%s"><a id = "%s" href="#" data-remote="%s">%s</a></li>', active, v.index, url, v.name)
        end
        ngx.print(html)
        %>
        </ul>
     </div>
     <div class="span6">
        <%
        end
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
        %>
          <fieldset>
              <legend><%= T"Global Information" %></legend>
              <%
              local advanced = {
                group = {
                  class = "advanced hide"
                }
              }
              -- Labels that shows the Local Device IP address & network subnet
				local html = {}
			  
				html[#html + 1] = ui_helper.createInputText(T"Local Device IP address", "localdevIP", content["localdevIP"],{},helpmsg["localdevIP"])
				html[#html + 1] = ui_helper.createInputText(T"Local Network subnet", "localdevmask", content["localdevmask"], advanced, helpmsg["localdevmask"])
				html[#html + 1] =ui_helper.createButton(T"Reset to default", T"Reset", "icon-bolt", clear_network_stats)
				if curintf == "lan" then
					html[#html + 1] = ui_helper.createSwitch(T"IPv6 state", "localIPv6", content["localIPv6"])
					local IPv6addr = proxy.get("rpc.network.interface.@"..curintf..".ip6addr")[1].value
					if IPv6addr == "" then
						html[#html + 1] = ui_helper.createLabel(T"LAN IPv6", T"IPv6 not assigned", advanced)
					else
					html[#html + 1] = ui_helper.createLabel(T"LAN IPv6", IPv6addr, advanced)
					end
				end
				ngx.print(html)
              %>
              <legend><%= T"DHCP Settings" %></legend>
              <%
                -- Labels that shows DHCP info
                local switchDHCP = {
                  values = {
                    on = "0",
                    off = "1"
                  }
                }
              ngx.print(
                  ui_helper.createSwitch(T"DHCP Server", "dhcpState", content["dhcpState"],switchDHCP),
                  ui_helper.createLabel(T"Network address", network, advanced),
                  ui_helper.createInputText(T"DHCP Start address", "dhcpStartAddress", ipstart, advanced, helpmsg["dhcpStart"]),
                  ui_helper.createInputText(T"DHCP End address", "dhcpEndAddress", ipend, advanced, helpmsg["dhcpLimit"]),
                  ui_helper.createInputText(T"Lease time", "leaseTime", content["leaseTime"], advanced, helpmsg["leaseTime"]),
                  ui_helper.createInputText(T"DNS server", "dnsServer", content["dnsServer"], advanced, helpmsg["dnsServer"])
                )
               %>
              <%
              -- Do not display the static lease when the interface is not lan
              if curintf == "lan" then
              %>
                  <legend><%= T"Static leases" %></legend>
                  <%
                    ngx.print(ui_helper.createTable(sleases_columns, sleases_data, sleases_options, nil, sleases_helpmsg))
                  %>
              </fieldset>
              <%
              end
              %>
          <%
          -- Do not display the navlist on the list if only 1 lan interface
          if #lan_intfs > 1 then
          %>
          </div>
          <%
          end
          %>
          <input type="hidden" name="isAdvanced" id="isAdvanced" value="0">
        </form>
   </div>

<script type='text/javascript'>
$(function() {
    var currentlanip = "<%= content["localdevIP"] %>";
    $("[name='localdevIP']").change(function(){
      if (currentlanip == $("[name='dnsServer']").val()){
          $("[name='dnsServer']").val($(this).val());
          currentlanip = $(this).val();
      }
    });

    $("#save-config").click(function(){
      if($("#Hide_Advanced_id").is(":visible"))
        $("#isAdvanced").val("1");
      else
        $("#isAdvanced").val("0");
    });

});
$("[name ='sleases_mac']").change(function () {
    if ((this.value) == "custom") {
          $(this).replaceWith($('<input/>',{'type':'text', 'name':'sleases_mac'}));
    }
});
</script>

<% ngx.print(ui_helper.createFooter()) %>
