local taint_mt = require("web.taint").taint_mt
local dm = require("datamodel")

local function is_modified(old_value_path, new_value)
    local old_value = dm.get(old_value_path)[1].value
    if(new_value ~= old_value) then
        return true
    end
    return false
end

local function monitor_table_generater(path)
    local monitor_tb = {}
    if path == nil or type(path) ~= "table" then
        return monitor_tb
    end
    setmetatable(monitor_tb, taint_mt)
    for path,value in pairs(path) do
        local monitor_path = value.value
        local tmp_tb = monitor_tb
        for sub_path in monitor_path:gmatch("[^$.]+") do
                if tmp_tb[sub_path] == nil then
                    setmetatable(tmp_tb, taint_mt)
                    tmp_tb[sub_path] = {}
                end
                tmp_tb = tmp_tb[sub_path]
        end
    end
    return monitor_tb
end

local function is_monitored(path,compared_paths)
    if path == nil or compared_paths == nil or type(compared_paths) ~= "table" then
        return false
    end
    local tmp_tb = compared_paths
    for p in path:gmatch("[^$.]+") do
        if tmp_tb[p] == nil then
            if tmp_tb["*"] ~= nil then
                tmp_tb = tmp_tb["*"]
            elseif next(tmp_tb) == nil then
                    return true
            else
                    return false
            end
        else
            tmp_tb = tmp_tb[p]
        end
    end
    return true
end

local function is_section_monitored(path)
    local monitors_path = "uci.guiwatcher.guiwatcher.@guiwatcher.section_path."
    local monitor_paths = dm.get(monitors_path)
        for p,value in pairs(monitor_paths) do
            local monitor_path = value.value
            local taint_path = path
            if not string.istainted(path) then
                taint_path = string.taint(path)
            end
            if monitor_path ~= nil and monitor_path ~= "" and (taint_path:match(monitor_path) ~= nil or monitor_path == "*") then
                return true
            end
        end
        return false
end

local function need_notify(arg1,arg2)
    local monitors_path = "uci.guiwatcher.guiwatcher.@guiwatcher.path."
    local monitor_paths = dm.get(monitors_path)
    local monitor_tb = monitor_table_generater(monitor_paths)
    if arg2 then
        if is_monitored(arg1,monitor_tb) then
            if(is_modified(arg1,arg2)) then
                return true
            end
        end
        return false
    else
        if type(arg1) ~= "table" then
            return false
        end
        for path,value in pairs(arg1) do
            if (is_monitored(path,monitor_tb)) then
                if(is_modified(path,value)) then
                    return true
                end
            end
        end
        return false
    end
end

local notified = "0"
local function notify(arg1,arg2,orig_set,action)
    local modify_time_path = "uci.guiwatcher.guiwatcher.@guiwatcher.lastmodifiedbyuser"
    local notified_value = "1"
    local unnotified_value = "0"
    if action == "set" then
        if notified == notified_value then
            return
        end
        if (need_notify(arg1,arg2)) then
            notified = notified_value
        end
    elseif action == "add" or action == "del" then
        if is_section_monitored(arg1) then
            notified = notified_value
        end
    elseif action == "apply" then
        if notified == notified_value  then
            orig_set(modify_time_path,os.date("!%Y-%m-%dT%XZ"))
            notified = unnotified_value
	end
    end
end

local orig_set = dm.set
dm.set = function(arg1,arg2)
    notify(arg1,arg2,orig_set,"set")
    return orig_set(arg1,arg2)
end

local orig_del = dm.del
dm.del = function(arg1)
    notify(arg1,nil,orig_set,"del")
    return orig_del(arg1)
end

local orig_add = dm.add
dm.add = function(arg1,arg2)
    notify(arg1,arg2,orig_set,"add")
    return orig_add(arg1,arg2)
end

local orig_apply = dm.apply
dm.apply = function()
    notify(arg1,arg2,orig_set,"apply")
    return orig_apply()
end
