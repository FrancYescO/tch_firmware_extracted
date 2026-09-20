local require = require
local pairs, ipairs, type, error, concat, remove, format =
      pairs, ipairs, type, error, table.concat, table.remove, string.format
local uci_helper = require("transformer.mapper.ucihelper")
local config_maps = require("transformer.shared.dmzconfig")

local binding = { state = false }
local transactions = {}

local index = 1
local id_dmz_disable = 2
local id_dmz_enable = 3

local M = {}

function M:dmz_state()
    binding.config = "network"
    binding.sectionname = "wan"
    binding.option = "ifname"

    local value = uci_helper.get_from_uci(binding)
    if type(value) == "table" then
        value = concat(value, " ")
    end
    local options = config_maps[binding.config][binding.sectionname]
    for _,v in ipairs(options) do
        if v[index] == binding.option then
            if type(v[id_dmz_enable]) == "table" then
                for _,vv in pairs(v[id_dmz_enable]) do
                    if type(vv) == "string" and not value:match(vv) then
                        return "0"
                    elseif type(vv) == "table" then
                        for _,vvv in pairs(vv) do
                            if not value:match(vvv) then
                                return "0"
                            end
                        end
                    end
                end
                return "1"
            elseif type(v[id_dmz_enable]) == "string" then
                if v[id_dmz_enable] == value then
                    return "1"
                end
            end
            break
        end
    end
    return "0"
end

local function merge_value(v1, v2, operation)
    if type(v1) == "table" then
        if operation == ".add" then
            if type(v2) == "table" then
                for k,v in pairs(v2) do
                    v1[#v1 + 1] = v
                end
            else
                v1[#v1 + 1] = v2
            end
        elseif operation == ".del" then
            if type(v2) == "table" then
                for k,v in pairs(v2) do
                    for kk,vv in pairs(v1) do
                        if v == vv then
                            remove(v1, kk)
                            break
                        end
                    end
                end
            else
                for k,v in pairs(v1) do
                    if v == v2 then
                        remove(v1, k)
                    end
                end
            end
        end
    elseif type(v1) == "string" then
        if operation == ".add" then
            if type(v2) == "table" then
                for k,v in pairs(v2) do
                    v1 = format("%s %s", v1, v)
                end
            else
                v1 = format("%s %s", v1, v2)
            end
        elseif operation == ".del" then
            if type(v2) == "table" then
                for k,v in pairs(v2) do
                    v1 = v1:gsub(v, "")
                end
            else
                v1 = v1:gsub(v2, "")
            end
        end
        v1 = v1:gsub("%s+$", "")
        v1 = v1:gsub("^%s+", "")
    end
    return v1
end


function M:dmz_switch(enabled)
    local id, key, val, atc = id_dmz_disable, "", "", ""
    local sectionname = nil
    local islist = false

    if enabled ~= "0" and enabled ~= "1" then
        return nil, "Invalid parameter."
    end
    if enabled == "1" then
        id = id_dmz_enable
    end

    for config, sections in pairs(config_maps) do
        binding.config = config
        for name,options in pairs(sections) do
            for _,v in ipairs(options) do
                binding.sectionname = name
                binding.option = nil
                if type(v[index]) == "string" and v[index] ~= ".type" then
                    binding.option = v[index]
                elseif type(v[index]) == "table" then
                    sectionname = nil
                    key = v[index][1]
                    val = v[index][2]
                    act = v[index][3]
                    uci_helper.foreach_on_uci(binding, function(s)
                        if s[key] == val then
                            sectionname = s['.name']
                            return false
                        end
                    end)
                    if not sectionname and act == ".add" and v[id] then
                        sectionname = uci_helper.add_on_uci(binding)
                    end
                    if not sectionname then
                        return nil, "No suitable section could be used!"
                    end
                    binding.sectionname = sectionname
                end
                if v[id] then
                    if type(v[id]) == "string" then
                        uci_helper.set_on_uci(binding, v[id])
                    elseif type(v[id]) == "table" then
                        for opt,val in pairs(v[id]) do
                            if type(opt) ~= "number" then
                                if opt == ".add" or opt == ".del" then
                                    local value = uci_helper.get_from_uci(binding)
                                    value = merge_value(value, val, opt)
                                    uci_helper.set_on_uci(binding, value)
                                else
                                    binding.option = opt
                                    uci_helper.set_on_uci(binding, val)
                                end
                            else
                                islist = true
                                break
                            end
                        end
                        if islist then
                            uci_helper.set_on_uci(binding, v[id])
                            islist = false
                        end
                    end
                else
                    uci_helper.delete_on_uci(binding)
                end
            end
        end
        transactions[config] = true
    end
    binding.sectionname = nil
    binding.option = nil
    for config in pairs(transactions) do
        binding.config = config
        uci_helper.commit(binding)
    end
    return true, "Switch successfully"
end

return M
