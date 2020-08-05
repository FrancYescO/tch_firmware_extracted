--pretranslated: do not change this file

-- Enable localization
local format = string.format
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local tprint = require("tch.tableprint")
-- Process POST query
local post_helper = require("web.post_helper")

local untaint_mt = require("web.taint").untaint_mt

local mapParams = {
    uci_wan_auto = "uci.network.interface.@wan.auto",
    uci_wan_username = "uci.network.interface.@wan.username",
    uci_wan_password = "uci.network.interface.@wan.password",
    uci_wan_proto = "uci.network.interface.@wan.proto",
    uci_wan_ipv6 = "uci.network.interface.@wan.ipv6",
    uci_wan_mtu = "uci.network.interface.@wan.mtu",
    uci_wan_vlan_default = "uci.env.custovar.wan_vlan_default",
    uci_wan_vlan_enabled = "uci.env.custovar.wan_vlan_enabled",
    uci_wan_ipaddr = "uci.network.interface.@wan.ipaddr",
    uci_wan_subnet = "uci.network.interface.@wan.netmask",
    uci_wan_gateway = "uci.network.interface.@wan.gateway",
    uci_wan_vlan = "uci.network.device.@vlan_wan.vid",
    uci_vlan_ifname = "uci.network.device.@vlan_wan.ifname",

    --uci_wan_dns = "rpc.network.interface.@wan.dnsservers",
}

-- Listbox that shows the supported PPP modes
local routed_mode = {
      { "pppoe", T"PPPoE" },
      { "dhcp", T"DHCP" },
      { "static", T"Static" }, 
      { "bridge", T"Bridge" },  
}



-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gCV = post_helper.getConditionalValidation
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP
local vSIP = post_helper.validateStringIsPort
local gVP = post_helper.getValidationPassword
local gOV = post_helper.getOptionalValidation
local vSIIA = post_helper.advancedIPValidation
local vIIP4N = post_helper.validateIPv4Netmask



local function validateUsername (value, postdata)
  local err,msg = vNES(value)
  if not err then
    return err,msg
  end

  local content_uci = {
    wan_domain = "uci.network.interface.@wan.domain",
  }
  content_helper.getExactContent(content_uci)

  if content_uci["wan_domain"] ~= "" then
    if string.find(value, "@") then
      return nil, T"Invalid username, domain locked"
    end
    postdata["uci_wan_username"] = format('%s@%s', value, content_uci["wan_domain"])
  end

  return true
end


local function validateVLAN (value, postdata)
  local err,msg = vNES(value)
  if not err then
    return err,msg
  end
  if value:match("^0") then
		return nil, T"Invalid VLAN ID - Leading 0's are not allowed"
  end
  if not value:match("^[0-9]*$") then
     return nil, T"Invalid VLAN - only numbers are allowed"
  end
  local valuenum = tonumber(value) 
  
  if valuenum then
    if valuenum >= 2 and valuenum <= 4094 then
        return true
    end    
  end
  return nil, T"Invalid VLAN ID - should be between 2 and 4096"
  
end

local function validateMTU (value, postdata)
  local err,msg = vNES(value)
  if not err then
    return err,msg
  end
  if not value:match("^[0-9]*$") then
     return nil, T"Invalid MTU - only numbers are allowed"
  end
  local valuenum = tonumber(value) 
  
  if valuenum then
    if valuenum >= 1280 and valuenum <= 1500 then
        return true
    end    
  end
  return nil, T"Invalid MTU - should be between 1280 and 1500"
  
end

local function validateIPandnotSubnet (value, postdata)
  err,msg = vSIIA(value, postdata)
  if not err then
    return err,msg
  end
  if value then
    if string.match(value,"%d+") == "255" then
        return nil, T"Invalid IP - Subnet addresses are not allowed"
    end    
  end
  
  return true
end

local function isWanEnabled(value, object, key)
    return object["uci_wan_auto"] ~= "0"
end

