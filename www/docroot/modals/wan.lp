--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local vdf_helper = require("vodafone_helper")
local proxy = require("datamodel")
local string = string
local format, match, untaint, sub, ipairs, pairs, tolower  = string.format, string.match, string.untaint, string.sub, ipairs, pairs, string.lower
local setmetatable = setmetatable
local sort = table.sort
local json = require("dkjson")
local adslPath = {}
local vdslPath = {}
local ethPath = {}
local dnsTable = {}
local untaint_mt = require("web.taint").untaint_mt
local gVIES = post_helper.getValidateInEnumSelect
local networkPath = "uci.network.interface."
local xtmPath = "uci.xtm.atmdevice."
local flagTable = {}

local ignoreInterface = {
  ["voip"] = true,
  ["wan6"] = true,
  ["iptv"] = true,
  ["lan"] = true,
  ["loopback"] = true,
  ["dummy"] = true,
}

local dataInterface = {
  ["vlanptm0"] = true,
  ["vlanwan"] = true,
  ["atm_wan"] = true,
}
dataInterface = setmetatable(dataInterface, untaint_mt)

local iptvInterface = {
}
iptvInterface = setmetatable(iptvInterface, untaint_mt)

local voiceInterface = {
}
voiceInterface = setmetatable(voiceInterface, untaint_mt)

local protoEnum = {
 { "ipoa" , "IPoA" },
 { "ipoe" , "IPoE" },
 {"pppoa" , "PPPoA"},
 {"pppoe" , "PPPoE"},
}

local authenticationMethod = {
  {"auto", "AUTO"},
  {"chap", "CHAP"},
  {"pap", "PAP"},
}

local pppdList = {
  ["chap"] = "refuse-pap refuse-eap refuse-mschap refuse-mschap-v2",
  ["pap"]  = "refuse-chap refuse-eap refuse-mschap refuse-mschap-v2",
  ["auto"] = "",
}

local params= {"ifname", "auto", "ipv6", "proto", "vpi", "vci", "service", "pppd_options", "demand", "keepalive", "mtu", "peerdns", "username", "password", "ipaddr", "netmask", "gateway", "hostname", "vendorid", "clientid", "sendopts"}

-- Validation authmethod to Validate authenticationMethod dropdown
-- @param value: currentvalue for dropdown
-- @param object :contains list of post arguments
-- @param key : param name to which validation needs to happen
-- @return boolean
local function validationAuthMethod(value, object, key)
  if object["proto"] == "pppoe"  or object["proto"] == "pppoa" then
    if (key == "authmethod") then
      local validAuth = gVIES(authenticationMethod)
      local valiauth = validAuth(value)
      return validAuth(value)
    end
  end
   return true
end

-- validations for IPadress and subnet field.
-- @param value: currentvalue of Textbox
-- @param object :contains list of post arguments
-- @param key : param name to which validation needs to happen
-- @return boolean
local function validationIPandSubnet(value, object, key)
  if object["proto"] == "ipoe"  or object["proto"] == "ipoa" then
    if object["ipaddressmode"]== "static" then
      return post_helper.validateStringIsIP(value)
    end
  end
  if object["data"] == "adsl" then
    local validvpi = post_helper.getValidateNumberInRange(0, 255)
    local validvci = post_helper.getValidateNumberInRange(32, 65535)
    if not (validvpi(tonumber(object["vpi"])) and validvci(tonumber(object["vci"]))) then
      return nil
    end
  end
   return true
end

-- Validations for primaryDNS and secondaryDNS
-- Validations will performed only when peerdns value set 0
-- @param  value : DNS Value
-- @param object : contains list of post arguments
-- @param key : param name to which validation needs to happen
-- @return boolean
local function validationsForDNS(value, object, key)
  if object["obtdns"] == "0" then
    return post_helper.validateStringIsIP(value)
  end
  return true
end

-- Validation for parameter MTU
-- @param value: contains post values for parameter MTU
-- @param object : contains list of post arguments
-- @param key : param name to which validation needs to happen
-- @return boolean
local function isValidMTU(value, object, key)
   if object["proto"] == "pppoe"  or object["proto"] == "pppoa" then
      local validMTU = post_helper.getValidateNumberInRange(68, 1500)
      if not validMTU(tonumber(value)) then
       return nil
      end
   end
   return true
end

-- validateWanData will validate entire postdata
-- @param postInfo: contains all post data
-- return boolean, based on validation result
local function validateWanData(postInfo)
  local postContent, postValidations
  for _, postData in ipairs(postInfo) do
    if not postData["change"]  then
       postContent = {
        firewall     = postData["firewall"],
        qos          = postData["qos"],
        authmethod   = postData["authmethod"],
        nat          = postData["nat"],
        ipv6         = postData["ipv6"],
        proto        = postData["proto"],
        wansubnet    = postData["wansubnet"],
        conntigger   = postData["conntigger"],
        obtdns       = postData["obtdns"],
        wanip        = postData["wanip"],
        ipaddressmode= postData["ipaddressmode"],
        data         = postData["data"],
        vpi          = postData["vpi"],
        vci          = postData["vci"],
        mtu          = postData["mtu"],
        primaryDNS   = postData["primaryDNS"],
        secondaryDNS = postData["secondaryDNS"],
        auto         = postData["auto"],
      }

      postValidations = {
        firewall     = post_helper.validateBoolean,
        qos          = post_helper.validateBoolean,
        authmethod   = validationAuthMethod,
        nat          = post_helper.validateBoolean,
        ipv6         = post_helper.validateBoolean,
        proto        = gVIES(protoEnum),
        wansubnet    = post_helper.getOptionalValidation(validationIPandSubnet),
        conntigger   = post_helper.validateBoolean,
        wanip        = post_helper.getOptionalValidation(validationIPandSubnet),
        obtdns       = post_helper.validateBoolean,
        mtu          = post_helper.getOptionalValidation(isValidMTU),
        primaryDNS   = validationsForDNS,
        secondaryDNS = validationsForDNS,
        auto         = post_helper.validateBoolean,
      }
    else
      postContent = {
        auto  = postData["auto"],
      }
      postValidations = {
        auto = post_helper.validateBoolean,
      }
    end
    if  not (content_helper.validateObject(postContent, postValidations)) then
      return nil
    end
  end
  return true
end

