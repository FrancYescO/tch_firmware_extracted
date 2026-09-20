--pretranslated: do not change this file

-- You must add the forwarders and the lan_private zone to your custo!!!
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local proxy = require("datamodel")
local lp = require("web.lp")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local untaint_mt = require("web.taint").untaint_mt
local session = ngx.ctx.session
local intfexists = 0
local current_WANIP = format("%s", proxy.get("rpc.network.interface.@wan.ipaddr")[1].value)
local example_ip =  "172.16.1.89"
if current_WANIP ~= "" then  example_ip = current_WANIP end
local example_sub = "255.255.255.248"
local InRange = 1



local subnet_converter = {
            {"255.0.0.0","/8"},{"255.128.0.0","/9"},{"255.192.0.0","/10"},{"255.224.0.0","/11"},{"255.240.0.0","/12"},{"255.248.0.0","/13"},{"255.252.0.0","/14"},
            {"255.254.0.0","/15"},{"255.255.0.0","/16"},{"255.255.128.0","/17"},{"255.255.192.0","/18"},{"255.255.224.0","/19"},{"255.255.240.0","/20"},{"255.255.248.0","/21"},
            {"255.255.252.0","/22"},{"255.255.254.0","/23"},{"255.255.255.0","/24"},{"255.255.255.128","/25"},{"255.255.255.192","/26"},{"255.255.255.224","/27"},
            {"255.255.255.240","/28"},{"255.255.255.248","/29"},{"255.255.255.252","/30"}
}

local wan_zone = ""
local lan_private_zone = ""
local zone_path = "uci.firewall.zone."
local zone_path_content = content_helper.getMatchedContent (zone_path)
for _, v in pairs (zone_path_content) do
   if v["name"] == "wan" then
      wan_zone = v["path"]
   end
   if v["name"] == "lan_public" then
      lan_private_zone = v["path"]
   end
end

local subin_fwd = ""
local subout_fwd = ""
local forward_path = "uci.firewall.forwarding."
local forward_path_content = content_helper.getMatchedContent (forward_path)
for _, v in pairs (forward_path_content) do
   if v["src"] == "wan" and v["dest"] == "lan_public" then
      subin_fwd = v["path"]
   end
   if v["dest"] == "wan" and v["src"] == "lan_public" then
      subout_fwd = v["path"]
   end
end


local subnet_present = 0

for _, v in ipairs (proxy.getPN("uci.network.interface.", true)) do
   if v["path"] == "uci.network.interface.@lan_public." then
      process_post = 1
      intfexists = 1
      break
   end
end
local postchk = false
if ngx.var.request_method == "POST" then
   local changed = 0
   local vars = ngx.req.get_post_args()
    if vars["action"] == "SAVE" then
        postchk = true
    end
   if postchk and vars["subnet_present"] == "1" then
      changed = 1
      proxy.set("uci.network.interface.@wan.auto","0")
      proxy.apply()
      if vars["InRange"] == "1" then
          proxy.set("uci.network.interface.@wan.unnumbered","lan_public")
      elseif intfexists == 1 then
          proxy.set("uci.network.interface.@wan.unnumbered","")
      end
      if intfexists == 0 then
        proxy.add("uci.network.interface.","lan_public")
        proxy.set({  ["uci.network.interface.@lan_public.proto"]  ="static",
                     ["uci.network.interface.@lan_public.ifname"] ="@lan",
                     ["uci.network.interface.@wan.unnumbered"]    ="lan_public",
                     ["uci.network.interface.@wan.auto"]          ="1",
                  })
        --proxy.add("uci.dhcp.dhcp.","lan_public")
        --proxy.set("uci.dhcp.dhcp.@lan_public.interface","lan_public")
        --proxy.set("uci.dhcp.dhcp.@lan_public.ignore","1")
        intfexists = 1

      end

      if (vars["uci_sub_ipaddr"] and vars["uci_sub_subnet"]) then
        local postip = vars["uci_sub_ipaddr"]

        local postsub = vars["uci_sub_subnet"]
        for _, v in pairs (subnet_converter) do
           if v[1] == postsub then
              postsub = v[2]
              break
           end
        end

        local masq_src_path = wan_zone .. "masq_src."
        local masq_src_path_content = content_helper.getMatchedContent (masq_src_path)
        proxy.del(masq_src_path)
        proxy.add(masq_src_path)
        proxy.set(masq_src_path .. "@1.value",format("!%s%s",postip,postsub))
        local lan_zone_subnet_path = lan_private_zone .. "subnet."
        proxy.del(lan_zone_subnet_path)
        proxy.add(lan_zone_subnet_path)
        proxy.set(lan_zone_subnet_path .. "@1.value",format("%s%s",postip,postsub))
        proxy.set(subin_fwd .. "enabled","1")
        proxy.set(subout_fwd .. "enabled","1")
      end


   else
      if intfexists == 1 then
        proxy.set("uci.network.interface.@wan.auto","0")
        proxy.apply()
        proxy.del("uci.network.interface.@lan_public.")
        --proxy.del("uci.dhcp.dhcp.@lan_public.")
        proxy.set("uci.network.interface.@wan.unnumbered","")
        proxy.del(lan_private_zone .. "subnet.")
        proxy.set(subin_fwd .. "enabled","0")
        proxy.set(subout_fwd .. "enabled","0")
        proxy.del(wan_zone .. "masq_src.")

        changed = 1
      end
      intfexists = 0
   end


   if changed == 1 then
      proxy.set("uci.network.interface.@wan.auto","1")
      proxy.apply()
   end
