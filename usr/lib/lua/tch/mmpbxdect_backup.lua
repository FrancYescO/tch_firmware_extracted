local uci = require("uci")
local logger = require("transformer.logger")
local log = logger.new("mmpbx_custo_clean_up", 2)

local table_remove, concat= table.remove, table.concat
local find = string.find
local tostring = tostring
local cursor = uci.cursor()
local needs_to_commit = false
local profile_helper = require("transformer.shared.profile_helper")
local uci_helper = require("transformer.mapper.ucihelper")
--Helper functions
local function get_config_by_section_type(config, sectype)
    local ifce = {}
    cursor:foreach(config, sectype, function(s) ifce[s[".index"]]=s end)
    return ifce
end

local function modify_list_on_uci(cmd)
    if not cmd.uci_secname then return end
    -- convert string to list
    if type(cmd.value) == "string" then
        local tmp = cmd.value
        cmd.value = { tmp }
    end
    -- UCI binding do not accept empty list
    if #cmd.value > 0 then
        cmd.uci_config  = tostring(cmd.uci_config)
        cmd.uci_secname = tostring(cmd.uci_secname)
        cmd.uci_option  = tostring(cmd.uci_option)
        local rc,errmsg = cursor:set(cmd.uci_config, cmd.uci_secname, cmd.uci_option, cmd.value)
        log:info("uci add_list %s.%s.%s { %s } => %s %s", cmd.uci_config,
            cmd.uci_secname, cmd.uci_option, concat(cmd.value, ","), tostring(rc), rc and "" or errmsg)
    end
    needs_to_commit = true
end

local function delete_on_uci(cmd)
    if not cmd.uci_secname then return end
    if not cmd.uci_config then return end

    cmd.uci_config  = tostring(cmd.uci_config)
    cmd.uci_secname = tostring(cmd.uci_secname)
    if cmd.uci_option then
        cmd.uci_option  = tostring(cmd.uci_option)
        local rc,errmsg = cursor:delete(cmd.uci_config, cmd.uci_secname, cmd.uci_option)
        log:info("uci delete %s.%s.%s => %s %s", cmd.uci_config, cmd.uci_secname,
            cmd.uci_option, tostring(rc), rc and "" or tostring(errmsg))
    else
        local rc,errmsg = cursor:delete(cmd.uci_config, cmd.uci_secname)
        log:info("uci delete %s.%s => %s %s", cmd.uci_config, cmd.uci_secname,
            tostring(rc), rc and "" or tostring(errmsg))
    end
    needs_to_commit = true
end

local function commit_to_uci(config)
    config = tostring(config)
    local rc,errmsg = cursor:commit(config)
    log:info("uci commit %s => %s %s", config,
        tostring(rc), rc and "" or tostring(errmsg))
end

--Function to clean up config based on the given structure.
local function cleanUpConfig(config_info)
    local ucicmd = {}
    local rm_list_iteam = {}

    for _,v in pairs(config_info) do
        local config = get_config_by_section_type("mmpbx", v[1])
        if v[3] == nil and v[2] ~= "" then
            for _,w in pairs(config) do
                if find(w[".name"], v[2]) then
                    ucicmd.uci_config = "mmpbx"
                    ucicmd.uci_secname = w[".name"]
                    delete_on_uci(ucicmd)
                end
            end
        elseif v[2] == "" then
            for _,w in pairs(config) do
                if v[3] == "option" then
                    if find(w[v[4]], v[5]) then
                        ucicmd = {}
                        ucicmd.uci_config = "mmpbx"
                        ucicmd.uci_secname = w[".name"]
                        delete_on_uci(ucicmd)
                    end
                elseif v[3] == "list" and w[v[4]] then
                    rm_list_iteam = {}
                    for i,u in ipairs(w[v[4]]) do
                        if find(u, v[5]) then
                            rm_list_iteam[#rm_list_iteam + 1] = i
                        end
                    end
                    if #rm_list_iteam > 0 then    --List need to modify.
                        ucicmd = {}
                        if #rm_list_iteam == #w[v[4]] then    --All elements in list needs to delete, so delete section.
                            ucicmd.uci_config = "mmpbx"
                            ucicmd.uci_secname = w[".name"]
                            delete_on_uci(ucicmd)
                        else
                            for i=#rm_list_iteam,1,-1 do -- Delition need to do in reverse
                                table_remove(w[v[4]],rm_list_iteam[i])
                                if v[1] == "outgoing_map" and #w["priority"] > rm_list_iteam[i] then    -- For outgoing maps need to modify the priority.
                                    table_remove(w["priority"],rm_list_iteam[i])
                                end
                            end
                            ucicmd.uci_config = "mmpbx"
                            ucicmd.uci_secname = w[".name"]
                            ucicmd.uci_option = v[4]
                            ucicmd.value = w[v[4]]
                            modify_list_on_uci(ucicmd)
                            if v[1] == "outgoing_map" then    -- For outgoing maps need to modify the priority.
                                ucicmd.uci_option = "priority"
                                ucicmd.value = w["priority"]
                                modify_list_on_uci(ucicmd)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Function to clean up DECT configuration.
local function cleanUpDECTConfig()
    local dect_sec_info = {
      --{section_type,   section_name, used_as,  related_to, value },
        {"device",       "dect"                                    },
        {"outgoing_map", "",           "option", "device",   "dect"},
        {"internal_map", "",           "option", "device",   "dect"},
        {"incoming_map", "",           "list",   "device",   "dect"},
        {"service",      "",           "list",   "device",   "dect"},
    }
    cleanUpConfig(dect_sec_info)
end

local transactions = {}
local binding = {}

local function line_commit()
    local binding = {}
    for config in pairs(transactions) do
        binding.config = config
        uci_helper.commit(binding)
    end
    transactions = {}
end

local function line_revert()
    local binding = {}
    for config in pairs(transactions) do
        binding.config = config
        uci_helper.revert(binding)
    end
    transactions = {}
end

local args         = {...}
local backup  = args[1]
local profile = args[2]


if backup == '0' then    --Backup part
    cleanUpDECTConfig()
end

if backup == '1' then    --Restore part
    binding.config = "mmpbxrvsipnet"
    transactions[binding.config] = true
    profile_helper.profile_delete(profile, transactions, commitapply)
    line_commit()
    line_revert()

end

--Commit changes
if needs_to_commit then
    commit_to_uci("mmpbx")
    needs_to_commit = false
end
