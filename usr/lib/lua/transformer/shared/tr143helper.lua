local M = {}
local open = io.open
local match = string.match
local pairs = pairs

local uci = require 'transformer.mapper.ucihelper'
local common = require 'transformer.mapper.nwcommon'
local split_key = common.split_key
local findLanWanInterfaces = common.findLanWanInterfaces
local wanconn = require 'transformer.shared.wanconnection'
local resolve, tokey
local ubusConnection = require("ubus").connect()

local tr143_results = { downloaddiag = {}, uploaddiag= {} }
local clearusers={ downloaddiag = {}, uploaddiag= {}}
local transactions = { downloaddiag = {}, uploaddiag= {}}
local uci_binding={ downloaddiag = {}, uploaddiag= {}}
local section_binding = {}

local url_type = {
    downloaddiag = "DownloadURL",
    uploaddiag = "UploadURL"
}

local paramValue = {
    DownloadTransports = "HTTP,FTP",
    DownloadDiagnosticMaxConnections = "1",
    DownloadDiagnosticsMaxIncrementalResult = "1",
    UploadTransports = "HTTP,FTP"
}

function M.clear_tr143_results(config, user)
    os.remove("/tmp/tr143/" .. config .. "_" .. user .. ".out")
    tr143_results[config][user] = nil
end

local function read_tr143_outfile(config, user)
    local my_data
    local fd = open("/tmp/tr143/" .. config .. "_" .. user .. ".out", "r")
    if fd then
        for line in fd:lines() do
            --line format: key = value such as SourceIPAddress = 10.11.58.95
            local key, value = match (line, "^(%w+)\s*=\s*(.+)\s*$")
            if key then
                my_data = my_data or {}
                my_data[key] = value
            end
        end
        fd:close()
        if my_data then
            tr143_results[config][user] = my_data
            return my_data
        end
    end
end

function M.read_tr143_results(config, user, name)
    if name then
        local results = tr143_results[config][user]
        if results then
            return results[name]
        end
        local my_data = read_tr143_outfile(config, user)
        return my_data and my_data[name]
    else
        local results = tr143_results[config][user]
        if results then
            return results
        end
        local my_data = read_tr143_outfile(config, user)
        return my_data
    end
end

function M.startup(config, user, binding, _resolve, _tokey)
    resolve, tokey = _resolve, _tokey
    uci_binding[config][user] = binding
    -- check if /etc/config/downloaddiag(or uploaddiag) exists, if not create it
    local config_file = "/etc/config/" .. config
    local f = open(config_file)
    if not f then
        f = open(config_file, "w")
        if not f then
            error("could not create " .. config_file)
        end
        f:write("config user '".. user .."'\n")
        f:close()
        uci.set_on_uci(binding["DSCP"], 0)
        uci.set_on_uci(binding["EthernetPriority"], 0)
    else
        local diag_binding = {config = config, sectionname = user}
        local value = uci.get_from_uci(diag_binding)
        if value == '' then
            uci.set_on_uci(diag_binding, "user")
            uci.set_on_uci(binding["DSCP"], 0)
            uci.set_on_uci(binding["EthernetPriority"], 0)
        end
    end
    uci.set_on_uci(binding["DiagnosticsState"], "None")
    uci.commit({config = config})
    return user
end

local function resolveInterface(user, value)
    local path
    local lanInterfaces = findLanWanInterfaces(false)
    local isLan = false
    for _,j in pairs(lanInterfaces) do
        if (value == j) then
            isLan = true
            break
        end
    end

    if user == "device2" then
        path = resolve("Device.IP.Interface.{i}.", value)
    else
        if (isLan) then
            path = resolve('InternetGatewayDevice.LANDevice.{i}.LANHostConfigManagement.IPInterface.{i}.', value)
        else
            local key, status = wanconn.get_connection_key(value)
            if key and status then
                if status.proto == "pppoe" or status.proto == "pppoa" then
                    path = resolve("InternetGatewayDevice.WANDevice.{i}.WANConnectionDevice.{i}.WANPPPConnection.{i}.", key)
                else
                    path = resolve("InternetGatewayDevice.WANDevice.{i}.WANConnectionDevice.{i}.WANIPConnection.{i}.", key)
                end
            end
        end
    end
    return path or ""
end

local function getIPAddress(interface)
    local ipaddress = ubusConnection:call("network.interface." .. interface,"status",{})
    if ipaddress and ipaddress['ipv4-address'] and ipaddress['ipv4-address'][1] then
        return ipaddress['ipv4-address'][1]['address'] or ""
    end
    return ""
end

