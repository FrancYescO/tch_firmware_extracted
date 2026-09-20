#! /usr/bin/lua
local lfs = require("lfs")
local datadir  = "/root/trafficmon/"

local binit = false

if arg[1] == "-i" then
    binit = true
end

local function DataCollector(datadir, binit)
    local format, match = string.format, string.match
    local dirname  = "/sys/class/net/"
    local tailname = "/statistics/"
    local checkdataname = datadir .. "check_data"
    local checkdata = {}

    local i, j, data = 0, 0, {}
    local f, fname = nil, ""

    local idx = 0
    --  the check_data file includes latest check data of 2 mins
    --  line 1: the index of check data (0-4)
    --     note: traffic data of 10 mins in traffic files is updated when index is 0
    --  from line 2, format of check data is dev|data_type|carry|number
    if not binit then
        f = io.open(checkdataname, "r")
        if f then
            local pattern = "([^|]*)|([^|]*)|(%d+)|(%d+)"
            i = 0
            for line in f:lines() do
                i = i + 1
                if i > 1 then
                    local name, dtype, carry, number = match(line, pattern)
                    if name then
                        checkdata[name] = checkdata[name] or {}
                        checkdata[name][dtype] = {
                            carry = tonumber(carry),
                            number = number
                        }
                    end
                else
                    idx = tonumber(line)
                end
            end
            f:close()
        end
    end

    local needupdate = false
    idx = idx + 1
    if idx >= 5 then
        idx = 0
        needupdate = true
    end
    -- the file will recode 145 line data
    --  line 1: the last moment total traffic data
    --  line 2~145: 144 times data, every 10mins during 24hours.
    local datanum  = 145
    local types = {"tx_bytes", "rx_bytes"};

    local ntotal, ntraffic = 0, 0

    for name in lfs.dir(dirname) do
        checkdata[name] = checkdata[name] or {}
        if name ~= "." and name ~= ".." then
            for _,dtype in ipairs(types) do
                fname = dirname .. name .. tailname .. dtype
                f = io.open(fname, "r")
                if f then
                    ntotal = f:read("*line")
                    f:close()
                end

                fname = datadir .. name .. "_" .. dtype
                if binit or (needupdate and lfs.attributes(fname, "mode") ~= "file") then
                    checkdata[name][dtype] = { carry = 0, number = ntotal }
                    f = io.open(fname, "w")
                    if f then
                        f:write(ntotal .. "\n" .. ntotal .. "\n")
                        f:close()
                    end
                else
                    if not checkdata[name][dtype] then
                        if needupdate then
                            checkdata[name][dtype] = { carry = 0, number = ntotal }
                        end
                    else
                        local tdata = checkdata[name][dtype]
                        if tonumber(ntotal) < tonumber(tdata["number"]) and tonumber(ntotal) > 0 then
                            tdata["carry"] = tdata["carry"] + 1
                        end
                        tdata["number"] = ntotal
                    end
                    if needupdate then
                        f = io.open(fname, "r")
                        if f then
                            i, data = 0, {}
                            for line in f:lines() do
                                i = i + 1
                                data[i] = tonumber(line)
                            end
                            f:close()
                            local carry = checkdata[name] and checkdata[name][dtype] and checkdata[name][dtype]["carry"] or 0
                            local ctotal = tonumber(ntotal) + carry*4294967296
                            ntraffic = ctotal - data[1]
                            f = io.open(fname, "w")
                            if f then
                                f:write(string.format("%.0f\n", ctotal))
                                if (i == datanum) then
                                    j = 2
                                else
                                    j = 1
                                end
                                for i,v in ipairs(data) do
                                    if i > j then
                                        f:write(v .. "\n")
                                    end
                                end
                                f:write(ntraffic .. "\n")
                                f:close()
                            end
                        end
                    end
                end
            end
        end
    end
    f = io.open(checkdataname, "w")
    if f then
        f:write(idx .. "\n")
        local pattern = "%s|%s|%.0f|%s\n"
        for name,v in pairs(checkdata) do
            for dtype, check in pairs(v) do
                local data = format(pattern, name, dtype, check.carry, check.number)
                f:write(data)
            end
        end
        f:close()
    end
end

-- lock file directory
local lock = lfs.lock_dir(datadir)
if lock then
    pcall(DataCollector, datadir, binit)
    -- unlock file directory
    lock:free()
end
