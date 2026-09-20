<%
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local json = require("dkjson")
local open = io.open
local args = ngx.req.get_uri_args()
local action = args.Action
local clientid = args.ClientID
local name =  args.Name

local sipdev_path = "uci.mmpbxrvsipdev.device."
local internalmap_path = "uci.mmpbx.internal_map."
local internalprofile_path = "uci.mmpbxinternalnet.profile."
local phonepath = "rpc.mmpbx.phonebook_entry."
local rpc_sipdev_path = "rpc.mmpbx.rvsipdev."

local function generate_password()
    local key = ("%02X"):rep(16)
    local fd = open("/dev/urandom", "r")
    if fd then
        local bytes = fd:read(16)
        fd:close()
        return key:format(bytes:byte(1,16))
    end
    return ""
end

local function getSipServerIpaddr()
    local interface_data = proxy.get("uci.mmpbxrvsipdev.sip_server.interface")
    local interface = interface_data and interface_data[1] and interface_data[1].value
    if not interface then
        return ""
    end
    local ipaddr_data = proxy.get("rpc.network.interface.@" .. interface .. ".ipaddr")
    return ipaddr_data and ipaddr_data[1] and ipaddr_data[1].value or ""
end

local function getIntNumData()
    local internalmap_data = proxy.get(internalmap_path)
    local res = {}
    local profile
    for _, v in pairs(internalmap_data) do
        if v["param"] == "device" then
            res[string.format("%s",v["value"])] = v["path"]
        elseif v["param"] == "profile" then
            res[v["path"]] = v["value"]
        end
    end
    return res
end

local function getIntNum(internalmap_data, sipdev_data)
    local internalnumber = ""
    if type(internalmap_data) ~= 'table' and type(sipdev_data) ~= 'table' and not sipdev_data["paramindex"] then
        return internalnumber
    end
    local path = internalmap_data[sipdev_data["paramindex"]]
    if internalmap_data[path] then
        local number = proxy.get(internalprofile_path .. "@" .. internalmap_data[path] .. ".number")
        internalnumber = number and number[1] and number[1].value or ""
    end
    return internalnumber
end

local function getSipProvisionData(sipdev_data)
    local res = {}
    if sipdev_data then
        res["user"] = sipdev_data["user_name"]
        res["transport"] = "TCP"
        res["password"] = sipdev_data["password"]
        local ipaddr = getSipServerIpaddr()
        res["URI"] = sipdev_data["uri"] .. "@" .. ipaddr
        local internalmap_data = getIntNumData()
        res["internalnumber"] = getIntNum(internalmap_data, sipdev_data)
    end
    return res
end

-- for Action QueryConfig and ReleaseConfig
-- and for ReleaseConfig, we need to filter out the Released clientid
local function getConfigListData(sipdevs_data, internalmap_data, clientid)
    local ipaddr = getSipServerIpaddr()
    local res = {}
    for _, v in pairs(sipdevs_data) do
        local clientmac = string.format("%s", v["clientmac"])
        if clientmac ~= "" and  (not clientid or clientmac ~= clientid) then
            local i = #res + 1
            res[i] = {}
            res[i]["name"] = v["clientname"]
            res[i]["clientId"] = v["clientmac"]
            res[i]["URI"] = v["uri"] .. "@" .. ipaddr
            res[i]["internalnumber"] =  getIntNum(internalmap_data, v)
        end
    end
    res = { ConfigList = res }
    return res
end

local function printJsonData(data)
    local buffer = {}
    local success = json.encode (data, { indent = true, buffer = buffer })
    if success then
        ngx.header.content_type = "application/json;charset=UTF-8"
        ngx.print(buffer)
        ngx.exit(ngx.HTTP_OK )
    else
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
end

local function getPhonebookEntryId(internalnumber)
    local phonebookTable = content_helper.convertResultToObject(phonepath .. "@", proxy.get(phonepath))
    local id
    for _, v in pairs(phonebookTable) do
        if v["HomeNumber"] == internalnumber then
            id = v["paramindex"]
            break
        end
    end
    return id
end

local function updatePhonebookEntry(clientid, name, internalnumber)
    local id = getPhonebookEntryId(internalnumber)
    if id and internalnumber then
        local content_set = {}
        content_set[phonepath .. "@" .. id .. ".FirstName"] = name
        content_set[phonepath .. "@" .. id .. ".HomeNumber"] = internalnumber
        proxy.set(content_set)
    end
