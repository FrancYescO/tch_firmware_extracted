local taint_mt = require("web.taint").taint_mt
local dm = require("datamodel")
local orig_set = dm.set
local orig_del = dm.del
local orig_add = dm.add
local orig_apply = dm.apply
local monitor_paths = {}
local monitor_section_paths = {}

local function monitor_paths_generater()
    local monitors_path = "uci.guiwatcher.guiwatcher.@guiwatcher.path."
    local path = dm.get(monitors_path)
    if path == nil or type(path) ~= "table" then
        return
    end
    setmetatable(monitor_paths, taint_mt)
    for path,value in pairs(path) do
        local monitor_path = value.value
        local tmp_tb = monitor_paths
        for sub_path in monitor_path:gmatch("[^$.]+") do
            if tmp_tb[sub_path] == nil then
                setmetatable(tmp_tb, taint_mt)
                tmp_tb[sub_path] = {}
            end
        tmp_tb = tmp_tb[sub_path]
        end
    end
end

local function monitor_section_paths_generater()
    local monitor_path = "uci.guiwatcher.guiwatcher.@guiwatcher.section_path."
    local monitor_paths = dm.get(monitor_path)
    for p,value in pairs(monitor_paths) do
        table.insert(monitor_section_paths,value.value)
    end
end

local function is_modified(old_value_path, new_value)
    local old_value = dm.get(old_value_path)[1].value
    if(new_value ~= old_value) then
        return true
    end
    return false
end

local function is_monitored(path)
    if path == nil then
        return false
    end
    local tmp_tb = monitor_paths
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
    for _,value in ipairs(monitor_section_paths) do
        local taint_path = path
        if not string.istainted(path) then
            taint_path = string.taint(path)
        end
        if value ~= nil and value ~= "" and (taint_path:match(value) ~= nil or value == "*") then
            return true
        end
    end
    return false
end

local function need_notify(arg1,arg2)
    if arg2 then
        if is_monitored(arg1) then
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
            if (is_monitored(path)) then
                if(is_modified(path,value)) then
                    return true
                end
            end
        end
        return false
    end
end

local notified = false
local function notify(arg1,arg2,action)
    local modify_time_path = "uci.guiwatcher.guiwatcher.@guiwatcher.lastmodifiedbyuser"
    if action == "set" then
        if notified then
            return
        end
        if (need_notify(arg1,arg2)) then
            notified = true
        end
    elseif action == "add" or action == "del" then
        if is_section_monitored(arg1) then
            notified = true
        end
    elseif action == "apply" then
        if notified then
            orig_set(modify_time_path,os.date("!%Y-%m-%dT%XZ"))
            notified = false
        end
    end
end

monitor_paths_generater()
monitor_section_paths_generater()

dm.set = function(arg1,arg2)
    notify(arg1,arg2,"set")
    return orig_set(arg1,arg2)
end

dm.del = function(arg1)
    notify(arg1,nil,"del")
    return orig_del(arg1)
end

dm.add = function(arg1,arg2)
    notify(arg1,arg2,"add")
    return orig_add(arg1,arg2)
end

dm.apply = function()
    notify(arg1,arg2,"apply")
    return orig_apply()
end