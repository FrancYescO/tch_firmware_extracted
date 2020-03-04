--pretranslated: do not change this file
 
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local post_helper = require("web.post_helper")
local tonumber = tonumber
local format, match, find, sub = string.format, string.match, string.find, string.sub

local function checkBlockValue(str)
    local val = tonumber(str, 16)
    if val and val <= 0xFFFF then
        return true
    else
        return false
    end
end

local function validateStringIsIPv6Prefix(prefix, object, key)
    local compressed=false
    local counter, borderl, borderh= 0,1

    local value, length = match(prefix, "^(.*)/(.*)$")

    if not value or value == "" or not length or length == "" then
        return nil, T"Invalid string."
    end

    local len = #value
    object["wan6_ip6prefix"] = value
    object["wan6_ip6prefixlen"] = length

    local success, msg = post_helper.getValidateNumberInRange(0,128)(length)
    if not success then
        return success, msg
    end

    --The address start with "::"
    if sub(value,1,2) == "::" then
        borderl = 3
        compressed = true
    end

    --check all the address group, and save the address group numbers
    while true do
        --find "::", we assume it's compressed address
        if sub(value,borderl, borderl) == ":" then
            if compressed == true then
                return nil, T"Invalid IPv6 Prefix, two or more '::'."
            end
            compressed = true
            borderl = borderl + 1
            if borderl > len then
                if counter < 8 then
                    return true
                else
                    return nil, T"Invalid IPv6 Prefix, address group is invalid."
                end
            end
        end

        borderh = find(value, ":", borderl, true)
        if borderh == borderl then
            return nil, T"Invalid IPv6 Prefix, ':::' was found."
        end

        --last address group
        if not borderh then
            if checkBlockValue(sub(value, borderl, len))==false then
                return nil, T"Invalid IPv6 Prefix, group value is too large."
            end
            counter = counter+1
        break end

        if checkBlockValue(sub(value, borderl, borderh-1))==false then
            return nil, T"Invalid IPv6 Prefix, group value is too large"
        end
        counter = counter+1

        if borderh+1 > len then
            if counter < 8 then
                return true
            else
                return nil, T"Invalid IPv6 Prefix, address group is invalid."
            end
        else
            borderl = borderh + 1
        end
    end

    if counter == 8 and compressed == false then
        return true
    elseif counter < 8 then
        return true
    else
        return nil, T"Invalid IPv6 Prefix, address group is invalid."
    end
end

local function alwaysTrue()
    return true
end
-- Configurable data
local mapParams = {
    wan6_ip4prefixlen = "uci.network.interface.@wan6.ip4prefixlen",
    wan6_ip6prefix = "uci.network.interface.@wan6.ip6prefix",
    wan6_ip6prefixlen = "uci.network.interface.@wan6.ip6prefixlen",
    wan6_peeraddr = "uci.network.interface.@wan6.peeraddr",
}

--wan6_ip6prefixlen was checked in the function validateStringIsIPv6Prefix and there is no need to check it again in validation function of wan6_ip6prefixlen.
local mapValid = {
    wan6_ip4prefixlen    = post_helper.getValidateNumberInRange(0,32),
    wan6_ip6prefix   = validateStringIsIPv6Prefix,
    wan6_peeraddr   = post_helper.validateStringIsIP,
    wan6_ip6prefixlen = alwaysTrue,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

  ngx.print('\
\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<fieldset>\
    <legend>');  ngx.print( T"6rd configuration" ); ngx.print('</legend>\
    ');  
        local html = {}

        html[#html+1] = ui_helper.createInputText(T"IPv4 Mask Length", "wan6_ip4prefixlen", content["wan6_ip4prefixlen"], nil, helpmsg["wan6_ip4prefixlen"])
        local ip6prefix = content["wan6_ip6prefix"]
        if content["wan6_ip6prefixlen"] ~= "" then
            ip6prefix = format("%s/%s", content["wan6_ip6prefix"], content["wan6_ip6prefixlen"]) 
        end
        html[#html+1] = ui_helper.createInputText(T"6rd Prefix", "wan6_ip6prefix", ip6prefix, nil, helpmsg["wan6_ip6prefix"])
        html[#html+1] = ui_helper.createInputText(T"Border Relay Address", "wan6_peeraddr", content["wan6_peeraddr"], nil, helpmsg["wan6_peeraddr"])

        ngx.print(html)
      ngx.print('\
</fieldset>\
'); 