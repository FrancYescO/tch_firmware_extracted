<%
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local table, format, match, len, sub, find = table, string.format, string.match, string.len, string.sub, string.find
local json = require("dkjson")

ngx.header.content_type = "application/json;charset=UTF-8"
local buffer = {}
local success = {}
local method = ngx.req.get_method()
if method == "GET" then
    local args = ngx.req.get_uri_args()
    local action = args.Action
    local FirstName = args.FirstName
    local LastName = args.LastName
    local HomeNumber = args.HomeNumber
    local MobileNumber = args.MobileNumber
    local WorkNumber = args.WorkNumber
    local ID = args.Id

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
        local contact_list = { ["version"] = tonumber(version), ["contacts"] = phonebookTable }
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
    elseif action == "BulkAddQuery" then
        local bulkaddstate = proxy.get("rpc.mmpbx.phonebook.bulkaddstate")
        local state = bulkaddstate and bulkaddstate[1] and bulkaddstate[1].value
        local data = {}
        if state == "none" then
            data = {["status"] = state}
        else
            local bulkaddid = proxy.get("rpc.mmpbx.phonebook.bulkaddid")
            local id = bulkaddid and bulkaddid[1] and bulkaddid[1].value
            data  = {["status"] = state, ["BulkAddId"] = id}
        end
        success = json.encode (data, { indent = true, buffer = buffer })
        if success then
            ngx.print(buffer)
            ngx.exit(ngx.HTTP_OK )
        else
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end
    else
        ngx.exit(552)
    end
elseif method == "POST" then
    local args = ngx.req.get_post_args()
    local data = args["contacts"]
    args = nil
    if data then
        data = string.untaint(data)
        local obj, _, err = json.decode(data, 1, nil)

        if not err then
            if obj.Action == "BulkAdd" then
                local bulkaddstate = proxy.get("rpc.mmpbx.phonebook.bulkaddstate")
                local state = bulkaddstate and bulkaddstate[1] and bulkaddstate[1].value
                if state == "none" then
                    local filename = "/tmp/bulkadd"
                    fd = io.open(filename, "w")
                    if fd then
                        fd:write(data)
                        data = nil
                        fd:close()
                    end
                    proxy.set("rpc.mmpbx.phonebook.bulkadd", "1")
                    proxy.apply()
                end
                local id_data = proxy.get("rpc.mmpbx.phonebook.bulkaddid")
                local id = id_data and id_data[1] and id_data[1].value
                local bulkaddid = { ["BulkAddId"] = string.format("%s",id) }
                success = json.encode (bulkaddid, { indent = true, buffer = buffer })
                if success then
                    ngx.print(buffer)
                    ngx.exit(state == "none" and ngx.HTTP_OK or 520)
                else
                    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
                end
            end
        else
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end
    end
end

%>