-- Validation allows empty values if wan access disabled but will stil check for validity if the parameter is set
-- if wan is enabled then it checks for validaty anyway
local mapValid = {
    uci_wan_auto = vB,
    uci_wan_ipv6 = vB,
    uci_wan_vlan_enabled = vB,
    uci_wan_username = gVIPIL(gCV(isWanEnabled, validateUsername, gOV(validateUsername)), "uci_wan_proto", {"pppoe","pppoa"}),
    uci_wan_password = gVIPIL(gCV(isWanEnabled, gVP(vNES), gVP()), "uci_wan_proto", {"pppoe","pppoa"}),    
    uci_wan_vlan     = gVIPIL(gCV(isWanEnabled, validateVLAN, gOV(validateVLAN)), "uci_wan_vlan_enabled", {"1"}),
    uci_wan_mtu      = gCV(isWanEnabled, validateMTU, gOV(validateMTU)),
    uci_wan_ipaddr   = gVIPIL(gCV(isWanEnabled, validateIPandnotSubnet), "uci_wan_proto", {"static"}),
    uci_wan_subnet   = gVIPIL(gCV(isWanEnabled, vIIP4N), "uci_wan_proto", {"static"}),
    uci_wan_gateway  = gVIPIL(gCV(isWanEnabled, validateIPandnotSubnet), "uci_wan_proto", {"static"}),
    uci_wan_dns1    = gVIPIL(gVIPIL(gCV(isWanEnabled, validateIPandnotSubnet), "dns_num", {"1","2"}), "uci_wan_proto", {"static"}) ,
    uci_wan_dns2    = gVIPIL(gVIPIL(gCV(isWanEnabled, validateIPandnotSubnet), "dns_num", {"2"}), "uci_wan_proto", {"static"}) ,
    uci_wan_proto   = gVIES(routed_mode),
}
local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

if content["uci_wan_ipv6"] == "" then content["uci_wan_ipv6"] = "1" end

