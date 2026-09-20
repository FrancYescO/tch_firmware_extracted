<%
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local table, format, match, len, sub = table, string.format, string.match, string.len, string.sub
local json = require("dkjson")
local args = ngx.req.get_uri_args()

local action = args.Action
local FirstName = args.FirstName
local LastName = args.LastName
local HomeNumber = args.HomeNumber
local MobileNumber = args.MobileNumber
local WorkNumber = args.WorkNumber
local ID = args.Id
ngx.header.content_type = "application/json;charset=UTF-8"

local buffer = {}
local success = {}
local contact_list = {}
local phonepath = "rpc.mmpbx.phonebook_entry."

local maxlength = 40   -- the max length of FirstName, LastName from T-Voice
if action == "Add" and (FirstName or LastName) and (HomeNumber or MobileNumber or WorkNumber) then
    local path  = "rpc.mmpbx.phonebook.newentry"

    local firstname = FirstName and len(FirstName) > maxlength and sub(FirstName, 0, maxlength) or FirstName or ""
    local lastname = LastName and len(LastName) > maxlength and sub(LastName, 0, maxlength) or LastName or ""

    local value = format("%s,%s,%s,%s,%s", firstname, lastname, HomeNumber or "", MobileNumber or "",WorkNumber or "")

    local _, entryID = proxy.set(path, value)
    local errmsg = (entryID and entryID[1] and entryID[1].errmsg) or ""
    local id = match(errmsg, "(-*%d+)")

    if id == "-1" then
       ngx.exit(520)      --exceed the max number of contacts
    elseif id then
        local reply = { created = {} }
        local items = reply.created
        items[#items + 1] = {
           FirstName = firstname,
           LastName = lastname,
           HomeNumber = HomeNumber,
           MobileNumber = MobileNumber,
           WorkNumber = WorkNumber,
           id = id,
        }
        success = json.encode (reply, { indent = true, buffer = buffer })
        if success then
           ngx.status = 201
           ngx.print(buffer)
           ngx.exit(ngx.HTTP_OK )
        else
           ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end
    end
    ngx.exit(510)
elseif action == "Update" and ID and (FirstName or LastName) and (HomeNumber or MobileNumber or WorkNumber) then
    local firstname = FirstName and len(FirstName) > maxlength and sub(FirstName, 0, maxlength) or FirstName or ""
    local lastname = LastName and len(LastName) > maxlength and sub(LastName, 0, maxlength) or LastName or ""
    ID = string.format("%s", ID)
    local updateR = false
    local content_update = {}
    content_update[phonepath .. "@" .. ID .. ".FirstName"] = firstname
    content_update[phonepath .. "@" .. ID .. ".LastName"] = lastname
    content_update[phonepath .. "@" .. ID .. ".HomeNumber"] = HomeNumber
    content_update[phonepath .. "@" .. ID .. ".MobileNumber"] = MobileNumber
    content_update[phonepath .. "@" .. ID .. ".WorkNumber"] = WorkNumber
    updateR = proxy.set(content_update)
    if updateR then
        ngx.exit(202)
    else
        ngx.exit(511)
    end
elseif action == "List" then
    local phonebookTable = content_helper.convertResultToObject(phonepath .. "@", proxy.get(phonepath))
    local phoneList = phonebookTable
    local content = proxy.get("rpc.mmpbx.phonebook.version")
    local version = content and content[1] and content[1].value or 0
    for _, v in ipairs(phonebookTable) do
         v.id = v.paramindex
         v.paramindex = nil
    end
    contact_list = { ["version"] = tonumber(version), ["contacts"] = phonebookTable }
    success = json.encode (contact_list, { indent = true, buffer = buffer })
    if success then
        ngx.print(buffer)
        ngx.exit(ngx.HTTP_OK )
    else
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
elseif action == "Delete" and ID then
    local delR = true
    if type(ID) == 'table' then
        for i=1, #ID do
            local entryID = string.format("%s", ID[i])
            delR = delR and proxy.del(phonepath .. "@" .. entryID .. ".")
        end
    else
        ID = string.format("%s", ID)
        delR = delR and proxy.del(phonepath .. "@" .. ID .. ".")
    end
    if delR then
        ngx.exit(203)
    else
        ngx.exit(512)
    end
elseif action == "Version" then
    local content = proxy.get("rpc.mmpbx.phonebook.version")
    local version = content and content[1] and content[1].value or 0
    local Version = {["version"] = tonumber(version)}
    success = json.encode (Version, { indent = true, buffer = buffer })
    if success then
        ngx.print(buffer)
        ngx.exit(ngx.HTTP_OK )
    else
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
else
    ngx.exit(552)
end

%>
