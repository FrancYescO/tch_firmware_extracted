local gsub, format, match = string.gsub, string.format, string.match
local huge = math.huge
local bit = require("bit")

local touci = require("tch.configmigration.touci")
local append_commit_list = require("tch.configmigration.core").append_commit_list

local M = {}

local map2bool = {
  ["enabled"] = 1,
  ["disabled"] = 0,
}

function M.convert_bool(_, value)
  return map2bool[value]
end

function M.convert_acl(_,value)
  if value ~= "lock" then
    return "disabled"
  end
end

local map2secmode = {
  ["disable"] = "none",
  ["wep"]     = "wep",
  ["wpa-psk"] = { ["WPA"] = "wpa-wpa2-psk",
                  ["WPA2"] = "wpa2-psk",
                  ["WPA+WPA2"] = "wpa-wpa2-psk",
                },
  ["wpa"]     = { ["WPA"] = "wpa-wpa2",
                  ["WPA2"] = "wpa2",
                  ["WPA+WPA2"] = "wpa-wpa2",
                },
}

function M.wireless_convert_secmode(_, legacy_value, legacy_attribute_t)
  local secmode = map2secmode[legacy_value]
  if type(secmode) == "table" and legacy_attribute_t then
     if legacy_value == "wpa" then
        return secmode[legacy_attribute_t.WPAversion]
     elseif legacy_value == "wpa-psk" then
        return secmode[legacy_attribute_t.WPAPSKversion]
     end
  end
  return secmode
end

local map2ddnsinterface = {
  ["B2BUA"] = "",
  ["PPPoEDSL"] = "ppp",
  ["Internet"] = "ppp",
  ["IPoEDSL"] = "ipoe",
  ["IPoEWAN"] = "ipoe",
  ["MobileBroadband"] = "",
  ["PPPoEWAN"] = "ppp",
}
function M.convert_ddns_interface(_, value)
  return map2ddnsinterface[value]
end

local map2ddnsservice = {
  ["dyndns"] = "dyndns.org",
  ["No-IP"] = "no-ip.com",
  ["custom"] = "custom",
  ["statdns"] = "statdns",
  ["DtDNS"] = "dtdns.com",
  ["gnudip"] = "gnudip",
}
function M.convert_ddns_service(_, value)
  return map2ddnsservice[value]
end

function M.convert_mobile_opermode(_, value)
  return value:upper()
end

