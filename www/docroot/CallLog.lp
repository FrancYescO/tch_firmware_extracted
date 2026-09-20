<%
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local table = table

local json = require("dkjson")
local args = ngx.req.get_uri_args()

local buffer = {}
local basepath = "rpc.mmpbx.calllog.info."

local function time_convertion(value)
    local res = string.gsub(value, "(%s+)", "T")
    if res then
        return res .. "Z"
    end
    return ""
end

local function getLogEntries(firstId)
    local logTable = content_helper.convertResultToObject(basepath .. "@", proxy.get(basepath))
    local log_entries = {}
    for _,v in ipairs(logTable) do
        if v.CalllogID and tonumber(v.CalllogID) >= firstId then
            local item = {}
            item.id = v.CalllogID
            item.RemoteNumber = v.Remoteparty
            item.State = v.callState
            item.Reason = v.terminationReason
            item.Read = v.ReadStatus == "1" and "Yes" or "No"
            item.Start = time_convertion(v.startTime)
            if v.endTime == "0" then
                item.End = "0"
            else
                item.End = time_convertion(v.endTime)
            end
            if v.Direction == "2" then
                item.Direction = "OUTGOING"
            elseif v.connectedTime == "0" then
                item.Direction = "Missed"
            else
                item.Direction = "Answered"
            end
            log_entries[#log_entries+1] = item
        end
    end
    table.sort(log_entries, function(a, b)
        if a.id and b.id and tonumber(a.id) < tonumber(b.id) then
            return true
        else
            return false
        end
    end)
    return log_entries
end

ngx.header.content_type = "application/json;charset=UTF-8"

if args.Action == "List" and tonumber(args.FirstId) then
    local calllog = { calllog = getLogEntries(tonumber(args.FirstId)) }
    local success = json.encode (calllog, { indent = true, buffer = buffer })
    if success then
        ngx.print(buffer)
        ngx.exit(ngx.HTTP_OK )
    else
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
elseif args.Action == "Update" and args.Id and args.Read == "yes" then
    local path = string.format(basepath .. "@%s.ReadStatus", args.Id)
    local ok, msg = proxy.set(path, "1")
    if not ok then
        ngx.exit(512)
    end
    ngx.exit(202)
elseif args.Action == "Delete" and args.Id then
    if type(args.Id) == 'table' then
        for _,v in pairs(args.Id) do
            local entry_path = string.format(basepath .. "@%s.", v)
            local ok, msg = proxy.del(entry_path)
            if not ok then
                ngx.exit(512)
            end
        end
    else
        local entry_path = string.format(basepath .. "@%s.", args.Id)
        local ok, msg = proxy.del(entry_path)
        if not ok then
            ngx.exit(512)
        end
    end
    ngx.exit(202)
else
    ngx.exit(552)
end

%>