-- if post action triggered from client. all post data will be verified.
-- and set operation will be happen in server and response will be returned to server.
if ngx.req.get_method() == "POST" then
  ngx.header.content_type = "application/json"
  local postArgs = ngx.req.get_post_args()
  local tableList = json.decode(untaint(postArgs.tableRequest), 1, nil)
  tableList = setmetatable(tableList, untaint_mt)
  local updateList = tableList.UPDATE
  local postData = {}
  for  index, data in ipairs(updateList) do
  postData[#postData +1] = {}
   for _, info in ipairs(data) do
    if info.change then
      postData[#postData] = info 
    else
     postData[#postData][info.name] = info.value
    end
   end
  end
  local setTable = {}
  if  validateWanData(postData) then
    for _, key in ipairs(postData) do
      if not key["change"] then
        if key["proto"] ~= "pppoe" and key["proto"] ~= "pppoa"  then
          if key["ipaddressmode"] == "static" then
            setTable[format("%s@%s.proto",networkPath, key.intf)] = "static"
          else
            setTable[format("%s@%s.proto",networkPath, key.intf)] = "dhcp"
          end
          if key["data"] == "adsl" then
            if key["proto"] == "ipoe" then
              setTable[format("%s@%s.ulp", xtmPath, key.ifname)] = "eth"
           else
              setTable[format("%s@%s.ulp", xtmPath, key.ifname)] = "ip"
            end
          end
        else
          setTable[format("%s@%s.proto",networkPath, key.intf)] = key["proto"]
          if key["ipv6flag"] == "1" then
            if key["vlanname"] ~= "" then
              setTable[format("uci.network.device.@%s.ipv6", key.vlanname)] =  key["ipv6"]
            else
              if key["ifname"] ~= "eth4" then
                setTable[format("uci.network.device.@%s.ipv6", key["devname"])] =  key["ipv6"]
              end
            end
          end

          setTable[format("%s@%s.username", networkPath, key.intf)] =  key["username"]
	  if (key["password"] ~= "********") then
          setTable[format("%s@%s.password", networkPath, key.intf)] =  key["password"]
          end
          setTable[format("%s@%s.service", networkPath, key.intf)] =  key["servname"]
          if key["authflag"] == "1" then
          setTable[format("%s@%s.pppd_options", networkPath, key.intf)] =  pppdList[key.authmethod]
          end
          setTable[format("%s@%s.demand", networkPath, key.intf)] =  key["conntigger"] ~= "0" and key["conntigger"] or ""
          setTable[format("%s@%s.keepalive", networkPath, key.intf)] =  key["lcpecho"]
          setTable[format("%s@%s.mtu", networkPath, key.intf)] =  key["mtu"]
          if key["dnsflag"] == "1" then
            setTable[format("%s@%s.peerdns", networkPath, key.intf)] =  key["obtdns"]
          end
          if key["obtdns"] == "0" then
            proxy.del(format("%s@%s.dns.",networkPath,key.intf))
            local primaryindex = proxy.add(format("%s@%s.dns.",networkPath,key.intf))
            local secondaryindex = proxy.add(format("%s@%s.dns.",networkPath,key.intf))
            setTable[format("%s@%s.dns.@1.value",networkPath, key.intf)] = key["primaryDNS"]
            setTable[format("%s@%s.dns.@2.value",networkPath, key.intf)] = key["secondaryDNS"]
          end
        end
        setTable["rpc.network.firewall.enable"] = key["firewall"]
        setTable[format("uci.firewall.zone.%s.masq",key.natindex)] = key["nat"]
        setTable[format("uci.qos.device.@%s.enable", key.ifname)] = key["qos"]
        setTable[format("%s@%s.auto", networkPath, key.intf)] = key["auto"]
        if key["ipaddressmode"] == "static" then
          setTable[format("%s@%s.ipaddr",networkPath, key.intf)] = key["wanip"]
          setTable[format("%s@%s.netmask", networkPath, key.intf)] = key["wansubnet"]
          setTable[format("%s@%s.gateway", networkPath, key.intf)] = key["wangw"]
        end
        if key["data"] == "adsl" then
          setTable[format("%s@%s.vpi", xtmPath, key.ifname)]  = key["vpi"]
          setTable[format("%s@%s.vci", xtmPath, key.ifname)]  = key["vci"]
        else
          if key.vlanname ~= "" then
            setTable[format("uci.network.device.@%s.vid", key.vlanname)]  = key["vci"]
          end
          if iptvInterface[key.ifname] or  iptvInterface[key.vlanname] then
            setTable["uci.qos.label.@IPTV.pcp"]  = key["vpi"]
          elseif voiceInterface[key.ifname] or  voiceInterface[key.vlanname]then
            setTable["uci.qos.label.@VoIP_traffic.pcp"]  = key["vpi"]
          else
            setTable["uci.qos.interface.@wan.pcp"]  = key["vpi"]
          end
        end
      else
        setTable[format("%s@%s.auto", networkPath, key.intf)] = key["auto"]
      end
    end
    proxy.set(setTable)
    proxy.apply()
    ngx.print('{"status":"success"}')
  else
    ngx.print('{"status":"error"}')
  end
  ngx.exit(ngx.HTTP_OK)
end

-- retrieving all network interface path
local interfacesList = proxy.getPN(networkPath, true)

-- get operation for firewall parameter.
local wanCommonGet = {
 ["firewall"] = "rpc.network.firewall.enable",
 ["wanpbit"] = "uci.qos.interface.@wan.pcp",
 ["voicepbit"] = "uci.qos.label.@VoIP_traffic.pcp",
 ["iptvpbit"] = "uci.qos.label.@IPTV.pcp",
 ["l3type"] = "uci.wansensing.global.l3type",
}content_helper.getExactContent(wanCommonGet)

-- Common Function to collect all parameter path for tables.
-- @param path contains datamodel path
-- @param intf conatain interfaceName
-- @detail which conatain table name
-- @tablePath contain previously saved path for table
-- @return constructed table
local function constructPathDetails(path, intf, detail, tablePath)
  for _, param in ipairs(params) do
    if (param == "vpi"  and detail == "adsl") then
      tablePath[#tablePath+1] = path..param
    elseif (param == "vci"  and detail == "adsl") then
      tablePath[#tablePath+1] = path..param
    elseif param ~= "vpi" and param ~= "vci" then
       tablePath[#tablePath+1] = path..param
    end
  end
   tablePath[#tablePath+1] = format("rpc.network.interface.@%s.up", intf)
   return tablePath
end

-- Based on network interface path. All necessary parameter path stored in table, according to classfication.
-- @param interfaceList contains all path for network interface.
-- @return table for adslPath, vdslPath, ethPath, mobilePath contains get path for required parameter.
for _, path in pairs(interfacesList) do
  local Intf = match(path.path, "@(.+)%.")
  if not ignoreInterface[Intf] then
    local interfaceName = proxy.get(path.path.."ifname")[1].value
    -- if interface contains word as "vlan", corepsonding ifname will retrieved from network device.
    if match(interfaceName, "^vlan") then
      local vlanInterfaceName = proxy.get("uci.network.device.@"..interfaceName..".ifname")[1].value
      if match(vlanInterfaceName, "^atm") then
        adslPath = constructPathDetails(path.path, Intf, "adsl", adslPath)
      -- Collecting all necassary path for vdsl table
      elseif match(vlanInterfaceName, "^ptm") then
        vdslPath = constructPathDetails(path.path, Intf, "vdsl", vdslPath)
      -- Collecting all parameter path for fiber table
      elseif match(vlanInterfaceName, "^eth") then
        ethPath = constructPathDetails(path.path, Intf, "fiber", ethPath)
      end
    end
    if match(interfaceName,"^eth4") then
      ethPath = constructPathDetails(path.path, Intf, "fiber", ethPath)
    end
    if match(interfaceName,"^ptm") then
      vdslPath = constructPathDetails(path.path, Intf, "vdsl", vdslPath)
    end
    -- Collecting all necassary path for adsl related table.
    if match(interfaceName,"^atm") then
      adslPath = constructPathDetails(path.path, Intf, "adsl" ,adslPath)
    end
  end
end

-- Get operation for adsl related parameters and table will be
-- formed according to interface name.
local adslInfo = {}
local adslPaths = proxy.get(unpack(adslPath))
if adslPaths then
  for _, data in ipairs (adslPaths) do
    local interface = match(data.path,"@(.+)%.")
    if not(adslInfo[interface]) then
      adslInfo[interface] = {}
    end
    if data.param == "ifname" then
      if match(data.value, "^vlan") then
        adslInfo[interface].vlanname = data.value
        adslInfo[interface][data.param] = proxy.get("uci.network.device.@"..data.value..".ifname")[1].value
        adslInfo[interface].ipv6 = proxy.get("uci.network.device.@"..data.value..".ipv6")[1].value
      else
        adslInfo[interface].devname = data.value
        adslInfo[interface][data.param] = data.value
      end
    else
      adslInfo[interface][data.param] = data.value
    end
  end
end

-- Get operation for vdsl related parameters and table will be
-- formed according to interface name.
local vdslInfo = {}
local vdslPaths = proxy.get(unpack(vdslPath))
if vdslPaths then
  for _, data in ipairs(vdslPaths) do
    local vdslinterface = match(data.path,"@(.+)%.")
    if not(vdslInfo[vdslinterface]) then
      vdslInfo[vdslinterface] = {}
    end
    if data.param == "ifname" then
      if match(data.value, "^vlan") then
        vdslInfo[vdslinterface].vlanname = data.value
        vdslInfo[vdslinterface].vid = proxy.get("uci.network.device.@"..data.value..".vid")[1].value
        vdslInfo[vdslinterface][data.param] = proxy.get("uci.network.device.@"..data.value..".ifname")[1].value
        vdslInfo[vdslinterface].ipv6 = proxy.get("uci.network.device.@"..data.value..".ipv6")[1].value
      else
        vdslInfo[vdslinterface].devname = data.value
        vdslInfo[vdslinterface][data.param] = data.value
      end
    else
      vdslInfo[vdslinterface][data.param] = data.value
    end
  end
end

-- Get operation for fiber related parameters and table will be
-- formed according to interface name.
local ethInfo = {}
local ethPaths = proxy.get(unpack(ethPath))
if ethPaths then
  for _, data in ipairs(ethPaths) do
    local ethinterface = match(data.path,"@(.+)%.")
    if not(ethInfo[ethinterface]) then
      ethInfo[ethinterface] = {}
    end
    if data.param == "ifname" then
      if match(data.value, "^vlan") then
        ethInfo[ethinterface].vlanname = data.value
        ethInfo[ethinterface].vid = proxy.get("uci.network.device.@"..data.value..".vid")[1].value
        ethInfo[ethinterface][data.param] = proxy.get("uci.network.device.@"..data.value..".ifname")[1].value
        ethInfo[ethinterface].ipv6 = proxy.get("uci.network.device.@"..data.value..".ipv6")[1].value
      else
        ethInfo[ethinterface].devname = data.value
        ethInfo[ethinterface][data.param] = data.value
      end
    else
      ethInfo[ethinterface][data.param] = data.value
    end
  end
end

-- Collecting qos  related information based on interfacename.
-- qosTable will formed with interface name and enabled parameter value.
local qosData = content_helper.convertResultToObject("uci.qos.device.",proxy.get("uci.qos.device."))
local qosTable = {}
for _, data in ipairs(qosData) do
  qosTable[match(data.paramindex,"@(.*)")] = data.enable
end
qosTable = setmetatable(qosTable, untaint_mt)

-- Collecting all vpi and vci from xtm.atmdevice
-- table will be formed according to interface name contains all vpi and vci and ulp information.
local vpiData = content_helper.convertResultToObject(xtmPath, proxy.get(xtmPath))
local vpiTable = {}
for _, data in ipairs(vpiData) do
   local vpiInterface = match(data.paramindex,"@(.*)")
   if not (vpiTable[vpiInterface]) then
      vpiTable[vpiInterface] = {}
   end
      vpiTable[vpiInterface].vpi = data.vpi
      vpiTable[vpiInterface].vci = data.vci
      vpiTable[vpiInterface].ulp = data.ulp
end
vpiTable = setmetatable(vpiTable, untaint_mt)

-- Collecting all firewall information for all interfacesList
-- based on zone information, interfaces are matched and enable parameter information
-- will be stored in table along with index number
local zoneList = proxy.getPN("uci.firewall.zone.", true)
local zoneEnabled, zoneData = {} , {}
for _, zone in pairs(zoneList) do
  zoneEnabled["enabled"] = zone.path.."masq"
  zoneEnabled["name"] = zone.path.."name"
  content_helper.getExactContent(zoneEnabled)
  local index = match(zone.path, "uci%.firewall%.zone%.(%d+)")
  zoneData[zoneEnabled["name"]] = content_helper.convertResultToObject(zone.path.."network.", proxy.get(zone.path.."network."))
  zoneData[zoneEnabled["name"]].enable = zoneEnabled["enabled"]
  zoneData[zoneEnabled["name"]].index = index
end

-- Collecting all nat information for all interfacesList
-- if interfaces are matched and enable parameter information
-- will be stored in table along with index number
local natInfo = {}
for  intf, data in pairs(zoneData) do
  if intf ~= "lan" then
    for _, v in ipairs(data) do
     if not natInfo[untaint(v.value)] then
      natInfo[untaint(v.value)] = {}
     end
      natInfo[untaint(v.value)].enable = data.enable
      natInfo[untaint(v.value)].index = data.index
    end
  end
end

-- Collecting DNS information for all interfaces
-- DNS information collected based on checking list dns information
-- avialable for particular interface.
for _, path in pairs(interfacesList) do
  local Intf = match(path.path, "@(.+)%.")
  if not ignoreInterface[Intf] then
    local dnsList = proxy.get(networkPath.."@"..Intf..".dns.")
    if next(dnsList) then
      if not dnsTable[Intf] then
       dnsTable[Intf] = {}
      end
       dnsTable[Intf].primaryDNS = dnsList[1].value
       dnsTable[Intf].secondaryDNS = dnsList[2].value
    end
  end
end

-- In order to sort interface table based on interface name.
-- Based on key name table data are sorted.
local function __genOrderedIndex( t )
  local orderedIndex = {}
  for key in pairs(t) do
    table.insert( orderedIndex, key )
  end
  table.sort( orderedIndex , function (a, b) return a:upper() < b:upper() end )
  return orderedIndex
end

local function orderedNext(t, state)
  key = nil
  if state == nil then
    t.__orderedIndex = __genOrderedIndex( t )
    key = t.__orderedIndex[1]
  else
    for i = 1,#t.__orderedIndex do
      if t.__orderedIndex[i] == state then
        key = t.__orderedIndex[i+1]
      end
    end
  end
  if key then
    return key, t[key]
  end
  t.__orderedIndex = nil
  return
end

local function orderedPairs(t)
  return orderedNext, t, nil
end   ngx.print('\
<!-- WAN ADSL -->\
<div id="content" class="content-wan">\
    <h1>');  ngx.print(T"WAN"); ngx.print('</h1>\
    <h2>&nbsp;</h2>\
    <h3>');  ngx.print(T"WAN ADSL"); ngx.print('</h3>\
    <div class="h3-content table-responsive" id="wan-adsl">\
        <div class="table wan-adsl no-margin-bottom">\
            <div class="table-row table-row-head">\
                <div class="table-col">\
                    <span>');  ngx.print(T"Description"); ngx.print('</span> </div>\
                <div class="table-col">\
                    <span>');  ngx.print(T"Protocol"); ngx.print('</span> </div>\
                <div class="table-col">\
                    <span>');  ngx.print(T"QoS"); ngx.print('</span> </div>\
                <div class="table-col">\
                    <span>');  ngx.print(T"Status"); ngx.print('</span> </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
            </div>\
            ');  for intf, data in orderedPairs(adslInfo) do
               if not flagTable[data.ifname] then
                flagTable[data.ifname] = {}
               end
              flagTable[data.ifname].ipv6  = data.ipv6
              flagTable[data.ifname].obtdns  = data.peerdns
              flagTable[data.ifname].auth  = data.pppd_options
              ngx.print('\
                <div class="table-row">\
                    <input type="hidden" class="proto"  name="proto"  value="');  ngx.print(data.proto); ngx.print('">\
                    <input type="hidden" class="intf"  name="intf"  value="');  ngx.print(intf); ngx.print('">\
                    <input type="hidden" class="username" name="username" id= "wan-hid-username" value="');  ngx.print(data.username); ngx.print('">\
                    <input type="hidden" class="password" name="password" id = "wan-hid-password" value="');  ngx.print(vdf_helper.createInputPassword(data.password)); ngx.print('">\
                    <input type="hidden" class="servname" name="servname" id= "wan-hid-servname" value="');  ngx.print(data.service); ngx.print('">\
                    <input type="hidden" class="authmethod" name="authmethod" id="wan-hid-authmethod" value="');  ngx.print(data.pppd_options); ngx.print('">\
                    <input type="hidden" class="conntigger"  name="conntigger" id="wan-hid-conntigger" value="');  ngx.print(data.demand); ngx.print('">\
                    <input type="hidden" class="lcpecho" name="lcpecho" id="wan-hid-lcpecho" value="');  ngx.print(data.keepalive); ngx.print('">\
                    <input type="hidden" class="mtu" name="mtu" id="wan-hid-mtu" value="');  ngx.print(data.mtu); ngx.print('">\
                    <input type="hidden" class="obtdns" name="obtdns"  id="wan-hid-obtdns" value="');  ngx.print(data.peerdns); ngx.print('">\
                    <input type="hidden" class="firewall" name="firewall" id="wan-hid-firewall" value="');  ngx.print(wanCommonGet.firewall); ngx.print('">\
                    <input type="hidden" class="qos" name="qos" id="wan-hid-qos" value="');  ngx.print(qosTable[data.ifname]); ngx.print('">\
                    <input type="hidden" class="nat" name="nat" id="wan-hid-nat" value="');  ngx.print(natInfo[intf].enable); ngx.print('">\
                    <input type="hidden" class="natindex" name="natindex" id="wan-hid-nat1" value="');  ngx.print(natInfo[intf].index); ngx.print('">\
                    <input type="hidden" class="wanip" name="wanip" id="wan-hid-wanip" value="');  ngx.print(data.ipaddr); ngx.print('">\
                    <input type="hidden" class="wansubnet" name="wansubnet" id="wan-hid-wansubnet" value="');  ngx.print(data.netmask); ngx.print('">\
                    <input type="hidden" class="wangw" name="wangw" id="wan-hid-wangw" value="');  ngx.print(data.gateway); ngx.print('">\
                    <input type="hidden" class="ifname" name="ifname" id="wan-hid-ifname" value="');  ngx.print(data.ifname); ngx.print('">\
                    <input type="hidden" class="vci_vlanid" name="vci" id="wan-hid-vci" value="');  ngx.print(vpiTable[data.ifname].vci); ngx.print('">\
                    <input type="hidden" class="vpi_802priority" name="vpi" id="wan-hid-vpi" value="');  ngx.print(vpiTable[data.ifname].vpi); ngx.print('">\
                    <input type="hidden" class="ulp" name="ulp" id="wan-hid-ulp" value="');  ngx.print(vpiTable[data.ifname].ulp); ngx.print('">\
                    <input type="hidden" class="ipv6" name="ipv6" value="');  ngx.print(data.ipv6); ngx.print('">\
                    <input type="hidden" class="data" name="data" value="adsl">\
                    <input type="hidden" class="ipaddressmode" name="ipaddressmode" value="">\
                    <input type="hidden" class="auto" name="auto" value="');  ngx.print(data.auto); ngx.print('">\
                    <input type="hidden" class="vlanname" name="vlanname" value=\'');  ngx.print(data.vlanname and data.vlanname or ""); ngx.print('\'>\
                    <input type="hidden" class="ipv6flag" name="ipv6flag" value="">\
                    <input type="hidden" class="dnsflag" name="dnsflag" value="">\
                    <input type="hidden" class="authflag" name="authflag" value="">\
                    <input type="hidden" class="devname" name="devname" value=\'');  ngx.print(data.devname and data.devname or ""); ngx.print('\'>\
                    <input type="hidden" class="primaryDNS" name="primaryDNS" value="');  ngx.print(dnsTable[intf] and dnsTable[intf].primaryDNS or "" ); ngx.print('">\
                    <input type="hidden" class="secondaryDNS" name="secondaryDNS" value="');  ngx.print(dnsTable[intf] and dnsTable[intf].secondaryDNS or ""  ); ngx.print('">\
                    <div class="table-col">\
                        <span>');  ngx.print(intf); ngx.print('</span> </div>\
                    <div class="table-col table-proto">\
                        <span> ');  ngx.print(data.proto); ngx.print('</span> </div>\
                    <div class="table-col table-qos">\
                        <span>');  if tonumber(qosTable[data.ifname]) ~= 0 then  ngx.print(T"Enabled"); ngx.print(' ');  else  ngx.print(' ');  ngx.print(T"Disabled"); end  ngx.print(' </span> </div>\
                    <div class="table-col">\
                        ');  if dataInterface[data.ifname] or dataInterface[data.vlanname] then   ngx.print('\
                           <span>');  if tolower(intf) == "wan" then  if data.up ~= "0" then  ngx.print(T"Connected"); else  ngx.print(T"Connecting"); end else  ngx.print(T"Unconfigured"); end  ngx.print('</span>\
                        ');  else  ngx.print('\
                          <span>');  if data.up ~= "0" then  ngx.print(T"Connected"); else  ngx.print(T"Unconfigured"); end  ngx.print('</span>\
                        ');  end   ngx.print('\
                    </div>\
                    <div class="table-col">\
                      ');  if not iptvInterface[data.ifname] and not iptvInterface[data.vlanname] then   ngx.print('\
                        <input class="button button-edit wan-edit" type="button" data-toggle="modal" data-target="#wanadsl-edit-popup">\
                      ');  end   ngx.print('\
                    </div>\
                    <div class="table-col">\
                       <!-- <input class="button button-delete" type="button">-->\
\
                    </div>\
                    <div class="table-col fR tR">\
\
\
                         ');  if not (dataInterface[data.ifname] or dataInterface[data.vlanname]) then    ngx.print('\
                          <div class=\'button  auto-button ');  if data.auto ~= "0" then   ngx.print('button-on');  else  ngx.print('button-off ');  end  ngx.print('\'>\
                        </div>\
                        ');  else   ngx.print('\
                           <div style="text-align:center; width:60px"><span>');  ngx.print(T"Auto"); ngx.print('</span></div>\
                        ');  end   ngx.print('\
                    </div>\
                </div>\
                ');  end  ngx.print('\
\
                    <div class="table-row table-row-last">\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col fR tR">\
                            <!--<input class="button button-add" type="button" data-toggle="modal" data-target="#wanadsl-add-popup"> -->\
                        </div>\
                    </div>\
        </div>\
    </div>\
\
    <!-- WAN VDSL -->\
    <h3><span>');  ngx.print(T"WAN VDSL"); ngx.print('</span></h3>\
    <div class="h3-content table-responsive" id="wan-vdsl">\
        <div class="table wan-vdsl no-margin-bottom">\
            <div class="table-row table-row-head">\
                <div class="table-col">\
                    <span>');  ngx.print(T"Description"); ngx.print('</span> </div>\
                <div class="table-col">\
                    <span>');  ngx.print(T"Protocol"); ngx.print('</span> </div>\
                <div class="table-col">\
                    <span>');  ngx.print(T"QoS"); ngx.print('</span> </div>\
                <div class="table-col">\
                    <span>');  ngx.print(T"Status"); ngx.print('</span> </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
            </div>\
            ');  for intf, data in orderedPairs(vdslInfo) do
                local priority
                if iptvInterface[data.ifname] or  iptvInterface[data.vlanname] then
                  priority = wanCommonGet["iptvpbit"]
                elseif voiceInterface[data.ifname] or  voiceInterface[data.vlanname]then
                  priority = wanCommonGet["voicepbit"]
                else
                  priority = wanCommonGet["wanpbit"]
                end
                if not flagTable[data.vlanname] then
                  flagTable[data.vlanname] = {}
                end
                flagTable[data.vlanname].ipv6  = data.ipv6
                flagTable[data.vlanname].obtdns  = data.peerdns
                flagTable[data.vlanname].auth  = data.pppd_options
              ngx.print('\
                <div class="table-row">\
                    <input type="hidden" class="intf"  name="intf"  value="');  ngx.print(intf); ngx.print('">\
                    <input type="hidden" class="proto"  name="proto"   value="');  ngx.print(data.proto); ngx.print('">\
                    <input type="hidden" class="username" name="username"  value="');  ngx.print(data.username); ngx.print('">\
                    <input type="hidden" class="password" name="password"  value="');  ngx.print(vdf_helper.createInputPassword(data.password)); ngx.print('">\
                    <input type="hidden" class="servname" name="servname"  value="');  ngx.print(data.service); ngx.print('">\
                    <input type="hidden" class="authmethod" name="authmethod"  value="');  ngx.print(data.pppd_options); ngx.print('">\
                    <input type="hidden" class="conntigger"  name="conntigger"  value="');  ngx.print(data.demand); ngx.print('">\
                    <input type="hidden" class="lcpecho" name="lcpecho"  value="');  ngx.print(data.keepalive); ngx.print('">\
                    <input type="hidden" class="mtu" name="mtu"  value="');  ngx.print(data.mtu); ngx.print('">\
                    <input type="hidden" class="obtdns" name="obtdns"   value="');  ngx.print(data.peerdns); ngx.print('">\
                    <input type="hidden" class="firewall" name="firewall"  value="');  ngx.print(wanCommonGet.firewall); ngx.print('">\
                    <input type="hidden" class="qos" name="qos"  value="');  ngx.print(qosTable[data.ifname]); ngx.print('">\
                    <input type="hidden" class="nat" name="nat" id="wan-hid-nat" value="');  ngx.print(natInfo[intf].enable);  ngx.print('">\
                    <input type="hidden" class="natindex" name="natindex" id="wan-hid-nat1" value="');  ngx.print(natInfo[intf].index); ngx.print('">\
                    <input type="hidden" class="wanip" name="wanip"  value="');  ngx.print(data.ipaddr); ngx.print('">\
                    <input type="hidden" class="wansubnet" name="wansubnet"  value="');  ngx.print(data.netmask); ngx.print('">\
                    <input type="hidden" class="wangw" name="wangw"  value="');  ngx.print(data.gateway); ngx.print('">\
                    <input type="hidden" class="ifname" name="ifname"  value="');  ngx.print(data.ifname); ngx.print('">\
                    <input type="hidden" class="vpi_802priority" name="vpi"  value="');  ngx.print(priority); ngx.print('">\
                    <input type="hidden" class="vci_vlanid" name="vci"  value="');  ngx.print(data.vid); ngx.print('">\
                    <input type="hidden" class="ipv6" name="ipv6" value="');  ngx.print(data.ipv6); ngx.print('">\
                    <input type="hidden" class="data" name="data" value="vdsl">\
                    <input type="hidden" class="ipaddressmode" name="ipaddressmode" value="">\
                    <input type="hidden" class="auto" name="auto" value="');  ngx.print(data.auto); ngx.print('">\
                    <input type="hidden" class="vlanname" name="vlanname" value=\'');  ngx.print(data.vlanname and data.vlanname or "" ); ngx.print('\'>\
                    <input type="hidden" class="ipv6flag" name="ipv6flag" value="">\
                    <input type="hidden" class="dnsflag" name="dnsflag" value="">\
                    <input type="hidden" class="authflag" name="authflag" value="">\
                    <input type="hidden" class="devname" name="devname" value=\'');  ngx.print(data.devname and data.devname or ""); ngx.print('\'>\
                    <input type="hidden" class="primaryDNS" name="primaryDNS" value="');  ngx.print(dnsTable[intf] and dnsTable[intf].primaryDNS or ""); ngx.print('">\
                    <input type="hidden" class="secondaryDNS" name="secondaryDNS" value="');  ngx.print(dnsTable[intf] and dnsTable[intf].secondaryDNS or ""); ngx.print('">\
                    <div class="table-col">\
                        <span>');  ngx.print(intf); ngx.print('</span> </div>\
                    <div class="table-col table-proto">\
                        <span> ');  ngx.print(data.proto); ngx.print('</span> </div>\
                    <div class="table-col table-qos">\
                    <span>');  if tonumber(qosTable[data.ifname]) ~= 0 then  ngx.print(T"Enabled"); ngx.print(' ');  else  ngx.print(' ');  ngx.print(T"Disabled"); end  ngx.print(' </span> </div>\
                    <div class="table-col">\
                       ');  if dataInterface[data.ifname] or dataInterface[data.vlanname] then   ngx.print('\
                            <span>');  if tolower(intf) == "wan" then  if data.up ~= "0" then  ngx.print(T"Connected"); else  ngx.print(T"Connecting"); end else  ngx.print(T"Unconfigured"); end  ngx.print('</span>\
                        ');  else  ngx.print('\
                          <span>');  if data.up ~= "0" then  ngx.print(T"Connected"); else  ngx.print(T"Unconfigured"); end  ngx.print('</span>\
                        ');  end   ngx.print('\
                    </div>\
                    <div class="table-col">\
                      ');  if not iptvInterface[data.ifname] and not iptvInterface[data.vlanname] then   ngx.print('\
                        <input class="button button-edit wan-edit" type="button" data-toggle="modal" data-target="#wanadsl-edit-popup"">\
                      ');  end   ngx.print('\
                    </div>\
                    <div class="table-col">\
                        <!--<input class="button button-delete" type="button"> -->\
                    </div>\
                    <div class="table-col fR tR">\
\
                        ');  if not (dataInterface[data.ifname] or dataInterface[data.vlanname]) then    ngx.print('\
                          <div class=\'button auto-button ');  if data.auto ~= "0" then   ngx.print('button-on');  else  ngx.print('button-off ');  end  ngx.print('\'>\
                        </div>\
                        ');  else   ngx.print('\
                          <div style="text-align:center; width:60px"><span>');  ngx.print(T"Auto"); ngx.print('</span></div>\
                        ');  end   ngx.print('\
                    </div>\
                </div>\
                ');  end   ngx.print('\
                    <div class="table-row table-row-last">\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col fR tR">\
                           <!-- <input class="button button-add" type="button" data-toggle="modal" data-target="#wanadsl-edit-popup"> -->\
                        </div>\
                    </div>\
        </div>\
    </div>\
\
    <!-- WAN FIBER -->\
    <h3><span>');  ngx.print(T"WAN FIBRE"); ngx.print('</span></h3>\
    <div class="h3-content table-responsive" id="wan-fiber">\
        <div class="table wan-fiber no-margin-bottom">\
            <div class="table-row table-row-head">\
                <div class="table-col">\
                    <span>');  ngx.print(T"Description"); ngx.print('</span>\
                </div>\
                <div class="table-col">\
                    <span>');  ngx.print(T"Protocol"); ngx.print('</span>\
                </div>\
                <div class="table-col">\
                    <span>');  ngx.print(T"QoS"); ngx.print('</span> </div>\
                <div class="table-col">\
                    <span>');  ngx.print(T"Status"); ngx.print('</span> </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
            </div>\
            ');  for intf, data in orderedPairs(ethInfo) do
              local priority
                if iptvInterface[data.ifname] or  iptvInterface[data.vlanname] then
                  priority = wanCommonGet["iptvpbit"]
                elseif voiceInterface[data.ifname] or  voiceInterface[data.vlanname]then
                  priority = wanCommonGet["voicepbit"]
                else
                  priority = wanCommonGet["wanpbit"]
                end
                if data.vlanname then
                  if not flagTable[data.vlanname] then
                    flagTable[data.vlanname] = {}
                   end
                  flagTable[data.vlanname].ipv6  = data.ipv6
                  flagTable[data.vlanname].obtdns  = data.peerdns
                  flagTable[data.vlanname].auth  = data.pppd_options
                else
                  flagTable[data.devname] = {}
                  flagTable[data.devname].ipv6  = data.ipv6 and data.ipv6  or ""
                  flagTable[data.devname].obtdns  = data.peerdns
                  flagTable[data.devname].auth  = data.pppd_options
                end
              ngx.print('\
                <div class="table-row">\
                    <input type="hidden" class="intf"  name="intf"  value="');  ngx.print(intf); ngx.print('">\
                    <input type="hidden" class="proto"  name="proto"   value="');  ngx.print(data.proto); ngx.print('">\
                    <input type="hidden" class="username" name="username"  value="');  ngx.print(data.username); ngx.print('">\
                    <input type="hidden" class="password" name="password"  value="');  ngx.print(vdf_helper.createInputPassword(data.password)); ngx.print('">\
                    <input type="hidden" class="servname" name="servname"  value="');  ngx.print(data.service); ngx.print('">\
                    <input type="hidden" class="authmethod" name="authmethod"  value="');  ngx.print(data.pppd_options); ngx.print('">\
                    <input type="hidden" class="conntigger"  name="conntigger"  value="');  ngx.print(data.demand); ngx.print('">\
                    <input type="hidden" class="lcpecho" name="lcpecho"  value="');  ngx.print(data.keepalive); ngx.print('">\
                    <input type="hidden" class="mtu" name="mtu"  value="');  ngx.print(data.mtu); ngx.print('">\
                    <input type="hidden" class="obtdns" name="obtdns"   value="');  ngx.print(data.peerdns); ngx.print('">\
                    <input type="hidden" class="firewall" name="firewall"  value="');  ngx.print(wanCommonGet.firewall); ngx.print('">\
                    <input type="hidden" class="qos" name="qos"  value="');  ngx.print(qosTable[data.ifname]); ngx.print('">\
                    <input type="hidden" class="nat" name="nat" id="wan-hid-nat" value="');  ngx.print(natInfo[intf].enable); ngx.print('">\
                    <input type="hidden" class="natindex" name="natindex" id="wan-hid-nat1" value="');  ngx.print(natInfo[intf].index); ngx.print('">\
                    <input type="hidden" class="wanip" name="wanip"  value="');  ngx.print(data.ipaddr); ngx.print('">\
                    <input type="hidden" class="wansubnet" name="wansubnet"  value="');  ngx.print(data.netmask); ngx.print('">\
                    <input type="hidden" class="wangw" name="wangw"  value="');  ngx.print(data.gateway); ngx.print('">\
                    <input type="hidden" class="ifname" name="ifname"  value="');  ngx.print(data.ifname); ngx.print('">\
                    <input type="hidden" class="vpi_802priority" name="vpi"  value="');  ngx.print(priority); ngx.print('">\
                    <input type="hidden" class="vci_vlanid" name="vci"  value="');  ngx.print(data.vid); ngx.print('">\
                    <input type="hidden" class="ipv6" name="ipv6" value="');  ngx.print(data.ipv6); ngx.print('">\
                    <input type="hidden" class="data" name="data" value="eth">\
                    <input type="hidden" class="ipaddressmode" name="ipaddressmode" value="">\
                    <input type="hidden" class="auto" name="auto" value="');  ngx.print(data.auto); ngx.print('">\
                    <input type="hidden" class="vlanname" name="vlanname" value=\'');  ngx.print(data.vlanname and data.vlanname or "" ); ngx.print('\'>\
                    <input type="hidden" class="ipv6flag" name="ipv6flag" value="">\
                    <input type="hidden" class="dnsflag" name="dnsflag" value="">\
                    <input type="hidden" class="authflag" name="authflag" value="">\
                    <input type="hidden" class="devname" name="devname" value=\'');  ngx.print(data.devname and data.devname or ""); ngx.print('\'>\
                    <input type="hidden" class="primaryDNS" name="primaryDNS" value="');  ngx.print(dnsTable[intf] and dnsTable[intf].primaryDNS or ""); ngx.print('">\
                    <input type="hidden" class="secondaryDNS" name="secondaryDNS" value="');  ngx.print( dnsTable[intf] and dnsTable[intf].secondaryDNS or ""); ngx.print('">\
                    <div class="table-col">\
                    <span> ');  ngx.print(intf); ngx.print('</span> </div>\
                    <div class="table-col table-proto">\
                        <span> ');  ngx.print(data.proto); ngx.print('</span> </div>\
                    <div class="table-col table-qos">\
                      <span> ');  if tonumber(qosTable[data.ifname]) ~= 0 then  ngx.print(T"Enabled"); ngx.print(' ');  else  ngx.print(' ');  ngx.print(T"Disabled"); end  ngx.print('</span></div>\
                    <div class="table-col">\
                       ');  if dataInterface[data.ifname] or dataInterface[data.vlanname] then   ngx.print('\
                           <span>');  if tolower(intf) == "wan" then  if data.up ~= "0" then  ngx.print(T"Connected"); else  ngx.print(T"Connecting"); end else  ngx.print(T"Unconfigured"); end  ngx.print('</span>\
                        ');  else  ngx.print('\
                          <span>');  if data.up ~= "0" then  ngx.print(T"Connected"); else  ngx.print(T"Unconfigured"); end  ngx.print('</span>\
                        ');  end   ngx.print('\
                    </div>\
                    <div class="table-col">\
                      ');  if not iptvInterface[data.ifname] and not iptvInterface[data.vlanname] then   ngx.print('\
                        <input class="button button-edit wan-edit" type="button" data-toggle="modal" data-target="#wanadsl-edit-popup">\
                      ');  end   ngx.print('\
                    </div>\
                    <div class="table-col">\
                        <!-- <input class="button button-delete" type="button"> -->\
                    </div>\
                    <div class="table-col fR tR">\
\
                       ');  if not (dataInterface[data.ifname] or dataInterface[data.vlanname]) and data.vlanname then    ngx.print('\
                          <div class=\'button auto-button ');  if data.auto ~= "0" then   ngx.print('button-on');  else  ngx.print('button-off ');  end  ngx.print('\'>\
                        </div>\
                        ');  else   ngx.print('\
                           <div style="text-align:center; width:60px"><span>');  ngx.print(T"Auto"); ngx.print('</span></div>\
                       ');  end  ngx.print('\
                    </div>\
                </div>\
                ');  end   ngx.print('\
                    <div class="table-row table-row-last">\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col fR tR">\
                            <!--<input class="button button-add" type="button" data-toggle="modal" data-target="#wanfiber-add-popup">-->\
                        </div>\
                    </div>\
        </div>\
    </div>\
\
    <!-- WAN MOBILE -->\
    <h3><span>');  ngx.print(T"WAN MOBILE"); ngx.print('</span></h3>\
    <div class="h3-content table-responsive" id="wan-mobile">\
        <div class="table wan-mobile no-margin-bottom">\
            <div class="table-row table-row-head">\
                <div class="table-col">\
                    <span>');  ngx.print(T"Description"); ngx.print('</span>\
                </div>\
                <div class="table-col">\
                    <span></span>\
                </div>\
                <div class="table-col">\
                    <span>');  T"QoS"  ngx.print('</span>\
                </div>\
                <div class="table-col">\
                    <span>');  ngx.print(T"Status"); ngx.print('</span>\
                </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
            </div>\
               <!-- <div class="table-row">\
                    <div class="table-col">\
                        <span></span>\
                    </div>\
                    <div class="table-col">\
                       </span></span>\
                    </div>\
                    <div class="table-col table-qos">\
                     <span>Enabled</span>\
                    </div>\
                    <div class="table-col">\
                       <span>Connected</span>\
                    </div>\
                    <div class="table-col">\
                        <input class="button button-edit wan-edit" type="button" data-toggle="modal" data-target="#wanadsl-edit-popup">\
                    </div>\
                    <div class="table-col">\
                        <!--<input class="button button-delete" type="button">\
                    </div>\
                    <div class="table-col fR tR">\
                        <div class=\'button auto-button button-on\'>\
                        </div>\
                    </div>\
                </div> -->\
                    <div class="table-row table-row-last">\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col">\
                            &nbsp;\
                        </div>\
                        <div class="table-col fR tR ">\
                            <!--<input class="button button-add" type="button" data-toggle="modal" data-target="#wanmobile-add-popup">  -->\
                        </div>\
                    </div>\
        </div>\
    </div>\
    ');  
    local lp = require("web.lp")
    lp.setpath("/www/docroot/")
    lp.include("apply-cancel.lp")
      ngx.print('\
</div>\
\
\
<!--- Edit Popup WAN ADSL-->\
<div class="modal wan-modal fade" id="wanadsl-edit-popup" role="dialog" data-backdrop="static">\
    <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
            <div class="modal-header hidden-sm hidden-md hidden-lg">\
                <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
            </div>\
            <div class="modal-body no-padding">\
                <form class="form-horizontal">\
                    <div class="form-group">\
                        <div class="col-sm-12">\
                            <p class="title tL">');  ngx.print(T"Edit Internet Connection"); ngx.print('</p>\
                        </div>\
                    </div>\
                    <div class="vdf-table">\
                        <div class="vdf-row">\
                            <div class="left">\
                                <span>');  ngx.print(T"Connection Type"); ngx.print('</span>\
                            </div>\
                            <div class="right">\
                                <div id="top-info-mode" class="rel">\
                                    <select class="connection-type" id="wan-sel-conntype">\
                                        <option value="ipoe">');  ngx.print(T"IPoE"); ngx.print('</option>\
                                        <option value="pppoe">');  ngx.print(T"PPPoE"); ngx.print('</option>\
                                        <option value="ipoa">');  ngx.print(T"IPoA"); ngx.print('</option>\
                                        <option value="pppoa">');  ngx.print(T"PPPoA"); ngx.print('</option>\
                                    </select>\
                                </div>\
                            </div>\
                        </div>\
                        <div class="vdf-row pppoe" style="display:none;" >\
                            <div class="left">\
                                <span>');  ngx.print(T"WAN IPv6 enable"); ngx.print('</span> </div>\
                            <div class="right">\
                                <div id= "wan-btn-ipv6" class="button button-on wan-button">\
\
                                </div>\
                            </div>\
                        </div>\
                        <div class="vdf-row">\
                            <div class="left">\
                                <span class="language-string">');  ngx.print(T"VPI [0-255]"); ngx.print('</span>\
                            </div>\
                            <div class="right">\
                                <input id= "wan-txt-vpi" type="text" class="input">\
                            </div>\
                        </div>\
                        <div class="vdf-row">\
                            <div class="left">\
                                <span class="language-string">');  ngx.print(T"VCI [32-65535]"); ngx.print('</span>\
                            </div>\
                            <div class="right">\
                                <input id= "wan-txt-vci" type="text" class="input">\
                            </div>\
                        </div>\
                        <div class="vdf-row">\
                            <div class="left">\
                                <span>');  ngx.print(T"Firewall"); ngx.print('</span> </div>\
                            <div class="right">\
                                <div  id= "wan-btn-firewall" class="button button-on wan-button">\
\
                                </div>\
                            </div>\
                        </div>\
                        <div class="vdf-row">\
                            <div class="left">\
                                <span class="language-string">');  ngx.print(T"NAT"); ngx.print('</span>\
                            </div>\
                            <div class="right">\
                                <div  id= "wan-btn-nat" class="button button-off wan-button">\
\
                                </div>\
                            </div>\
                        </div>\
                        <div class="vdf-row op40">\
                            <div class="left">\
                                <span>');  ngx.print(T"QoS"); ngx.print('</span> </div>\
                            <div class="right">\
                                <div  id = "wan-btn-qos" class="button button-on wan-button">\
                                </div>\
                            </div>\
                        </div>\
                        <div class="vdf-row">\
                            <div class="left">\
                                <span>');  ngx.print(T"IP Address Mode"); ngx.print('</span> </div>\
                            <div class="right">\
                                <div id="top-info-mode" class="rel">\
                                    <select class="ip-address-mode" style="display: none;" id = "wan-sel-addmode">\
                                    </select>\
                                </div>\
                            </div>\
                        </div>\
                        <div class="vdf-row static">\
                            <div class="left">\
                                <span>');  ngx.print(T"WAN IP Address"); ngx.print('</span> </div>\
                            <div class="right wan-div-address ">\
                                <input type="number" class="max3" maxlength="3" id = "wan-txt-ipaddress1" >\
                                <input type="number" class="max3" maxlength="3" id = "wan-txt-ipaddress2">\
                                <input type="number" class="max3" maxlength="3" id = "wan-txt-ipaddress3">\
                                <input type="number" class="max3" maxlength="3" id = "wan-txt-ipaddress4">\
                            </div>\
                        </div>\
                        <div class="vdf-row static">\
                            <div class="left">\
                                <span>');  ngx.print(T"WAN Subnet Mask"); ngx.print('</span> </div>\
                            <div class="right wan-div-subnet">\
                                <input type="number" class="max3" maxlength="3" id="wan-txt-subnet1">\
                                <input type="number" class="max3" maxlength="3" id="wan-txt-subnet2">\
                                <input type="number" class="max3" maxlength="3" id="wan-txt-subnet3">\
                                <input type="number" class="max3" maxlength="3" id="wan-txt-subnet4">\
                            </div>\
                        </div>\
                        <div class="vdf-row static">\
                            <div class="left">\
                                <span>');  ngx.print(T"WAN Gateway IP Address"); ngx.print('</span> </div>\
                            <div class="right wan-div-gateway">\
                                <input type="number" class="max3" maxlength="3" id="wan-txt-gateway1">\
                                <input type="number" class="max3" maxlength="3" id="wan-txt-gateway2">\
                                <input type="number" class="max3" maxlength="3" id="wan-txt-gateway3">\
                                <input type="number" class="max3" maxlength="3" id="wan-txt-gateway4">\
                            </div>\
                        </div>\
                        <div class="vdf-row pppoe wan-div-show_hide_conntype" >\
                            <div class="left">\
                                <span>');  ngx.print(T"Username"); ngx.print('</span> </div>\
                            <div class="right">\
                                <input id= "wan-txt-username" type="text" value="">\
                            </div>\
                        </div>\
                        <div class="vdf-row pppoe wan-div-show_hide_conntype " >\
                            <div class="left">\
                                <span>');  ngx.print(T"Password"); ngx.print('</span> </div>\
                            <div class="right">\
                                <input  id= "wan-txt-password" type="password" value="">\
                            </div>\
                        </div>\
                        <div class="vdf-row pppoe" >\
                            <div class="left">\
                                <span>');  ngx.print(T"Service Name"); ngx.print('</span> </div>\
                            <div class="right">\
                                <input id= "wan-txt-servicename" type="text">\
                            </div>\
                        </div>\
                        <div class="vdf-row pppoe" >\
                            <div class="left">\
                                <span>');  ngx.print(T"Authentication Method"); ngx.print('</span> </div>\
                            <div class="right">\
                                <div id="top-info-mode" class="rel">\
                                    <select style="display: none;" id="wan-sel-authmethod" >\
                                        <option value= "auto">');  ngx.print(T"AUTO"); ngx.print('</option>\
                                        <option value= "chap">');  ngx.print(T"CHAP"); ngx.print('</option>\
                                        <option value= "pap">');  ngx.print(T"PAP"); ngx.print('</option>\
                                    </select>\
                                </div>\
                            </div>\
                        </div>\
                        <div class="vdf-row pppoe" >\
                            <div class="left">\
                                <span>');  ngx.print(T"Connection Trigger"); ngx.print('</span> </div>\
                            <div class="right">\
                                <div id="top-info-mode" class="rel"  >\
                                    <select style="display: none;" id="wan-sel-conntrigger">\
                                        <option value="alwayson">');  ngx.print(T"AlwaysOn"); ngx.print('</option>\
                                        <option value="ondemand">');  ngx.print(T"On Demand"); ngx.print('</option>\
                                    </select>\
                                </div>\
                            </div>\
                        </div>\
                        <div class="vdf-row pppoe" >\
                            <div class="left">\
                                <span>');  ngx.print(T"LCP Echo request interval (sec)"); ngx.print('</span> </div>\
                            <div class="right">\
                                <input id= "wan-txt-lcp" type="text" value="10">\
                            </div>\
                        </div>\
                        <div class="vdf-row pppoe" >\
                            <div class="left">\
                                <span class="language-string">');  ngx.print(T"MTU [68-1500]"); ngx.print('</span>\
                            </div>\
                            <div class="right">\
                                <input  id= "wan-txt-mtu" type="text" value="1492">\
                            </div>\
                        </div>\
                        <div class="vdf-row pppoe" >\
                            <div class="left">\
                                <span>');  ngx.print(T"Obtain DNS Servers automatically"); ngx.print('</span> </div>\
                            <div class="right">\
                                <div  id= "wan-btn-obtdns" class="button button-on wan-button">\
                                </div>\
                            </div>\
                        </div>\
                        <div class="vdf-row dns">\
                            <div class="left">\
                                <span>');  ngx.print(T"Primary Address"); ngx.print('</span> </div>\
                            <div class="right wan-div-primaryDNS">\
                                <input type="number" class="max3" maxlength="3" id = "wan-txt-pridns1">\
                                <input type="number" class="max3" maxlength="3" id = "wan-txt-pridns2">\
                                <input type="number" class="max3" maxlength="3" id = "wan-txt-pridns3">\
                                <input type="number" class="max3" maxlength="3" id = "wan-txt-pridns4">\
                            </div>\
                        </div>\
                        <div class="vdf-row dns">\
                            <div class="left">\
                                <span>');  ngx.print(T"Secondary Address"); ngx.print('</span> </div>\
                            <div class="right wan-div-secondaryDNS">\
                                <input type="number" class="max3" maxlength="3" id = "wan-txt-secdns1" >\
                                <input type="number" class="max3" maxlength="3" id = "wan-txt-secdns2">\
                                <input type="number" class="max3" maxlength="3" id = "wan-txt-secdns3">\
                                <input type="number" class="max3" maxlength="3" id = "wan-txt-secdns4">\
                            </div>\
                        </div>\
\
                    </div>\
\
                    <div class="message message-info message-error not-similiar" id="adsl-err" style="display:none">\
                        ');  ngx.print(T "Please check the inputs entered."); ngx.print('\
                    </div>\
                    <div class="form-group">\
                        <div class="col-sm-12">\
                            <div class="modal-footer">\
                                <input class="button button-apply save mob-button-width wan-save" id="wanadsl-btn-editSave" value="');  ngx.print(T" Save "); ngx.print('" data-dismiss="modal" type="button" />\
                                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="');  ngx.print(T" Cancel "); ngx.print('" type="button" id="wanadsl-btn-editCancel" />\
                            </div>\
                        </div>\
                    </div>\
                </form>\
            </div>\
        </div>\
    </div>\
</div>\
<script>\
\
\
\
 $(function () {\
    $(\'select\').chosen({\
      disable_search_threshold: 100000,\
      allow_single_deselect: true\
    });\
    });\
  var T = {\
    "Dynamic" : "');  ngx.print(T"Dynamic"); ngx.print('",\
    "Static"  : "');  ngx.print(T"Static"); ngx.print('",\
    "VPI [0-255]" : "');  ngx.print(T"VPI [0-255]"); ngx.print('",\
    "VCI [32-65535]" : "');  ngx.print(T"VCI [32-65535]"); ngx.print('",\
    "IPoA"  : "');  ngx.print(T"IPoA"); ngx.print('",\
    "PPPoA"  : "');  ngx.print(T"PPPoA"); ngx.print('",\
    "Enabled" : "');  ngx.print(T"Enabled"); ngx.print('",\
    "Disabled" : "');  ngx.print(T"Disabled"); ngx.print('",\
    "802.1P Priority [0-7]" : "');  ngx.print(T"802.1P Priority [0-7]"); ngx.print('",\
    "802.1Q VLAN ID [0-4094]" : "');  ngx.print(T"802.1Q VLAN ID [0-4094]"); ngx.print('"\
  }\
 var flagTable = ');  ngx.print(json.encode(flagTable)); ngx.print('\
</script>\
<script src="js/wan.js"></script>\
'); 