if ngx.var.request_method == "POST" and #helpmsg == 0 then
  local args = ngx.req.get_post_args()
  local action = args["action"]
  if action == "SAVE" then

      local higher_mtu = tostring(tonumber(content["uci_wan_mtu"])+8)
      local mtu = content["uci_wan_mtu"]
      if content["uci_wan_proto"]== "pppoe" then
        proxy.set("uci.network.device.@eth4.mtu",higher_mtu)
        proxy.set("uci.network.device.@vlan_wan.mtu",higher_mtu)
        proxy.set("uci.network.interface.@wan.proto","pppoe")
        proxy.set("uci.network.config.wan_mode","pppoe") 
        proxy.set("uci.network.interface.@wan.rqoptions","") 
      elseif content["uci_wan_proto"]== "dhcp" then
        proxy.set("uci.network.device.@eth4.mtu",mtu)
        proxy.set("uci.network.device.@vlan_wan.mtu",mtu)
        proxy.set("uci.network.interface.@wan.proto","dhcp")
        proxy.set("uci.network.config.wan_mode","dhcp")
        proxy.set("uci.network.interface.@wan.rqoptions","1 3 6 15 33 42 51 121 249")
        proxy.set("uci.network.interface.@wan.password","") 
      elseif content["uci_wan_proto"]== "static" then
        proxy.set("uci.network.device.@eth4.mtu",mtu)
        proxy.set("uci.network.device.@vlan_wan.mtu",mtu)
        proxy.set("uci.network.interface.@wan.proto","static")
        proxy.set("uci.network.config.wan_mode","static")
        proxy.set("uci.network.interface.@wan.rqoptions","")
        proxy.set("uci.network.interface.@wan.password","")
      end
      if content["uci_wan_proto"]== "bridge" then 
        proxy.set("uci.network.device.@eth4.mtu","1500")
        proxy.set("uci.network.device.@vlan_wan.mtu","1500")
        proxy.set("uci.network.interface.@wan.rqoptions","")
        proxy.set("uci.network.interface.@wan.password","")
        proxy.set("uci.intercept.config.enabled","0")
        if content["uci_wan_vlan_enabled"] == "1" then
            proxy.set("uci.network.device.@vlan_wan.vid",content["uci_wan_vlan"])
            proxy.set("uci.network.device.@vlan_wan.ifname","eth4")
            proxy.set("uci.network.interface.@wan.ifname","eth0 eth1 eth2 vlan_wan")
        else
           proxy.set("uci.network.interface.@wan.ifname","eth0 eth1 eth2 eth4")
           proxy.set("uci.env.custovar.wan_vlan_default",content["uci_wan_vlan_default"])

        end
        --proxy.set("uci.network.interface.@wan.mtu","1500")
        proxy.set("uci.network.interface.@wan.proto","bridge")
        proxy.set("uci.network.interface.@lan.ifname","eth3 eth5")
        proxy.set("uci.network.config.wan_mode","bridge")
        proxy.set("uci.network.interface.@wan.type","bridge")
      else
        proxy.set("uci.intercept.config.enabled","1")
        proxy.set("uci.network.interface.@lan.ifname","eth0 eth1 eth2 eth3 eth5")
        proxy.set("uci.network.interface.@wan.type","")
        if content["uci_wan_vlan_enabled"] == "1" then
            proxy.set("uci.network.interface.@wan.ifname","vlan_wan")
            proxy.set("uci.env.custovar.wan_vlan",content["uci_wan_vlan"])
            proxy.set("uci.network.device.@vlan_wan.ifname","eth4")
        else
             proxy.set("uci.network.interface.@wan.ifname","eth4")
             proxy.set("uci.env.custovar.wan_vlan_default",content["uci_wan_vlan_default"])
        end
      end
      if content["uci_wan_proto"]~= "static" then 
             proxy.set("uci.network.interface.@wan.ipaddr","")
             proxy.set("uci.network.interface.@wan.netmask","")
             proxy.set("uci.network.interface.@wan.gateway","")
             proxy.del("uci.network.interface.@wan.dns.")
      else
         if content["dns_num"] ~= "0" then
            local res1, help1 = vSII(content["uci_wan_dns1"])
            if res1 then
               proxy.del("uci.network.interface.@wan.dns.@1.")
               proxy.add("uci.network.interface.@wan.dns.")
               proxy.set("uci.network.interface.@wan.dns.@1.value",content["uci_wan_dns1"])
                if content["dns_num"] == "2" then
                     
                     local res2, help2 = vSII(content["uci_wan_dns2"])
                     if res2 then
                        proxy.del("uci.network.interface.@wan.dns.@2.")
                        proxy.add("uci.network.interface.@wan.dns.")
                        proxy.set("uci.network.interface.@wan.dns.@2.value",content["uci_wan_dns2"])
                     else
                     
                       helpmsg["uci_wan_dns2"] = help2 
                     end
                else
                
                    proxy.del("uci.network.interface.@wan.dns.@2.")              
                end
            else
               helpmsg["uci_wan_dns1"] = help1
            end
         else
            proxy.del("uci.network.interface.@wan.dns.")
         end
      end
      if content["uci_wan_proto"]~= "bridge" then
        local cwmpd_enabled = proxy.get("uci.env.custovar.cwmpd_enabled")[1].value
        proxy.set("uci.cwmpd.cwmpd_config.state",cwmpd_enabled)
      else
        proxy.set("uci.cwmpd.cwmpd_config.state","0")
      end
      proxy.set("uci.env.custovar.WS","2")
      proxy.set("uci.wansensing.global.enable","0")
      proxy.apply()
  end  
end
-- End POST process

local string = string

local content_uci = {
  wan_proto = "uci.network.interface.@wan.proto",
  wan_domain = "uci.network.interface.@wan.domain",
}
content_helper.getExactContent(content_uci)

local content_rpc = {
    wan_ppp_state    = "rpc.network.interface.@wan.ppp.state",
    wan_ppp_error    = "rpc.network.interface.@wan.ppp.error",
    wan_ppp_ll_intf  = "rpc.network.interface.@wan.ppp.ll_intf",
    ipaddr           = "rpc.network.interface.@wan.ipaddr",
    nexthop          = "rpc.network.interface.@wan.nexthop",
    ip6addr          = "rpc.network.interface.@wan6.ip6addr",
}
content_helper.getExactContent(content_rpc)