end

local sub_en, content, helpmsg = "0", {},{}
if intfexists == 1 then
    -- Shortcuts to validation helpers to make lines shorter
    local gVIPIL = post_helper.getValidationIfPropInList
    local gCV = post_helper.getConditionalValidation
    local gVIES = post_helper.getValidateInEnumSelect
    local vB = post_helper.validateBoolean
    local vNES = post_helper.validateNonEmptyString
    local vSII = post_helper.validateStringIsIP
    local vSIIA = post_helper.advancedIPValidation
    local vIIP4N = post_helper.validateIPv4Netmask

    local function checkIP (value, postdata)
      local err,msg = vNES(value)
      if not err then
        return err,msg
      end
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


    local mapParams = {
        uci_sub_en = "uci.network.interface.@lan_public.ifname",
        uci_sub_ipaddr = "uci.network.interface.@lan_public.ipaddr",
        uci_sub_subnet = "uci.network.interface.@lan_public.netmask",
    }



    local function isSubEnabled(value, object, key)
        return object["uci_sub_en"] == "@lan"
    end

    local mapValid = {
        sub_en = vB,
        uci_sub_ipaddr   = gVIPIL(gCV(isSubEnabled, checkIP), "subnet_present", {"1"}),
        uci_sub_subnet   = gVIPIL(gCV(isSubEnabled, vIIP4N), "subnet_present", {"1"}),
    }

    content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
else
   content["uci_sub_ipaddr"] = ""
   content["uci_sub_subnet"] = ""
end



subnet_present = 0

for _, v in ipairs (proxy.getPN("uci.network.interface.", true)) do
   if v["path"] == "uci.network.interface.@lan_public." then subnet_present = 1 end
end

InRange = format("%s", proxy.get("uci.network.interface.@wan.unnumbered")[1].value or "")
local unnumbered = proxy.get("uci.network.interface.@wan.unnumbered")
if unnumbered[1].value == "lan_public" then
   InRange = "1"
end
ngx.print(ui_helper.createHeader(T"Routed Subnet", true, true), '\
\
<div class="modal-body update">\
<div class="advanced hide">');
local tabs = {}
if session:hasAccess("/modals/setup-modal.lp") then
    tabs[#tabs+1] = {
        desc = T"Connection Setup",
        target = "modals/setup-modal.lp",
    }
end
if session:hasAccess("/modals/subnet-modal.lp") then
    tabs[#tabs+1] ={
        desc = T"Routed Subnet",
        target = "modals/subnet-modal.lp",
        active = "active",
    }
end
if session:hasAccess("/modals/AP-modal.lp") then
    tabs[#tabs+1] ={
        desc = T"Convert to Access Point",
        target = "modals/AP-modal.lp",
    }
