local string, tonumber = string, tonumber

local M = {}

function M.parse_creg_state(data)
    -- +CREG: <n>, <stat>, <lac>, <cid>
    local stat, lac, cid = string.match(data, '+CREG:%s*%d,(%d),"(.-)","(.-)"')
    if stat then return tonumber(stat), tonumber(lac, 16), tonumber(cid, 16) end
    -- +CREG: <stat>, <lac>, <cid>, <dunno>
    stat, lac, cid = string.match(data, '+CREG:%s*(%d),"(.-)","(.-)",%d')
    if stat then return tonumber(stat), tonumber(lac, 16), tonumber(cid, 16) end
    -- +CREG: <stat>, <lac>, <cid>
    stat, lac, cid = string.match(data, "+CREG:%s*(%d),%s?(%d),%s?(%d)")
    if stat then return tonumber(stat), tonumber(lac, 16), tonumber(cid, 16) end
    -- +CREG: <n>, <stat>
    stat = string.match(data, "+CREG:%s*%d,%s?(%d)")
    if stat then return tonumber(stat) end
    -- +CREG: <stat>
    stat = string.match(data, "+CREG:%s?(%d)")
    if stat then return tonumber(stat) end

    return nil
end

--[[
    CREG_NOT_REGISTERED = 0,
    CREG_REGISTERED = 1,
    CREG_SEARCHING = 2,
    CREG_REGISTRATION_DENIED = 3,
    CREG_UNKNOWN = 4,
    CREG_REGISTERED_ROAMING = 5,
    CREG_REGISTERED_SMS = 6,
    CREG_REGISTERED_ROAMING_SMS = 7,
    CREG_EMERGENCY_SERVICE = 8,
    CREG_REGISTERED_NO_CSFB = 9,
    CREG_REGISTERED_ROAMING_NO_CSFB = 10
]]--
function M.get_state(device)
    local ret = device:send_singleline_command("AT+CREG?", "+CREG:")
    local state, lac, cid
    if ret then
        state, lac, cid = M.parse_creg_state(ret)
    end
    return M.creg_state_to_string(state), lac, cid
end

function M.creg_state_to_string(state)
    if state then
        if state == 1 or state == 5 or state == 6 or state == 7 or state == 9 or state == 10 then
            return "registered"
        elseif state == 2 then
            return "not_registered_searching"
        elseif state == 3 then
            return "registration_denied"
        end
    end
    return "not_registered"
end

function M.get_plmn(device)
    local mcc, mnc, description
    device:send_command('AT+COPS=3,2')
    local ret = device:send_singleline_command("AT+COPS?", "+COPS:")
    if ret then
        local oper = string.match(ret, '+COPS:%s?%d,%d,"(.+)",%d')
        if tonumber(oper) then
            mcc = string.sub(oper, 1, 3)
            mnc = string.sub(oper, 4)
        end
    end
    device:send_command('AT+COPS=3,0')
    ret = device:send_singleline_command("AT+COPS?", "+COPS:")
    if ret then
        description = string.match(ret, '+COPS:%s?%d,%d,"(.+)",%d')
    end
    if not mcc and not mnc and not description then return nil end
    return { mcc = mcc, mnc = mnc, description = description }
end

function M.get_radio_interface(device)
    device:send_command('AT+COPS=3,2')
    local ret = device:send_singleline_command("AT+COPS?", "+COPS:")
    if ret then
        local radio_interface = tonumber(string.match(ret, '+COPS:%s?%d,%d,".-",(%d)'))
        if radio_interface then
            if radio_interface >= 0 and radio_interface <= 3 and radio_interface ~= 2 then
                return "gsm"
            elseif radio_interface == 2 or (radio_interface >= 4 and radio_interface <= 6) then
                return "umts"
            elseif radio_interface == 7 then
                return "lte"
            end
        end
    end
    return "no_service"
end

function M.get_ps_state(device)
    local ret = device:send_singleline_command("AT+CGATT?", "+CGATT:")
    if ret then
        local state = string.match(ret, '+CGATT:%s?(%d)')
        if state == "1" then
            return "attached"
        end
    end
    return "detached"
end

return M



