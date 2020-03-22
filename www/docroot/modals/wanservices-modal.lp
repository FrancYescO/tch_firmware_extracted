--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local portslist = require("portslist_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()
local table, ipairs, pairs, format = table, ipairs, pairs, string.format
local warning_443 = "0"
local ddns_supported_services = {}

local pfw_destination_values = {
    {"", ""},
    {"any", T"any"},
}
for k, v in pairs(hosts_ac) do
    pfw_destination_values[#pfw_destination_values + 1] ={v,k}
end

local function generate_ddns_supported_services()
-- open the supported services file that come with the ddns package
    local f = io.open("/etc/ddns/services", "r")
    if f then
        for line in f:lines() do
           --a service in this file is  indicated as a url between quotes, we want a list with urls and name of service in capitals
           local service = line:match('^%b""')
           if service then
              service = service:gsub('"','')
              local serviceline = { service , service:upper() }
              ddns_supported_services[#ddns_supported_services + 1] = serviceline
           end
        end
        f:close()
    end
end

generate_ddns_supported_services()

-- Retrieve GW IP + netmask for use by validation function
local ipdetails = {
    gw = "uci.network.interface.@lan.ipaddr",
    netmask = "uci.network.interface.@lan.netmask"
}
content_helper.getExactContent(ipdetails)

local ddns_status_data = {
    ddns_status = "rpc.ddns.status",
}
content_helper.getExactContent(ddns_status_data)

-- DMZ / DynDNS / UPnP switches Only one handleQuery in a page
local qry_params = {
    DMZ_enable = "rpc.network.firewall.dmz.enable",
    DMZ_destination = "rpc.network.firewall.dmz.redirect.dest_ip",
    ddns_enabled = "uci.ddns.service.@myddns_ipv4.enabled",
    ddns_service_name = "uci.ddns.service.@myddns_ipv4.service_name",
    ddns_domain = "uci.ddns.service.@myddns_ipv4.domain",
    ddns_lookup_host = "uci.ddns.service.@myddns_ipv4.lookup_host",
    ddns_username = "uci.ddns.service.@myddns_ipv4.username",
    ddns_password = "uci.ddns.service.@myddns_ipv4.password",
    upnp_status = "uci.upnpd.config.enable_upnp",
    upnp_natpmp = "uci.upnpd.config.enable_natpmp",
    upnp_secure_mode = "uci.upnpd.config.secure_mode",
}

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSIP = post_helper.validateStringIsPort
local vSIPR = post_helper.validateStringIsPortRange
local gVP = post_helper.getValidationPassword
local gVSIDIP = post_helper.getValidateStringIsDeviceIPv4
local vSIDIP = gVSIDIP(ipdetails.gw, ipdetails.netmask)

local function set_lookup_host(value, object, key)
    object["ddns_lookup_host"] = object["ddns_domain"]
    return true
end

local qry_valid = {
    DMZ_enable = vB,
    DMZ_destination = gVIPIL(vSIDIP, "DMZ_enable", {"1"}),
    ddns_enabled = vB,
    ddns_service_name = gVIPIL(gVIES(ddns_supported_services), "ddns_enabled", {"1"}),
    ddns_username = gVIPIL(vNES, "ddns_enabled", {"1"}),
    ddns_password = gVP(gVIPIL(vNES, "ddns_enabled", {"1"})),
    ddns_domain = gVIPIL(vNES, "ddns_enabled", {"1"}),
    ddns_lookup_host = set_lookup_host,
    upnp_status = vB,
    upnp_natpmp = vB,
    upnp_secure_mode = vB,

}

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)

-- In UCI
--config 'redirect'
--        option 'enabled'  '1'
--        option 'name' 'ssh'
--        option 'src' 'wan'
--        option 'proto' 'tcp'
--        option 'src_dport' '5555'
--        option 'dest_ip' '192.168.1.100'
--        option 'dest_port' '22'
--        option 'target' 'DNAT'
--        option 'dest' 'lan'

-- In Transformer
-- rpc.network.firewall.portforward.{i}.enabled
-- rpc.network.firewall.portforward.{i}.name
-- rpc.network.firewall.portforward.{i}.src
-- rpc.network.firewall.portforward.{i}.src_dport
-- rpc.network.firewall.portforward.{i}.dest_ip
-- rpc.network.firewall.portforward.{i}.dest_port
-- rpc.network.firewall.portforward.{i}.target
-- rpc.network.firewall.portforward.{i}.dest
-- rpc.network.firewall.portforward.{i}.proto.@1.value

-- Templates for pre-defined rules
package.loaded['pfwd_helper'] = nil
local knownapps = require("pfwd_helper")

function translate(inputstr)
  local outputstr = ""
  if string.match(inputstr,"(.+)(%s)(%d+)") then
       local a,b,name,d,num= string.find(inputstr, "(.+)(%s)(%d+)")
       outputstr = T(name).." "..num
  else
       outputstr = T(inputstr)
  end
  return outputstr
end

local function table_removekey(table, key)
   local element = table[key]
   table[key] = nil
   return element
end

local wan_app = {}
-- Retrieve all wan-services sections in system config
local servicesTable = proxy.getPN("uci.system.wan-service.", true)
if servicesTable then
  for _,service in ipairs(servicesTable) do
    local port = string.match(service.path, "uci%.system%.wan%-service%.@([^%.]+)%.")
    if port then
      wan_app[#wan_app + 1] = port
    end
  end
end

local wan_ports ={}
-- Retrieve the list of ports in all wan-services section
for _,app in ipairs(wan_app) do
  local wan_port_path = "uci.system.wan-service.@".. app .. ".ports"
  wan_ports[#wan_ports + 1] = proxy.get(wan_port_path)
end

local reserved_ports = {}
for _,wanPort in ipairs(wan_ports) do
  for port in wanPort[1].value:gmatch("%w+") do
    reserved_ports [#reserved_ports +1] = port
  end
end

--Remove the ports configured in system.wan-service in allowed_portlist
local allowed_portlist = portslist
for _,wanPort in ipairs(reserved_ports) do
  for i,j in pairs(allowed_portlist) do
    if wanPort and (tonumber(wanPort) == tonumber(j)) then
       table_removekey(allowed_portlist,i)
    end
  end
end

local pfw_helper_map = {}
pfw_helper_map["FTP server"] = {pfw = "FTP server", helper = "ftp", wanport = "21"}
pfw_helper_map["TFTP server"] = {pfw = "TFTP server", helper = "tftp", wanport = "69"}
pfw_helper_map["PPTP"] = {pfw = "PPTP", helper = "pptp", wanport = "1723"}

--translate base on cur lang
for _,item in ipairs(knownapps) do
   for k,v in pairs(item) do
     if k == "text" then
       item[k] = translate(v)
     end
     if k == "values" then
        for _k,_v in pairs(v) do
            if _k == "name" then
              v[_k] = translate(_v)
            end
        end
     end
   end
end

local dmz_destination_values = (function ()
    local values = {}
    values[1]={"0", T"Add user defined entry"}
    for name, ip in pairs(hosts_ac) do
       values[#values + 1] = { ip, name }
    end
    return values
end)()

------------Firewall forwarding rules check and handle
local protocolMap = {
  DirectX = {"tcp", "udp", "tcpudp", "udp"},
  eMule = {"tcp", "tcp", "tcp", "udp", "udp"},
  Netmeeting = {"tcp", "tcp", "tcp", "tcp", "tcp", "tcp", "udp"},
  PlayStation = {"tcp", "tcp", "tcp", "tcpudp", "udp", "udp"},
  Skype = {"tcp", "tcpudp", "tcpudp"},
  Vuze = {"tcp", "tcp", "tcp", "udp", "udp"},
  Wii = {"tcpudp", "tcpudp", "tcp", "tcpudp", "tcp"},
  WindowsLiveMessenger = {"tcpudp", "tcpudp", "tcpudp", "tcp", "tcpudp", "tcp", "tcp", "tcpudp", "tcpudp","udp", "udp"},
  WinMX = {"tcp", "udp"},
}

local function isMultiPort(ports)
    local pos, _ = string.find(ports, ",")
    if pos ~= nil then
            return true
    end
    return false
end

local function getPortList(ports)
    local portList = {}
    local i,j, ni=1,1,nil
    while true do
      ni, j = string.find(ports, ",", i)
      local port = string.gsub(string.sub(ports, i, j), ",", "")
      table.insert(portList, port)
      if not ni then break end
      i = j+1
    end
    return portList
end

local portrange_pattern = "^(%d+)[%-%:](%d+)$"
function compare_startport(a,b)
  return a.start < b.start
end

local function validPorts(ports)
    local curend = -1

    for _,v in ipairs(ports) do
        if v.start <= curend then
            return nil, { wanport = T"An existing mapping overlaps with the ports range" }
        else
            curend = v["end"]
        end
    end
    return true
end

local function getTcpUdpPortRangeList(wanPort, proto, idx, tcp, udp)
	local p1,p2
	local chunks = { wanPort:match(portrange_pattern) }
	if #chunks == 2 then
		p1 = tonumber(chunks[1])
		p2 = tonumber(chunks[2])
	else
		p1 = tonumber(wanPort)
		p2 = p1
	end
	if proto == "tcp" or proto == "tcpudp" then
		tcp[#tcp+1] = { start = p1, ["end"] = p2, index = idx }
	end
	if proto == "udp" or proto == "tcpudp" then
		udp[#udp+1] = { start = p1, ["end"] = p2, index = idx }
	end
	return tcp, udp
end

local del_pfw_index = nil
local pfw_columns = {}

local function globalValid(data)

	local tcp = {}
	local udp = {}
	local err, msg
	local idx=1

        local allowedIndexes
        if del_pfw_index ~= nil then
            del_pfw_data, allowedIndexes = content_helper.loadTableData("rpc.network.firewall.portforward.", pfw_columns, nil, nil)
        end

	for i,v in ipairs(data) do
		local name = v[2]
		local protocol = v[3]
		local wanPortStr = v[4]
		if isMultiPort(wanPortStr) then
			wanPortList = getPortList(wanPortStr)
			for j=1, #wanPortList do
				local protocolMapName = string.format("%s",string.gsub(name, " ", ""))
				if protocolMap[protocolMapName] ~= nil then
					protocol = protocolMap[protocolMapName][j]
				end
				getTcpUdpPortRangeList(wanPortList[j], protocol, idx, tcp, udp)
				idx = idx + 1
			end
		else
			getTcpUdpPortRangeList(wanPortStr, protocol, idx, tcp, udp)
			idx = idx + 1
		end
	end

    table.sort(tcp, compare_startport)
    table.sort(udp, compare_startport)

    err, msg = validPorts(tcp)
    if not err then
        return err, msg
    end
    err, msg = validPorts(udp)
    return err, msg
end

function validateRuleName(value)
	local helpmsg = {}
	if type(value) ~= "string" and not string.istainted(value) then
		helpmsg["name"]=T"Received a non string value"
		return nil, helpmsg
	end
	if #value == 0 then
		helpmsg["name"]=T"String cannot be empty"
		return nil, helpmsg
	end
	local basepath = "rpc.network.firewall.portforward."
	local cmatch = content_helper.getMatchedContent(basepath, { ["name"] = value })
	if #cmatch > 0 then
		helpmsg["name"]=T"duplicate value"
		return nil, helpmsg
	end
	return true
end

function convertPostToArrayCusto(columns, data)
	local line = {}
	for _,v in ipairs(columns) do
		if v.type == "aggregate" then
			line[#line+1] = convertPostToArrayCusto(v.subcolumns, data)
		else
			line[#line+1] = data[v.name]
		end
	end
	return line
end

local function validatePortRange(basepath, columns, filter, sorted, content)
	local data, allowedIndexes = content_helper.loadTableData(basepath, columns, filter, sorted)
	data[#data+1] = convertPostToArrayCusto(columns, content)
	return globalValid(data)
end

local function validateServicePort(value)
  local portrange_pattern = "^[%s0]*(%d+)%s*%:[%s0]*(%d+)%s*$"
  if not value then
    return nil, T"Invalid port range."
  end
  local p1, p2 = string.match(value, portrange_pattern)
  if p1 then
    for _,v in ipairs(reserved_ports) do
      if tonumber(v) >= tonumber(p1) and tonumber(v) <= tonumber(p2) then
        return nil, T"Port range ".. p1 .. " : " .. p2 .. " covers reserved port " .. v .. " for wan services"
      end
    end
  else
    for _,v in ipairs(reserved_ports) do
      if tonumber(v) == tonumber(value) then
        return nil, T"Port " .. value .. " is reserved for wan services"
      end
    end
  end
  return true
end

local function validatePort(value, object, key, wan)
	local key_init = key
	local replacedash

	if isMultiPort(value) then
		local portList= getPortList(value)
		for i=1, #portList do
			replacedash=string.gsub(portList[i],"-",":")
			key=key_init..tostring(i)
			local valid, helpmsg = post_helper.validateStringIsPortRange(replacedash,object,key)
			if valid == nil then
				return valid, helpmsg
			elseif wan == true then
				return validateServicePort(replacedash)
			end
		end
	else
		if string.match(value,"%-") then
			key=key_init.."valid"
		end
		replacedash=string.gsub(value,"-",":")
		local valid, helpmsg = post_helper.validateStringIsPortRange(replacedash, object, key)
		if valid == nil then
			return valid, helpmsg
		elseif wan == true then
			return validateServicePort(replacedash)
		end
	end
	return true
end

local function validateLANPort(value, object, key)
	return validatePort(value, object, key, false)
end

local function validateWANPort(value, object, key)
	return validatePort(value, object, key, true)
end

local function columnsToParamMapCusto(columns, withro)
    local map = {}
    for _,v in ipairs(columns) do
        if v.type == "aggregate" then
            for _, sv in ipairs(v.subcolumns) do
                if withro or not sv.readonly then
                    map[sv.name] = sv.param
                end
            end
        else
            if withro or not v.readonly then
                map[v.name] = v.param
            end
        end
    end
    return map
end

local function complementObjectAndValidateCusto(postdata, mapparam, mapvalid)
    for k,v in pairs(mapparam) do
       if not postdata[k] then
          postdata[k] = "" -- put a default value to get it through validation, it should have been sent in the post data
       end
    end
    return content_helper.validateObject(postdata, mapvalid)
end

local function handleTableQueryCusto(columns, options, filter, defaultObject, mapValidation)
		local content = ngx.req.get_post_args()
	local paramMap = columnsToParamMapCusto(columns)
	local basepath = options.basepath or ""
	local session = ngx.ctx.session
	local tablesessionkey = options.tableid .. ".stateid"
	local tablesessionindexes = options.tableid .. ".allowedindexes"
	local sorted = options and options.sorted

	local wanPortList= getPortList(content.wanport)
	local lanPortList= getPortList(content.lanport)
	local multiName = content.name
	validated, helpmsg = complementObjectAndValidateCusto(content, paramMap, mapValidation)
	if validated == true then
		for i=1, #wanPortList do
			local name = multiName .." ".. tostring(i)
			validated, helpmsg = validateRuleName(name)
			if not validated then
				break
			end
		end
	end
	if validated == true then
		validated, helpmsg = validatePortRange(basepath, columns, filter, sorted, content)
	end
	if validated == true then
		if isMultiPort(content.wanport) then
			for i=1, #wanPortList do
				content.name = multiName .." ".. tostring(i)
				content.wanport = wanPortList[i]
				content.lanport = lanPortList[i]
				local protocolMapName = string.format("%s",string.gsub(multiName, " ", ""))
				if protocolMap[protocolMapName] ~= nil then
					content.protocol = protocolMap[protocolMapName][i]
				end
				success = content_helper.addNewObject(basepath, content, paramMap, defaultObject)
			end
			proxy.apply()
		end
	end

	options.stateid = session:retrieve(tablesessionkey) or ""
	local data, allowedIndexes = content_helper.loadTableData(basepath, columns, filter, sorted)
	session:store(tablesessionindexes, allowedIndexes)
	if not validated then
		options.editing = -1
		for _,v in ipairs(columns) do
			v.default = content[v.name] or v.default or ""
		end
	end
	return data, helpmsg
end


-- Firewall forwarding rules
local pfw_columns = {
  {
    header = "",
    name = "enabled",
    param = "enabled",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Name",
    name = "name",
    param = "name",
    type = "text",
    unique = true,
    attr = { input = { class="span2" } },
  },
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto.@1.value",
    default = "tcp",
    type = "select",
    values = {
      { "tcp", "TCP"},
      { "udp", "UDP"},
      { "tcpudp", "TCP/UDP"}
    },
    attr = { select = { class="span2" } },
  },
  {
    header = T"WAN port",
    name = "wanport",
    param = "src_dport",
    type = "text",
    attr = { input = { class="span1", maxlength="11" }, autocomplete=allowed_portlist },
  },
  {
    header = T"LAN port",
    name = "lanport",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="11" }, autocomplete=portslist },
  },
  {
    header = T"Destination",
    name = "pfw_destinationip",
    param = "dest_ip",
    default = "",
    type = "select",
    values = pfw_destination_values,
    attr = { select = { class="span2"} },
  },
}

local pfw_attributes = {
}

local pfw_valid = {
    enabled = vB,
    name = vNES,
    lanport = validateLANPort,
    wanport = validateWANPort,
    pfw_destinationip = vSIDIP,
}

-- Warning, this uses transformer paths. So use correct naming
local pfw_defaultObject = {
    src = "wan",
    dest = "lan",
    family = "ipv4",
    target = "DNAT",
}

local pfw_filter = nil


local function set_helper_port(helper, port)
    local path = "uci.firewall.helper."
    local data = proxy.get(path)

    if data == nil then
        return
    end

    for _,v in ipairs(data) do
        if v.param == "helper" and v.value == helper then
            proxy.set(v.path .. "dest_port", port)
            return
        end
    end

end

local function get_firewall_helper(userredir_name)
    local tmp
    for _,tmp in pairs(pfw_helper_map) do
        if userredir_name == tmp.pfw then
            return tmp
        end
    end

    return nil
end

local function get_firewall_helper_name(userredir_name)
    local tmp = get_firewall_helper(userredir_name)

    if tmp ~= nil then
        return tmp["helper"]
    else
        return nil
    end
end

local function update_firewall_helper(index, content)
    if index == nil then
        return
    end

    local helper = get_firewall_helper_name(content.name)

    -- the corresponding helper in firewall should be updated also
    if helper ~= nil then
        if content.enabled == "1" then
            set_helper_port(helper, string.untaint(content.wanport))
        else
            set_helper_port(helper, pfw_helper_map[string.untaint(content.name)].wanport)
        end
    end
end


local function onDelete(index)
    if del_pfw_index == nil then
        return
    end

    local helper = get_firewall_helper(del_pfw_data[del_pfw_index][2])

    if helper ~= nil and helper["wanport"] ~= nil then
        set_helper_port(helper.helper, helper.wanport)
    end
end

local pfw_options = {
    tableid = "portforwarding",
    basepath = "rpc.network.firewall.portforward.",
    createMsg = T"Add new port mapping",
    newList = knownapps,
    valid = globalValid,
    onModify = update_firewall_helper,
    onAdd = update_firewall_helper,
    onDelete = onDelete,
}

-- Firewall forwarding userdefined rules
local pfw_columns_userd = {
  {
    header = "",
    name = "enabled",
    param = "enabled",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Name",
    name = "name",
    param = "name",
    type = "text",
    unique = true,
    attr = { input = { class="span2" } },
  },
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto.@1.value",
    default = "tcp",
    type = "select",
    values = {
      { "tcp", "TCP"},
      { "udp", "UDP"},
      { "tcpudp", "TCP/UDP"}
    },
    attr = { select = { class="span2" } },
  },
  {
    header = T"WAN port",
    name = "wanport",
    param = "src_dport",
    type = "text",
    attr = { input = { class="span1", maxlength="11" }, autocomplete=portslist },
  },
  {
    header = T"LAN port",
    name = "lanport",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="11" }, autocomplete=portslist },
  },
  {
    header = T"Destination",
    name = "pfw_destinationip",
    param = "dest_ip",
    default = "",
    type = "select",
    values = pfw_destination_values,
    attr = { select = { class="span2"} },
  },
}

local pfw_attributes_userd = {
}

local pfw_valid_userd = {
    enabled = vB,
    name = vNES,
    lanport = validateLANPort,
    wanport = validateWANPort,
    pfw_destinationip = vSIDIP,
}

local pfw_filter_userd = nil

local pfw_options_userd = {
    tableid = "portforwardingUserd",
    basepath = "rpc.network.firewall.portforward.",
    createMsg = T"Add new user defined port mapping",
    newList = knownapps,
    valid = globalValid,
    onModify = update_firewall_helper,
    onAdd = update_firewall_helper,
    onDelete = onDelete,
}

local pfw_data, pfw_helpmsg, pfw_data_userd, pfw_helpmsg_userd
local isSingleHandle = true
--Handle for multi port
if ngx.var.request_method == "POST" then
	local content = ngx.req.get_post_args()
        if content.action == "TABLE-DELETE" and (content.tableid == "portforwarding" or content.tableid == "portforwardingUserd") then
            del_pfw_index = tonumber(content.index)
        end

	if content.action == "TABLE-ADD" and (content.tableid == "portforwarding" or content.tableid == "portforwardingUserd") and isMultiPort(content.wanport) then
		if content.tableid == "portforwarding" then
			pfw_data, pfw_helpmsg = handleTableQueryCusto(pfw_columns, pfw_options, pfw_filter, pfw_defaultObject, pfw_valid)
			pfw_data_userd, pfw_helpmsg_userd = post_helper.handleTableQuery(pfw_columns_userd, pfw_options_userd, pfw_filter_userd, pfw_defaultObject, pfw_valid_userd)
		elseif content.tableid == "portforwardingUserd" then
			pfw_data_userd, pfw_helpmsg_userd = handleTableQueryCusto(pfw_columns_userd, pfw_options_userd, pfw_filter_userd, pfw_defaultObject, pfw_valid_userd)
			pfw_data, pfw_helpmsg = post_helper.handleTableQuery(pfw_columns, pfw_options, pfw_filter, pfw_defaultObject, pfw_valid)
		end
		isSingleHandle = false
	end
end

if isSingleHandle then
	--basic handle
	pfw_data, pfw_helpmsg = post_helper.handleTableQuery(pfw_columns, pfw_options, pfw_filter, pfw_defaultObject, pfw_valid)
	--advance handle
	pfw_data_userd, pfw_helpmsg_userd = post_helper.handleTableQuery(pfw_columns_userd, pfw_options_userd, pfw_filter_userd, pfw_defaultObject, pfw_valid_userd)
end

-- for DMZ notice message
  local number_of_pfw = nil
  local userredirect_list = "uci.firewall."
  local user_tab_list =  proxy.get(userredirect_list)
  local res = {}
	    post_helper.mergeTables(res, user_tab_list)
  local num = tonumber(res.userredirectNumberOfEntries)
  local get_port = nil
  local enable_status = nil
  local entry_num = 1

  while( num > 0 )
  do
    get_port = proxy.get(userredirect_list.."userredirect."..tostring(entry_num)..".src_dport")
    enable_status = proxy.get(userredirect_list.."userredirect."..tostring(entry_num)..".enabled")
	if enable_status and get_port then
	  if tonumber(enable_status[1].value) == 1 and tonumber(get_port[1].value) == 443 then
            warning_443 = "1"
            break
	  end
	end
	entry_num = entry_num + 1
	if enable_status ~= nil then
	  num = num - 1
	end
  end
-- UPnP forwarding rules
local upnp_columns = {
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto",
    default = "tcp",
    type = "select",
    values = {
      { "tcp", "TCP"},
      { "udp", "UDP"},
      { "tcpudp", "TCP+UDP"}
    },
    attr = { select = { class="span2" } },
  },
  {
    header = T"WAN port",
    name = "wanport",
    param = "src_dport",
    type = "text",
    attr = { input = { class="span1", maxlength="5" } },
  },
  {
    header = T"LAN port",
    name = "lanport",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" } },
  },
  {
    header = T"Destination",
    name = "destinationip",
    param = "dest_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15"} },
  },
  {
    header = T"Description",
    name = "description",
    param = "description",
    type = "text",
    attr = { input = { class="span2", maxlength="15"} },
  },
}

local upnp_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "upnpportforwarding",
    basepath = "sys.upnp.redirect.",
}

local ddns_state_map = {
  disabled = T"disabled",
  updating = T"updating",
  updated = T"updated",
  error = T"error",
}

local ddns_light_map = {
  disabled = "off",
  updating = "orange",
  updated = "green",
  error = "red",
}

local upnp_data, upnp_helpmsg = post_helper.handleTableQuery(upnp_columns, upnp_options, nil, nil, nil)

local ddns_enabled
-- get the ddns parameter 'enabled' from uci when handleQuery(qry_params...) fails
if (ngx.var.request_method == "POST") and (next(qry_helpmsg)) then
  local ddns_uci = {
      ddns_enabled = "uci.ddns.service.@myddns.enabled",
  }
  content_helper.getExactContent(ddns_uci)
  ddns_enabled = ddns_uci.ddns_enabled
else
  ddns_enabled = qry_data.ddns_enabled
end

local action
if ngx.var.request_method == "POST" then
  action = ngx.req.get_post_args().action
end

local ddns_status = "error"
if ddns_enabled ~= "1" then
  ddns_status = "disabled"
else
  if action == "SAVE" then
    ddns_status = "updating"
  elseif ddns_status_data.ddns_status then
    if ddns_status_data.ddns_status == "Domain's IP updated" then
      ddns_status = "updated"
    elseif ddns_status_data.ddns_status == "No error received from server" then
      ddns_status = "updating"
    else
      ddns_status = "error"
    end
  end
end

local ddns_update_info = T"No error received from server"
if ddns_enabled ~= "0" then
  if action ~= "SAVE" and ddns_status_data.ddns_status then
    ddns_update_info = ddns_status_data.ddns_status
    local si,ei,middle = string.find(ddns_update_info,"nslookup: can't resolve(.+)Name or service not known")
    if si and middle then
      ddns_update_info = T"nslookup: can't resolve"..middle..T"Name or service not known"
    end
    if ddns_update_info == "No error received from server" then
      ddns_update_info = T"No error received from server"
    end
  end
end

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"WAN services", true, true))   ngx.print('\
\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/wanservices-modal.lp">\
    ');  
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
        ngx.print("<div class = 'alert alert-error' >"..T"The user that the port for remote access has been changed to: ".."8090.".."</div>")
      ngx.print('\
\
    <fieldset class="advanced hide">\
      <legend>');  ngx.print( T"DMZ" ); ngx.print('</legend>\
      ');  
        -- Switch for toggling DMZ state
        local dmzattr = {
          autocomplete = hosts_ac
        }
        local dmzattr_sel = {
          select = {
            class = "span5",
          },
        }
        local dmzattr_hide = {
          autocomplete = hosts_ac,
          input = {
            class = "hide ",
          },
        }
        ngx.print(ui_helper.createSwitch(T"Enabled", "DMZ_enable", qry_data["DMZ_enable"], nil, qry_helpmsg["DMZ_enable"]))
        local sel = 0
        for _ , v in pairs(dmz_destination_values) do
          if (v[1] and qry_data["DMZ_destination"] and (qry_data["DMZ_destination"] == v[1])) then
            sel = 1
            break
          end
        end

        ngx.print(ui_helper.createInputSelect(T"Destination", "DMZ_destination_sel",dmz_destination_values, qry_data["DMZ_destination"], dmzattr_sel))
        if sel == 0 then
          ngx.print(ui_helper.createInputText(T"", "DMZ_destination", qry_data["DMZ_destination"], dmzattr, qry_helpmsg["DMZ_destination"]))
        else
          ngx.print(ui_helper.createInputText(T"", "DMZ_destination", qry_data["DMZ_destination"], dmzattr_hide, qry_helpmsg["DMZ_destination"]))
        end
        ngx.print('\
    </fieldset>\
\
    <fieldset class="advanced show">\
      <legend>');  ngx.print( T"Port forwarding table" ); ngx.print('</legend>\
      ');  
        ngx.print(ui_helper.createTable(pfw_columns, pfw_data, pfw_options, pfw_attributes, pfw_helpmsg))
        ngx.print('\
    </fieldset>\
\
    <fieldset class="advanced hide">\
      <legend>');  ngx.print( T"User defined port forwarding table" ); ngx.print('</legend>\
      ');  
        ngx.print(ui_helper.createTable(pfw_columns_userd, pfw_data_userd, pfw_options_userd, pfw_attributes_userd, pfw_helpmsg_userd))
        ngx.print('\
    </fieldset>\
\
    <fieldset>\
      <legend>');  ngx.print( T"UPnP" ); ngx.print('</legend>\
      ');  
        local advanced = { group = { class = "advanced hide" }}
        ngx.print(
          ui_helper.createSwitch(T"UPnP Enabled", "upnp_status", qry_data["upnp_status"], advanced, qry_helpmsg["upnp_status"]),
          ui_helper.createSwitch(T"NAT-PMP Enabled", "upnp_natpmp", qry_data["upnp_natpmp"], advanced, qry_helpmsg["upnp_natpmp"]),
          ui_helper.createSwitch(T"Secure Mode Enabled", "upnp_secure_mode", qry_data["upnp_secure_mode"], advanced, qry_helpmsg["upnp_secure_mode"]),
          ui_helper.createTable(upnp_columns, upnp_data, upnp_options, upnp_attributes, upnp_helpmsg)
        )
        ngx.print('\
    </fieldset>\
\
    <fieldset class="advanced hide">\
      <legend>');  ngx.print( T"DynDNS" ); ngx.print('</legend>\
      ');  
         ngx.print(
            ui_helper.createLight(T"Status", nil, ddns_state_map[ddns_status], { light = { class = ddns_light_map[ddns_status] } }),
            ui_helper.createSwitch(T"Enabled", "ddns_enabled", qry_data["ddns_enabled"], nil, qry_helpmsg["ddns_enabled"]),
            ui_helper.createInputSelect(T"Service Name", "ddns_service_name", ddns_supported_services, qry_data["ddns_service_name"], nil, qry_helpmsg["ddns_service_name"]),
            ui_helper.createInputText(T"Domain", "ddns_domain", qry_data["ddns_domain"], nil, qry_helpmsg["ddns_domain"]),
            ui_helper.createInputText(T"User Name", "ddns_username", qry_data["ddns_username"], nil, qry_helpmsg["ddns_username"]),
            ui_helper.createInputPassword(T"Password", "ddns_password", qry_data["ddns_password"], nil, qry_helpmsg["ddns_password"])
          )
        if qry_data["ddns_enabled"] == "1" then
          local basic = {
            span = {
            class = "span12"
            },
          }
          ngx.print(
            ui_helper.createLabel(T"DynDNS Information", ddns_update_info, basic)
          )
        end
        ngx.print('\
    </fieldset>\
\
\
  </form>\
</div>\
<script type="text/javascript">\
$(document).ready(function(){\
$(\'select[name="DMZ_destination_sel"]\').on("change", function() {\
  if(this.value == "0")\
  {\
    $(\'input[name="DMZ_destination"]\').val("");\
    $(\'input[name="DMZ_destination"]\').show();\
  }else{\
    $(\'input[name="DMZ_destination"]\').val(this.value);\
    $(\'input[name="DMZ_destination"]\').hide();\
  }\
});\
\
$(\'select[name="pfw_destinationip"]\').on("change", function() {\
    if(this.value == "any")\
    {\
        var dest_ip_input = $(\'<input name="pfw_destinationip" class="span2 edit-input" type="text" maxlength="15">\');\
        $(this).after(dest_ip_input);\
        $(this).remove();\
    }\
});\
});\
</script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 