function M.wireless_convert_trace_modules(lk, legacy_value, legacy_attribute_t)
  local trcmods_t = legacy_attribute_t["_trace_modules"]
  if not trcmods_t then legacy_attribute_t["_trace_modules"] = {} end
  trcmods_t = legacy_attribute_t["_trace_modules"]
  if legacy_value == "enabled" then
     trcmods_t[#trcmods_t+1] = lk
  end
  return trcmods_t
end

function M.cmd_capture(cmd)
   local f = assert(io.popen(cmd, 'r'))
   local s = assert(f:read('*a'))
   f:close()
   return s
end

function convert_addr_to_offset(addr, cidr)
   local hostnb = cidr%8
   local netnb = (cidr - hostnb)/8

   local pb = {}
   addr = gsub(addr, "([0-9]+)", "0", netnb)
   pb[0], pb[1], pb[2], pb[3] = match(addr, "([0-9]+)%.([0-9]+)%.([0-9]+)%.([0-9]+)")

   pb[netnb] = M.cmd_capture("echo $(( ~(255 << " .. 8 - hostnb .. ") & " .. pb[netnb] ..  " ))" )

   local offset = pb[0]*256*256*256 + pb[1]*256*256 + pb[2]*256 + pb[3]
   -- print(offset)
   return offset
end

function M.dhcs_convert_pooloffset(_, legacy_value, legacy_attribute_t)

   if legacy_attribute_t.pooloffset == nil then
      legacy_attribute_t["pooloffset"] = convert_addr_to_offset(legacy_value, legacy_attribute_t.netmask)
   end
   return legacy_attribute_t.pooloffset
end

function M.dhcs_convert_poolrange(_, legacy_value, legacy_attribute_t)
   if legacy_attribute_t.pooloffset == nil then
      legacy_attribute_t["pooloffset"] = convert_addr_to_offset(legacy_attribute_t.poolstart, legacy_attribute_t.netmask)
   end

   local poolend = convert_addr_to_offset(legacy_value, legacy_attribute_t.netmask)

   return poolend - legacy_attribute_t["pooloffset"] + 1
end

-- line up with /vobs/fsn/app/co/tagparser/tagtypes.c
local map2ipport = {
  ["undefined"] = 0,        -- DNS/SRV undefined port for SIP Proxy
  ["at-echo"]   = 204,      -- AppleTalk Echo
  ["at-nbp"]    = 202,      -- AppleTalk Name Binding
  ["at-rtmp"]   = 201,      -- AppleTalk Routing Maintenance
  ["at-zis"]    = 206,      -- AppleTalk Zone Information
  ["auth"]      = 113,      -- Authentication Service
  ["bgp"]       = 179,      -- Border Gateway Protocol
  ["biff"]      = 512,      -- used by mail system to notify users
  ["bootpc"]    = 68,       -- Bootstrap Protocol Client
  ["bootps"]    = 67,       -- Bootstrap Protocol Server
  ["chargen"]   = 19,       -- Character Generator
  ["clearcase"] = 371,      -- Clearcase
  --["cmd"]     = 514,      -- like exec, but automatic
  ["daytime"]   = 13,       -- Daytime
  ["discard"]   = 9,        -- Discard
  ["dns"]       = 53,       -- Domain Name Server
  ["domain"]    = 53,       -- Domain Name Server
  ["doom"]      = 666,      -- doom Id Software
  ["echo"]      = 7,        -- Echo */
  ["exec"]      = 512,      -- remote process execution;
  ["finger"]    = 79,       -- Finger
  ["ftp"]       = 21,       -- File Transfer [Control]
  ["ftp-data"]  = 20,       -- File Transfer [Default Data]
  ["gopher"]    = 70,       -- Gopher
  ["h323"]      = 1720,     -- h323
  ["httpproxy"] = 8080,     -- HTTP proxy
  ["ike"]       = 500,      -- IKE
  ["ils"]       = 1002,     -- ils
  ["imap2"]     = 143,      -- Interim Mail Access Protocol v2
  ["imap3"]     = 220,      -- Interactive Mail Access Protocol v3
  ["ingres-net"]= 134,      -- INGRES-NET Service *
  ["ipcserver"] = 600,      -- Sun IPC server
  ["ipx"]       = 213,      -- IPX
  ["irc-o"]     = 194,      -- Internet Relay Chat Protocol */
  ["irc-u"]     = 6667,     -- Internet Relay Chat Protocol
  ["kerberos"]  = 88,       -- Kerberos
  ["ldap"]      = 389,      -- Lightweight Directory Access Protocol
  --["login"]   = 49,       -- dups port 513 !!!  Login Host Protocol
  ["login"]     = 513,      -- remote login a la telnet;
  ["netbios-dgm"]   = 138,  -- NETBIOS Datagram Service
  ["netbios-ns"]    = 137,  -- NETBIOS Name Service
  ["netbios-ssn"]   = 139,  -- NETBIOS Session Service *
  ["netwall"]   = 533,      -- for emergency broadcasts
  ["netware-ip"]    = 396,  -- Novell Netware over IP *
  ["new-rwho"]  = 550,      -- new-who
  ["nfds"]      = 2049,     -- NFS deamon
  ["nicname"]   = 43,       -- Who Is
  ["nntp"]      = 119,      -- Network News Transfer Protocol
  ["ntalk"]     = 518,
  ["ntp"]       = 123,      -- Network Time Protocol */
  ["pcmail-srv"]= 158,      -- PCMail Server
  ["pop2"]      = 109,      -- Post Office Protocol - Version 2
  ["pop3"]      = 110,      -- Post Office Protocol - Version 3
  ["printer"]   = 515,      -- spooler
  ["qotd"]      = 17,       -- Quote of the Day
  ["realaudio"] = 7070,     -- realaudio
  ["rip"]       = 520,      -- rip
  ["rtelnet"]   = 107,      -- Remote Telnet Service
  ["rtsp"]      = 554,      -- rtsp
  ["sip"]       = 5060,     -- Session Initiation Protocol
  ["smtp"]      = 25,       -- Simple Mail Transfer
  ["snmp"]      = 161,      -- SNMP
  ["snmptrap"]  = 162,      -- SNMPTRAP
  ["snpp"]      = 444,      -- Simple Network Paging Protocol
  ["sntp"]      = 123,      -- Network Time Protocol */
  ["sql*net"]   = 66,       -- Oracle SQL*NET
  ["sql-net"]   = 150,      -- SQL-NET
  ["sqlserv"]   = 118,      -- SQL Services
  ["sunrpc"]    = 111,      -- SUN Remote Procedure Call
  ["syslog"]    = 514,
  ["systat"]    = 11,       -- Active Users
  ["talk"]      = 517,      -- like tenex link, but across
  ["telnet"]    = 23,       -- Telnet
  ["time"]      = 37,       -- Time
  ["timed"]     = 525,      -- timeserver
  ["tftp"]      = 69,       -- Trivial File Transfer
  ["ulistserv"] = 372,      -- Unix Listserv
  ["utime"]     = 519,      -- unixtime
  ["uucp"]      = 540,      -- uucpd
  ["uucp-rlogin"]   = 541,  -- uucp-rlogin  Stuart Lynne
  ["who"]       = 513,      -- maintains data bases showing who's
  ["www-http"]  = 80,       -- World Wide Web HTTP
  ["whoami"]    = 565,      -- whoami
  ["xwindows"]  = 6000,     -- X windows
}

-- convert service.ini auxiliary methods
function M.service_get_uci_secname(_,_,legacy_attribute_t)
  if legacy_attribute_t._maps_store["_target"] == "SNAT" then
     -- set uci_secname as 'nil' to skip the outbound/SNAT port mapping
     return nil
  end
  if not legacy_attribute_t._maps_store["_uci_secname"] then
     legacy_attribute_t._maps_store["_uci_secname"] = legacy_attribute_t._maps_store["_ucicmd_result"]
  end
  return legacy_attribute_t._maps_store["_uci_secname"]
end

function M.service_get_portmapping_mode(_,legacy_value,legacy_attribute_t)
  -- skip the outbound/SNAT port mapping, since homeware GUI dosen't support
  if legacy_value == "auto" or legacy_value == "inbound" then
     legacy_attribute_t._maps_store["_target"] = "DNAT"
  else
     legacy_attribute_t._maps_store["_target"] = "SNAT"
  end
end

function M.service_add_portmapping_if_need(_,_,legacy_attribute_t)
  -- legacy parameter 'mode' is optional and default value is 'auto',
  -- in this case we should create a 'DNAT' in homeware.
  if not legacy_attribute_t._maps_store["_target"] then
     legacy_attribute_t._maps_store["_target"] = "DNAT"
  end
  if legacy_attribute_t._maps_store["_target"] ~= "SNAT" then
     return "add"
  end
end

function M.service_convert_baseport_to_dest_port(_,legacy_value,legacy_attribute_t)
  if legacy_attribute_t["baseport"] then
     local baseport = map2ipport[legacy_attribute_t["baseport"]] or legacy_attribute_t["baseport"]
     -- fully use Lua imply type convsion
     local range = gsub(legacy_attribute_t["portrange"], "((%d+)%-(%d+))", function(_,s,e) return e-s end)
     return format("%d-%d", baseport, baseport+range)
  --else
  --don't do anything, then return value will be nil, thus framework will use legacy value.
  end
end

function M.dhcs_convert_poolstate(_, legacy_value, legacy_attribute_t)
  if legacy_value == "enabled" then
    return "server"
  else
    return "disabled"
  end
end

-- In legacy Number@IP or Number@DomainName format is allowed for URI,
-- But in HW this format is not supported. So need to get only Number for HW config.
function M.get_uri(_, legacy_value)
  local number = match(legacy_value, "^([^@]*)@(.*)")

  if number then	  --legacy_value containing @, So return only number.
     return number
  else
     return legacy_value  -- legacy_value not having @, So we can return same value.
  end
end

function M.decrypt(_, legacy_value)
  return M.cmd_capture("passwd_decrypt "..legacy_value)
end

function M.set_each_section(uci_config, uci_secname, uci_option, uci_value)
  local ucicmd = {}
  ucicmd.uci_config = uci_config
  ucicmd.uci_secname = uci_secname

  ucicmd.uci_option = uci_option
  ucicmd.value = uci_value
  ucicmd.action = "set"

  append_commit_list(ucicmd.uci_config)
  touci.touci(ucicmd)
end

function M.num2ipv4(ip)
  return format("%d.%d.%d.%d", bit.band(bit.rshift(ip,24), 255),
                               bit.band(bit.rshift(ip,16), 255),
                               bit.band(bit.rshift(ip,8), 255),
                               bit.band(ip, 255))
end

function M.convert_ipport(_, value)
  return map2ipport[value] or value

end

local voice_services_type_map = {
  ["waiting"]   = "CALL_WAITING",
  ["clip"]      = "CLIP",
  ["clir"]      = "CLIR",
  ["hold"]      = "HOLD",
  ["transfer"]  = "TRANSFER",
  ["warmline"]  = "WARMLINE",
  ["3pty"]      = "CONFERENCE",
  ["acr"]       = "ACR",
  ["cfbs"]      = "CFBS",
  ["cfnr"]      = "CFNR",
  ["cfu"]       = "CFU",
  ["mwi"]       = "MWI",}

local voice_profile_services = {
  ["acr"] = "acr",
  ["cfbs"] = "cfbs",
  ["cfnr"] = "cfnr",
  ["cfu"] = "cfu",
  ["clip"] = "clip",
  ["clir"] = "clir",
  ["callreturn"] = "call_return",
}

-- services whose profile information has to be migrated, should be mentioned in below table
local voice_profile_based_services_list = {
"CLIR",
"HOLD",
}


--function to append list of profile names to services
function M.voice_profile_based_services_add_profile(profile_secname)
  for _,v in ipairs (voice_profile_based_services_list) do
    local voice_srv = touci.get_config_by_option_value("mmpbx", "service", "type", v)
    local voice_srv_uci_name
    if not voice_srv then return  end
    voice_srv_uci_name = voice_srv[1][".name"]
    local ucicmd = {}
    ucicmd.uci_config = "mmpbx"
    ucicmd.uci_secname = voice_srv_uci_name
    ucicmd.action = "add_list"
    ucicmd.uci_option = "profile"
    local profile_list ={}
    profile_list = touci.get_all(format("%s.%s.%s","mmpbx",voice_srv_uci_name,"profile"))
    if profile_list then
      if type(profile_secname) == "string" and not match(table.concat(profile_list," "), profile_secname) then
        profile_list[#profile_list+1] = profile_secname
      end
    else
      if type(profile_secname) == "string" then
        profile_list = { profile_secname}
      end
    end
    ucicmd.value = profile_list
    append_commit_list(ucicmd.uci_config)
    touci.touci(ucicmd)
  end
end

function M.voice_services_get_uci_name(_,lv)
  local voice_srv = touci.get_config_by_option_value("mmpbx", "service", "type", voice_services_type_map[lv])
  local voice_srv_uci_name
  if voice_srv then
    voice_srv_uci_name = voice_srv[1][".name"]
  end
  return voice_srv_uci_name
end

function M.voice_service_based_services_get_uci_name(_,lv)
  local voice_srv_uci_name
  if voice_profile_services[lv] then
    voice_srv_uci_name = "service_" .. lv
  end
  return voice_srv_uci_name
end

function M.voice_services_get_cw_uciname(_,_,lt)
  if lt["_cw_uciname"] then return lt["_cw_uciname"] end
  lt["_cw_uciname"] = M.voice_services_get_uci_name(_,"waiting")
  return lt["_cw_uciname"]
end

function M.voice_services_get_wl_uciname(_,_,lt)
  if lt["_wl_uciname"] then return lt["_wl_uciname"] end
  lt["_wl_uciname"] = M.voice_services_get_uci_name(_,"warmline")
  return lt["_wl_uciname"]
end

function M.voice_profile_get_available_secname(_,_,lt)
  if lt._maps_store["_sip_profile_name"] then return lt._maps_store["_sip_profile_name"] end
  for idx = 0, huge do
      profile_secname = format("sip_profile_%d", idx)
      if not touci.get("mmpbxrvsipnet", profile_secname) then
         lt._maps_store["_sip_profile_name"] = profile_secname
         -- add profile name to the list in services
         M.voice_profile_based_services_add_profile(profile_secname)
         break
      end
  end
  return lt._maps_store["_sip_profile_name"]
end

function M.voice_uamap_get_uci_secname(_,_,legacy_attribute_t)
  if not legacy_attribute_t._maps_store["_uamap_uci_secname"] then
     legacy_attribute_t._maps_store["_uamap_uci_secname"] = legacy_attribute_t._maps_store["_ucicmd_result"]
  end
  return legacy_attribute_t._maps_store["_uamap_uci_secname"]
end

function M.voice_portmap_get_uci_secname(dev_name)
  if dev_name then
     --Find the outgoing_map Section name for given dev_name
     local outgoing_map = touci.get_config_type("mmpbx", "outgoing_map")
     for _,outmap in pairs(outgoing_map) do
         if outmap["device"] == dev_name then
	    return outmap[".name"]
	 end
     end
     --Outgoing map for given device is not available, add the outgoing map
     local ucicmd = {}
     ucicmd.uci_config = "mmpbx"
     ucicmd.uci_sectype = "outgoing_map"
     ucicmd.action = "add"

     append_commit_list(ucicmd.uci_config)
     local sec_name = touci.touci(ucicmd)

     M.set_each_section("mmpbx", sec_name, "device", dev_name)

     return sec_name
  end
end

function M.voice_portmap_add_list_items(path, option, new_items)
  local list = {}
  if not path or not option or not new_items then return list end
  local cur_list = touci.get_all(format("%s.%s.%s", "mmpbx", path, option))
  if cur_list then
     -- we currently only support add a single string as new item
     if type(new_items) == "string" then
        cur_list[#cur_list+1] = new_items
        list = cur_list
     end
  else
     if type(new_items) == "string" then
        list[1] = new_items
     end
  end
  return list
end

local magic_char_map = {
  ["("] = "%(",
  [")"] = "%)",
  ["["] = "%[",
  ["]"] = "%]",
  ["."] = "%.",
  ["*"] = "%*",
  ["+"] = "%+",
  ["?"] = "%?",
  ["-"] = "%-",
  ["^"] = "%^",
  ["$"] = "%$",
  ["%"] = "%%",
}

-- This function is used when we want the string as a part of new pattern
-- but the string should not have any Lua regexp
function M.escape_lua_magic_char(s)
  return s and s:gsub("%p", magic_char_map) or ""
end

return M