end

local function addPhonebookEntry(clientid, name, internalnumber)
    -- add internalnumber in address book
    if internalnumber then
        local id = proxy.add(phonepath)
        local content_set = {}
        if id and internalnumber then
            content_set[phonepath .. "@" .. id .. ".FirstName"] = name
            content_set[phonepath .. "@" .. id .. ".HomeNumber"] = internalnumber
            proxy.set(content_set)
        end
    end
end

local function delPhonebookEntry(internalnumber)
    local id = getPhonebookEntryId(internalnumber)
    if id then
        proxy.del(phonepath .. "@" .. id .. ".")
    end
end

if action == "SetConfig" and clientid and clientid ~= "" and name and name ~= "" then
    local sipdevs_data = content_helper.convertResultToObject(sipdev_path .. "@.", proxy.get(sipdev_path))
    local rpc_sipdevs_data = content_helper.convertResultToObject(rpc_sipdev_path .. "@.", proxy.get(rpc_sipdev_path))
    local res = {}
    -- check if already auto provisoned
    local isfound = false
    for _, v in pairs(sipdevs_data) do
        --get old SIP provisioning data if the clientid has been assigned a number before
        if string.format("%s",v["clientmac"]) == clientid then
            res = getSipProvisionData(v)
            if res["clientname"] ~= name then
                proxy.set(sipdev_path .. "@" .. v["paramindex"] .. ".clientname", name)
                --update address book if name changed
                if res["internalnumber"] then
                    updatePhonebookEntry(clientid, name, res["internalnumber"])
                end
            end
            isfound = true
            break
        end
    end
    -- get new SIP provisioning data which is not assigned yet
    if not isfound then
        for _, v in pairs(sipdevs_data) do
            if v["clientmac"] == "" then
                res = getSipProvisionData(v)
                local basepath = sipdev_path .. "@" .. v["paramindex"]
                local password = res["password"]
                res["password"] = generate_password()
                local content_set = {
                    [basepath .. ".defaultpassword"] = password,
                    [basepath .. ".password"] = res["password"],
                    [basepath .. ".clientmac"] = clientid,
                    [basepath .. ".clientname"] = name,
                }
                local ok = proxy.set(content_set)
                if not ok then
                    ngx.exit(556)
                else
                    if res["internalnumber"] then
                        addPhonebookEntry(clientid, name, res["internalnumber"])
                    end
                    ok = proxy.set("rpc.mmpbx.rvsipdevreload.reload", "")
                    if not ok then
                        ngx.exit(556)
                    end
                end
                break
            end
        end
    end

    -- check if SIP provisioning data available
    if not res["URI"] then
        ngx.exit(556)
    end

    res = { SIP = res }
    printJsonData(res)
elseif action == "QueryConfig" then
    local sipdevs_data =  content_helper.convertResultToObject(sipdev_path .. "@.", proxy.get(sipdev_path))
    local internalmap_data = getIntNumData()
    local res = getConfigListData(sipdevs_data,internalmap_data)
    printJsonData(res)
elseif action == "ReleaseConfig" and clientid and clientid ~= "" then
    local sipdevs_data =  content_helper.convertResultToObject(sipdev_path .. "@.", proxy.get(sipdev_path))
    local internalmap_data = getIntNumData()
    for _, v in pairs(sipdevs_data) do
        if string.format("%s",v["clientmac"]) == clientid then
            local basepath = sipdev_path .. "@" .. v["paramindex"]
            local content_set = {
                [basepath .. ".defaultpassword"] = "",
                [basepath .. ".password"] = v["defaultpassword"],
                [basepath .. ".clientmac"] = "",
                [basepath .. ".clientname"] = "",
            }
            local ok = proxy.set(content_set)
            if not ok then
                ngx.exit(556)
            else
                local number = getIntNum(internalmap_data, v)
                delPhonebookEntry(number)
                ok = proxy.set("rpc.mmpbx.rvsipdevreload.reload", "")
                if not ok then
                    ngx.exit(556)
                end
            end
            break
        end
    end
    local res = getConfigListData(sipdevs_data,internalmap_data, clientid)
    printJsonData(res)
else
    ngx.exit(552)
end

%>