function M.tr143_get(config, user, pname)
    local value
    if paramValue[pname] then
        return paramValue[pname]
    end
    if uci_binding[config][user] == nil then
        uci_binding[config][user] = {
            ["DiagnosticsState"] = { config = config, sectionname = user, option = "state" },
            [url_type[config]] = { config = config, sectionname = user, option = "url" },
            ["Interface"] = { config = config, sectionname = user, option = "interface" },
            ["DSCP"] = { config = config, sectionname = user, option = "dscp" },
            ["EthernetPriority"] = { config = config, sectionname = user, option = "pbit" },
        }
        if config == "uploaddiag" then
            uci_binding[config][user]["TestFileLength"] = { config = config, sectionname = user, option = "filesize" }
        end
    end
    if pname == "IPAddressUsed" then
        value = uci_binding[config][user]["Interface"]
        value = uci.get_from_uci(value)
        return value ~= "" and getIPAddress(value) or ""
    end
    local param_binding = uci_binding[config][user][pname]
    if param_binding then
        value = uci.get_from_uci(param_binding)
        if pname == "Interface" then
            value = resolveInterface(user, value)
        -- Internally, we need to distinguish between Requested and InProgress; IGD does not
        elseif pname == "DiagnosticsState" and value == "InProgress" then
            value = "Requested"
        end
    else
        value = M.read_tr143_results(config, user, pname)
    end
    return value or ""
end

function M.tr143_getall(config, user)
    local results = M.read_tr143_results(config, user)
    if not results then
        results = {
            EOMTime = "",
            ROMTime = "",
            BOMTime = "",
            TCPOpenRequestTime = "",
            TCPOpenResponseTime = "",
        }
        if config == "uploaddiag" then
            results.TestBytesSent = ""
            results.TotalBytesSent = ""
        else
            results.TestBytesReceived = ""
            results.TotalBytesReceived = ""
        end
    end
    if config == "uploaddiag" then
        results.UploadTransports = paramValue[UploadTransports]
    else
        results.DownloadTransports = paramValue[DownloadTransports]
        results.DownloadDiagnosticMaxConnections = paramValue[DownloadDiagnosticMaxConnections]
        results.DownloadDiagnosticsMaxIncrementalResult = paramValue[DownloadDiagnosticsMaxIncrementalResult]
    end
    section_binding.config = config
    section_binding.sectionname = user
    local uci_data = uci.getall_from_uci(section_binding)
    results[url_type[config]] = uci_data.url or ""
    results.Interface = uci_data.interface and resolveInterface(user, uci_data.interface) or ""
    results.DSCP = uci_data.dscp or ""
    results.EthernetPriority = uci_data.pbit or ""
    if uci_data.state == "InProgress" then
        results.DiagnosticsState = "Requested"
    else
        results.DiagnosticsState = uci_data.state or ""
    end
    if config == "uploaddiag" then
        results.TestFileLength = uci_data.filesize or ""
    end
    results.IPAddressUsed = (uci_data and uci_data.interface) and getIPAddress(uci_data.interface) or ""
    return results
end

local function transaction_set(binding, pvalue, commitapply)
    uci.set_on_uci(binding, pvalue, commitapply)
    transactions[binding.config][binding.config] = true
end

function M.tr143_set(config, user, pname, pvalue, commitapply)
    local bindings = uci_binding[config][user]
    if pname == "DiagnosticsState" then
        if (pvalue ~= "Requested" and pvalue ~= "None") then
            return nil, "invalid value"
        end
        clearusers[config][user] = true
        transaction_set(bindings["DiagnosticsState"], pvalue, commitapply)
    elseif pname == "TestFileLength" and tonumber(pvalue) and tonumber(pvalue) < 1 then
        return nil, "invalid value"
    else
        -- Interface is displayed in IGD as path, but stored as UCI/UBUS interface in UCI, so convert it first
        --allow empty value
        if pname == "Interface" and pvalue ~= "" then
            -- Convert path to key; this is always the UCI/UBUS interface name, like wan, lan, ...
          if user == "device2" then
            local rc
            rc, pvalue = pcall(tokey, pvalue, "Device.IP.Interface.{i}.")
            if not rc then
              return nil, "invalid value"
            end
          else
            local value = tokey(pvalue,
                "InternetGatewayDevice.LANDevice.{i}.LANHostConfigManagement.IPInterface.{i}.",
                "InternetGatewayDevice.WANDevice.{i}.WANConnectionDevice.{i}.WANIPConnection.{i}.",
                "InternetGatewayDevice.WANDevice.{i}.WANConnectionDevice.{i}.WANPPPConnection.{i}.")
            if value:match("|") then
                -- Interface name is the first part of the WANDevice.WANConnectionDevice.WANIP/WANPPP key
                pvalue = split_key(value)
            else
                pvalue = value
            end

            if (not pvalue) then
               return nil, "Invalid value"
            end
          end
        end
        local state = uci.get_from_uci(bindings["DiagnosticsState"])
        if (state ~= "Requested" and  state ~= "None") then
            transaction_set(bindings["DiagnosticsState"], "None", commitapply)
        end
        transaction_set(bindings[pname], pvalue, commitapply)
        return true
    end
end

function M.tr143_commit(config)
    for cl_user,_ in pairs(clearusers[config]) do
        M.clear_tr143_results(config, cl_user)
    end
    clearusers[config] = {}
    for cfg,_ in pairs(transactions[config]) do
        local binding = {config = cfg}
        uci.commit(binding)
    end
    transactions[config] = {}
end

function M.tr143_revert(config)
  clearusers[config]={}
  for cfg,_ in pairs(transactions[config]) do
    local binding = {config = cfg}
    uci.revert(binding)
  end
  transactions[config] = {}
end

return M