local display_DNS = ""
local uci_dnsservers = {}
for i,v in ipairs(proxy.getPN("uci.network.interface.@wan.dns.", true)) do
   local thispath = format("%svalue",v.path)
   uci_dnsservers[#uci_dnsservers+1] = format("%s", proxy.get(thispath)[1].value)
   display_DNS = format("%s%s ",display_DNS,uci_dnsservers[i])
    
end




wan_ppp_over_atm = 1
local content_uci_xtm
if wan_ppp_over_atm then
  -- need to untaint the string otherwise getExactContent will get lost
  local wan_atm_uci_path = string.format("uci.xtm.atmdevice.@%s.", content_rpc["wan_ppp_ll_intf"])
  content_uci_xtm = {
    wan_atm_vpi = wan_atm_uci_path.."vpi",
    wan_atm_vci = wan_atm_uci_path.."vci",
    wan_atm_enc = wan_atm_uci_path.."enc",
  }
  content_helper.getExactContent(content_uci_xtm)
end

if content_uci["wan_domain"] ~= "" then
  content["uci_wan_username"] = string.match(content["uci_wan_username"], "[^@]*")
end

local ppp_state_map = {
    disabled = T"Disabled",
    disconnecting = T"Disconnecting",
    connected = T"Connected",
    connecting = T"Connecting",
    disconnected = T"Disconnected",
    error = T"Error",
    networking = T"Network Error",
    AUTH_TOPEER_FAILED = T"Authentication failed",
    NEGOTIATION_FAILED = T"Negotiation failed",
}
setmetatable(ppp_state_map, untaint_mt)

local ppp_light_map = {
    disabled = "off",
    disconnected = "red",
    disconnecting = "orange",
    connecting = "orange",
    connected = "green",
    error = "red",
    networking = "red",
    AUTH_TOPEER_FAILED = "red",
    NEGOTIATION_FAILED = "red",
}
setmetatable(ppp_light_map, untaint_mt)

local ppp_status = ""
if content.uci_wan_auto ~= "0" then
  -- WAN enabled
  content.uci_wan_auto = "1"
  ppp_status = string.format("%s", content_rpc.wan_ppp_state) -- untaint
  if ppp_status == "" or ppp_status == "authenticating" then
    ppp_status = "connecting"
  end

  if not (content_rpc.wan_ppp_error == "" or content_rpc.wan_ppp_error == "USER_REQUEST") then
    if ppp_state_map[content_rpc.wan_ppp_error] then
        ppp_status = content_rpc.wan_ppp_error
    else
        ppp_status = "error"
    end
  end
else
  -- WAN disabled
  ppp_status = "disabled"
end


-- Figure out interface state DHCP
local cs = {
    ipaddr = "rpc.network.interface.@wan.ipaddr",
    nexthop = "rpc.network.interface.@wan.nexthop",
    ip6addr = "rpc.network.interface.@wan6.ip6addr",
}


content_helper.getExactContent(cs)

local dhcp_state = "connecting"
local dhcp_state_map = {
    disabled = T"Disabled",
    connected = T"Connected",
    connecting = T"Connecting",
}

local dhcp_light_map = {
  disabled = "off",
  connecting = "orange",
  connected = "green",
}

if content["uci_wan_auto"] ~= "0" then
    content["uci_wan_auto"] = "1"
    if cs["ipaddr"]:len() > 0 then
        dhcp_state = "connected"
    else
        dhcp_state = "connecting"
    end
else
    dhcp_state = "disabled"
end

ngx.print('\
\
<fieldset>',
ui_helper.createMessages(message_helper.popMessages()), '\
\
<legend>', T"Connection Configuration - Ethernet WAN", '</legend>');
   
    local html = {}
    -- Label that shows PPP status
    if content["uci_wan_proto"] == "pppoa" or content["uci_wan_proto"] == "pppoe" then
      html[#html + 1] = ui_helper.createLight(T"Status", nil, ppp_state_map[ppp_status] or T"Unknown", { light = { class = ppp_light_map[ppp_status] or "red" } })
    elseif content["uci_wan_proto"] == "dhcp" then
    -- Or DHCP
      html[#html + 1] = ui_helper.createLight(T"Status", nil, dhcp_state_map[dhcp_state], { light = { class = dhcp_light_map[dhcp_state] } })
    end
        -- Switch
     local onoff_class = {
            group = {
                class = "monitor-uci_wan_proto monitor-pppoe monitor-pppoa monitor-dhcp monitor-static"
            }
        }
    
    
    -- Switch on/off
    html[#html + 1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content.uci_wan_auto, onoff_class)
    html[#html + 1] = ui_helper.createSwitch(T"IPv6", "uci_wan_ipv6", content.uci_wan_ipv6, onoff_class)
    --Routed Type
    local WANType = {
        group = {
            class = "",
        },
        select = {
            class = "monitor-changes span2"
        }
    }
    html[#html + 1] = ui_helper.createInputSelect(T"Routed Type", "uci_wan_proto", routed_mode, content.uci_wan_proto, WANType)

   
    -- Class to show hide PPP details
    
    
   local security_warning = {
        alert = {
            class = "alert-warning monitor-uci_wan_proto monitor-pppoe"
        },
    }
    html[#html + 1] = ui_helper.createAlertBlock(T"Please complete the user details below", security_warning)

    -- Class for Bridge port 4 message
    
    local security_bridge_warning = {
        alert = {
            class = "alert-warning monitor-uci_wan_proto monitor-bridge"
        },
    }
    html[#html + 1] = ui_helper.createAlertBlock(T"In Bridge mode only LAN ports 1-3 will be bridged, port 4 and the wireless can be used for this managment interface only.", security_bridge_warning)
  
    -- PPP username
    local class_username = {
      group = {
            class ="monitor-uci_wan_proto monitor-pppoe monitor-pppoa",
        },
        input = {
        maxlength= "128",
        class = "span6",
      }
    }
    


    
    html[#html + 1] = "<div class='control-group'><label class='control-label monitor-uci_wan_proto monitor-pppoe monitor-pppoa'>" .. T"Username" .. "</label><div class='controls monitor-uci_wan_proto monitor-pppoe monitor-pppoa'>"
    html[#html + 1] = ui_helper.createSimpleInputText("uci_wan_username", content["uci_wan_username"], class_username, helpmsg["uci_wan_username"])
    if content_uci["wan_domain"] ~= "" then
      html[#html + 1] = " @ " .. content_uci["wan_domain"]
    end
    html[#html + 1] = "</div></div>"
    
    


    -- PPP password
    local class_password = class_username
    html[#html + 1] = ui_helper.createInputPassword(T"Password", "uci_wan_password", content["uci_wan_password"], class_username , helpmsg["uci_wan_password"])
    local security_warning_pass = {
        alert = {
            id = "password_warn",
            class = "alert-warning monitor-uci_wan_proto monitor-pppoe"
        },
    }
    html[#html + 1] = ui_helper.createAlertBlock(T"Re-enter your password each time, if you do not your password will not be taken correctly", security_warning_pass)               
    
    
    -- MTU
    
    local class_mtu = {
    group = {
                class ="monitor-uci_wan_proto monitor-bridge monitor-pppoe monitor-dhcp monitor-static",
            },
        input = {
        maxlength= "4",
        class = "span1",
      }
    }
    html[#html + 1] = ui_helper.createInputText(T"MTU", "uci_wan_mtu", content["uci_wan_mtu"], class_mtu, helpmsg["uci_wan_mtu"])
        

    
    
   local ipv4pattern = "^(((([1]?\\d)?\\d|2[0-4]\\d|25[0-5])\\.){3}(([1]?\\d)?\\d|2[0-4]\\d|25[0-5]))$" 
   local StaticClass = {
       group = {
                class ="monitor-uci_wan_proto monitor-static",
            },
            input = {
            maxlength= "15",
            class = "span2",
	    pattern = ipv4pattern,
          },
         
    }
    
    local static_warning = {
        alert = {
            class = "alert-warning monitor-uci_wan_proto monitor-static"
        },
    }
    
    local dns_amount = {
      { 0, 0 },
      { 1, 1 },
      { 2, 2 }, 
    }
    
    local StaticClassDNS1 = {
       group = {
                class ="monitor-uci_wan_proto monitor-static monitor-dns_num monitor-1 monitor-2",
            },
            input = {
            maxlength= "15",
            class = "span2",
	    pattern = ipv4pattern,
          },
         
    }
    local StaticClassDNS2 = {
       group = {
                class ="monitor-uci_wan_proto monitor-static monitor-dns_num monitor-2",
            },
            input = {
            maxlength= "15",
            class = "span2",
	    pattern = ipv4pattern,
          },
         
    }

    local dnsselect_class = {
        group = {
            class = "monitor-uci_wan_proto monitor-static",
        },
        select = {
            class = "monitor-changes span1"
        }
    }
    html[#html + 1] = ui_helper.createAlertBlock(T"Please complete the required IP addresses below", static_warning)
   
    
  

        -- UI CONTROLS LIST 
        -- ARGUMENT 2 MUST MUST MATCH PARAMETER NAME FROM mapParams OR ERRORS WILL OCCUR DURING INTERFACE UPDATES     
        html[#html+1] = ui_helper.createInputText(T"IP Address", "uci_wan_ipaddr", content["uci_wan_ipaddr"], StaticClass, helpmsg["uci_wan_ipaddr"])
        html[#html+1] = ui_helper.createInputText(T"Subnet Mask", "uci_wan_subnet", content["uci_wan_subnet"], StaticClass, helpmsg["uci_wan_subnet"])
        html[#html+1] = ui_helper.createInputText(T"Gateway", "uci_wan_gateway", content["uci_wan_gateway"], StaticClass, helpmsg["uci_wan_gateway"])
        local numberofDNS = #uci_dnsservers
        if helpmsg["uci_wan_dns2"] ~= nil then numberofDNS = 2 end
        html[#html + 1] = ui_helper.createInputSelect(T"Number of DNS Servers", "dns_num", dns_amount, numberofDNS, dnsselect_class)

       -- html[#html+1] = ui_helper.createLabel(T"DNS Server 1", uci_dnsservers[1], StaticClassDNS1)
        --html[#html+1] = ui_helper.createLabel(T"DNS Server 2", uci_dnsservers[2], StaticClassDNS2)
        html[#html+1] = ui_helper.createInputText(T"DNS 1", "uci_wan_dns1", uci_dnsservers[1], StaticClassDNS1, helpmsg["uci_wan_dns1"])
        html[#html+1] = ui_helper.createInputText(T"DNS 2", "uci_wan_dns2", uci_dnsservers[2], StaticClassDNS2, helpmsg["uci_wan_dns2"])
        
    
    --VLAN
    local vlanswitch_class = {
        input = {
            class = "monitor-changes"
        }
    }
  
    html[#html + 1] = ui_helper.createSwitch(T"VLAN Enabled", "uci_wan_vlan_enabled", content["uci_wan_vlan_enabled"], vlanswitch_class)
    
    
    local vlan_class = {
        group = {
            class = "monitor-uci_wan_vlan_enabled monitor-1"
        },
        input = {
          maxlength= "4",
          class = "span1",
        }
    }
    local VLAN = content[uci_wan_vlan]
    --ngx.log(ngx.ERR, format("VLAN : %s",content["uci_wan_vlan"])) 
    html[#html + 1] = ui_helper.createInputText(T"VLAN ID", "uci_wan_vlan", content["uci_wan_vlan"], vlan_class, helpmsg["uci_wan_vlan"])
    ngx.print(html, '\
\
</fieldset>\
<script>\
var vlan_en = $("[name=\'uci_wan_vlan_enabled\']");\
var vlan_id = $("[name=\'uci_wan_vlan\']");\
var mtu = $("[name=\'uci_wan_mtu\']");\
var username = $("[name=\'uci_wan_username\']");\
var password = $("[name=\'uci_wan_password\']");\
var proto = $("[name=\'uci_wan_proto\']");\
function wantype() {\
     if (proto.val()!=\'pppoe\'){\
         password.val(\'\');\
         mtu.val(\'1500\');\
     }else{\
         mtu.val(\'1492\');\
     }\
}\
$(function() {\
   vlan_en.change(function() {vlan_id.val("', content["uci_wan_vlan"], '");});\
   proto.change(function() {wantype();});\
   //Clear the password box on select and leave of username\
   username.focusout(function() {\
     password.val(\'\');\
   });\
   password.focus(function() {\
     password.val(\'\');\
   });');
   
   if content["uci_wan_password"] == "" then 
ngx.print('\
       password.val(\'\');');
   end
ngx.print('\
});\
\
</script>');