end
ngx.print(ui_helper.createModalTabs(tabs), '\
\
</div>\
\
<form class="form-horizontal" method="post" action="modals/subnet-modal.lp">\
<input type="hidden" name="wanip" value="', current_WANIP, '\">',
ui_helper.createMessages(message_helper.popMessages()), '\
<fieldset>\
<legend>', T"Subnet Configuration", '</legend>');
    -- Switch
    local html = {}
    -- Switch on/off
    local subswitch_class = {
        input = {
            class = "monitor-changes"
        }
    }
    html[#html + 1] = ui_helper.createSwitch(T"Enable Subnet", "subnet_present", tostring(subnet_present), subswitch_class)
    if subnet_present == 1 then

        --Class info for input

        local subswitch_class_plus = {
            input = {
                class = "monitor-changes"
            }
        }

        local SubnetClass = {
           group = {
                    class ="monitor-subnet_present monitor-1",
                },
                input = {
                maxlength= "15",
                class = "span2",
              },
        }

        html[#html + 1] = "<div class='monitor-subnet_present monitor-1'>"
        html[#html + 1] = ui_helper.createSwitch(T"In Range WAN IP", "InRange", InRange,subswitch_class)
        html[#html + 1] = "</div>"
        local save_warning = {
        alert = {
              class = "alert-warning monitor-InRange monitor-1 monitor-subnet_present monitor-1"
          },
        }
        html[#html + 1] = ui_helper.createAlertBlock(T"Only enable if your gateway IP address allocated to the WAN interface is in your Public Subnet.", save_warning)


        local SubnetClassRO = {
          group = {
                    class ="monitor-subnet_present monitor-1",
                },

        }
        --Router IP

        if  content["uci_sub_ipaddr"] == "" then content["uci_sub_ipaddr"] = example_ip end
        html[#html+1] = ui_helper.createInputText(T"Gateway Address", "uci_sub_ipaddr", content["uci_sub_ipaddr"], SubnetClass, helpmsg["uci_sub_ipaddr"])
        local subnet_selection = {
            {"255.0.0.0","255.0.0.0 "..T"or".." /8"},
            {"255.128.0.0","255.0.0.0 "..T"or".." /9"},
            {"255.192.0.0","255.192.0.0 "..T"or".." /10"},
            {"255.224.0.0","255.224.0.0 "..T"or".." /11"},
            {"255.240.0.0","255.240.0.0 "..T"or".." /12"},
            {"255.248.0.0","255.248.0.0 "..T"or".." /13"},
            {"255.252.0.0","255.252.0.0 "..T"or".." /14"},
            {"255.254.0.0","255.254.0.0 "..T"or".." /15"},
            {"255.255.0.0","255.255.0.0 "..T"or".." /16"},
            {"255.255.128.0","255.255.128.0 "..T"or".." /17"},
            {"255.255.192.0","255.255.192.0 "..T"or".." /18"},
            {"255.255.224.0","255.255.224.0 "..T"or".." /19"},
            {"255.255.240.0","255.255.240.0 "..T"or".." /20"},
            {"255.255.248.0","255.255.248.0 "..T"or".." /21"},
            {"255.255.252.0","255.255.252.0 "..T"or".." /22"},
            {"255.255.254.0","255.255.254.0 "..T"or".." /23"},
            {"255.255.255.0","255.255.255.0 "..T"or".." /24"},
            {"255.255.255.128","255.255.255.128 "..T"or".." /25"},
            {"255.255.255.192","255.255.255.192 "..T"or".." /26"},
            {"255.255.255.224","255.255.255.224 "..T"or".." /27"},
            {"255.255.255.240","255.255.255.240 "..T"or".." /28"},
            {"255.255.255.248","255.255.255.248 "..T"or".." /29"},
            {"255.255.255.252","255.255.255.252 "..T"or".." /30"}
        }
        local Subnet_Bits = {
            group = {
                class ="monitor-subnet_present monitor-1",
            },
            select = {
                class = "span2"
            }
        }
        if  content["uci_sub_subnet"] == "" then content["uci_sub_subnet"] = "255.255.255.248"  end
        html[#html + 1] = ui_helper.createInputSelect(T"Subnet Mask", "uci_sub_subnet", subnet_selection, content["uci_sub_subnet"], Subnet_Bits)
        SubnetClassRO ["span"] = {id = "from"}
        html[#html+1] = ui_helper.createLabel(T"Subnet ID", "", SubnetClassRO)
        SubnetClassRO ["span"] = {id = "to"}
        html[#html+1] = ui_helper.createLabel(T"Broadcast Address",  "", SubnetClassRO)
        SubnetClassRO ["span"] = {id = "ranges"}
        html[#html+1] = ui_helper.createLabel(T"Range Start", "", SubnetClassRO)
        SubnetClassRO ["span"] = {id = "rangee"}
        html[#html+1] = ui_helper.createLabel(T"Range End", "", SubnetClassRO)

    else
       html[#html+1] = "<input type='hidden' name='uci_sub_ipaddr' value='" .. example_ip .. "'>"
       html[#html+1] = "<input type='hidden' name='uci_sub_subnet' value='" .. example_sub .. "'>"
      local save_warning = {
        alert = {
            class = "alert-warning monitor-subnet_present monitor-1"
        },
      }
      html[#html + 1] = ui_helper.createAlertBlock(T"Please click save to see the full options", save_warning)

    end
    ngx.print(html, '\
</fieldset>\
</form>\
</div>\
<script type=\'text/javascript\'>');
if subnet_present == 1 then
ngx.print('\
function Subcal(){\
   var div = 1;\
     var ip = $(\'[name=uci_sub_ipaddr]\').val().split(".");\
     var mk = $(\'[name=uci_sub_subnet]\').val().split(".");\
     if(ip.length == 4 ){\
     var From = new Array("0","0","0","0");\
     var To = new Array("0","0","0","0");\
     var options = new Array(new Array("255","1"),new Array("254","2"),new Array("252","4"),new Array("248","8"),new Array("240","16"),new Array("224","32"),new Array("192","64"),new Array("128","128"),new Array("0","256"));\
     var sendalert = 0;\
     // for the Octets\
     for (var i = 0; i <= 3 ;i++) {\
     // For alll the subnet options\
       for (var j = 0; j < options.length; j++) {\
           //If the Octet matches the option\
              if (options[j][0] == mk[i]){\
                 div = options[j][1];\
                 if (div == 1){\
                    From[i]=ip[i]\
                    To[i]=ip[i]\
                 }else{\
                   var allowed = 256 / div;\
                   var range = new Array;\
                   // For the range within the mask provided\
                   for (var k = 0; k < allowed; k++) {\
                      range[k] = ((div *(k+1))-1);\
                           if (k==0){\
                              if (ip[i]<= range[k] ){\
                                  From[i]="0";\
                                  To[i]=range[k];\
                              }\
                          }else{\
                              if ((range[k-1]+1 <= ip[i])&&(ip[i]<= range[k] )){\
                                    From[i]=range[k-1]+1;\
                                    To[i]=range[k];\
                              }\
                          }\
                   }\
                 }\
            }\
        }\
     }\
     $(\'#from\').html(From[0]+"."+From[1]+"."+From[2]+"."+From[3])\
     var rangestart = parseInt(From[3])+1\
     $(\'#ranges\').html(From[0]+"."+From[1]+"."+From[2]+"."+rangestart)\
     $(\'#to\').html(To[0]+"."+To[1]+"."+To[2]+"."+To[3])\
     var rangeend =  To[3]-1\
     $(\'#rangee\').html(To[0]+"."+To[1]+"."+To[2]+"."+rangeend)\
      }\
}\
function limittoIP(x){\
  var timer = "3000"\
  var num = x.value.replace(/\,/g,\'\');\
  var numberordot=/^[0-9.]/;\
  var lastchar = x.value.substring(x.value.length-1,x.value.length);\
  var temp = lastchar.match(numberordot) ;\
  if (x.value.length != 0){\
        if(!lastchar.match(numberordot)){\
          tch.showProgress("', T"Only numbers and '.' are accepted!", '");\
          x.value = x.value.substring(0,x.value.length-1);\
          window.setTimeout(function(){ tch.removeProgress(); },timer);\
        }else if (x.value.length != 0){\
          var octets = num.split(".");\
          if (5 > octets.length > 0){\
            var count = 0;\
            while (count < octets.length){\
              if (((octets[count].length==3)&&(octets[count]>255))||(octets[count].length==4)){\
                tch.showProgress("', T"Maximum Number per Octet is 255!", '");\
                var z = 0;\
                var tmpip = "";\
                do\
                 {\
                    if (count < 4){\
                        if (octets[z] > 255){octets[z] = "255"}\
                        tmpip=tmpip+octets[z]\
                        if (z != 3){tmpip=tmpip+"."}\
                    }\
                    z++;\
                 }\
                 while (z <= count);\
                x.value = tmpip;\
                window.setTimeout(function(){ tch.removeProgress();  },timer);\
              }\
              count++;\
            }\
          }else{\
              tch.showProgress("' ,T"Full Address already entered!", '");\
              x.value = x.value.substring(0,x.value.length-1);\
              window.setTimeout(function(){ tch.removeProgress(); },timer);\
          }\
        }\
    }\
}\
\
function allOK(){\
   var timer = "3000"\
   if ($(\'[name=bc]\').val() == $(\'[name=uci_sub_ipaddr]\').val()) {\
      tch.showProgress("',T"Your Router IP Address can not be the same as the Broadcast Address!",'");\
      $("#popUp").css({\'height\': \'250px\'})\
      window.setTimeout(function(){  tch.removeProgress(); },timer);\
      return false;\
   }else if ($(\'[name=id]\').val() == $(\'[name=uci_sub_ipaddr]\').val()) {\
      tch.showProgress("',T"Your Router IP Address can not be the same as the Subnet ID!",'");\
      $("#popUp").css({\'height\': \'250px\'})\
      window.setTimeout(function(){  tch.removeProgress(); },timer);\
      return false;\
   }else{\
   return true;\
   }\
}');
end

ngx.print('\
$(function() {\
    if (', postchk, ' == true) {\
       window.setTimeout(function(){  tch.removeProgress(); },"10000");\
    }');
    if subnet_present == 1 then
      ngx.print('\
      $(\'[name=uci_sub_ipaddr]\').keyup(function() {\
      limittoIP(this);\
      Subcal();\
    });\
    $(\'[name=uci_sub_ipaddr]\').focusout(function() {\
      allOK();\
    });\
    $(\'[name=uci_sub_subnet]\').change(function() {\
      Subcal();\
    });\
    Subcal();');
    end
ngx.print('\
});\
\
</script>',
ui_helper.createFooter());