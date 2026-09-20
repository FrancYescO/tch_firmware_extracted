--*** Worker_dnsqueries Thread ***
--Worker Thread to calculate query values for all wan dns servers
--Output of dig servers.bind command will be taken for calculations
--All calculated dns query values  will be stored
--/tmp/dnsqueries/ directory will be created
--Files will be created and values will be stored in respective dns servers

local M = {}
local timer

M.SenseEventSet = {
    ['start'] = true,
    ['query_update'] = true,
    ['network_interface_wan_ifup'] = true,
    ['network_interface_wan_ifdown'] = true,
    ['network_interface_wwan_ifup'] = true,
    ['network_interface_wwan_ifdown'] = true,
}

--Funtion which actually updates dnsqueries in respective path
--First line of file will have final result for each hour
--From second line it will accumulate results of each 5mins
--Success, Errors, Timeout, average is caluclated
--Max line count will be 14 - 1st line , next 13 lines to hold last one hour values
local function actionUpdate(path, val, action)
  local fileContent = {}
  local count = 0
  local f = io.open(path, "r")
  if f then
    for lines in f:lines() do
      table.insert (fileContent, lines)
      count = count + 1
    end
    f:close()
  end
  if count == 14 then
    if action == "update" then
      if tonumber(val) >= tonumber(fileContent[2]) then
         fileContent[1] = tonumber(val) - tonumber(fileContent[2])
      else
        os.execute("rm -rf /tmp/dnsqueries/")
        return
      end
    elseif action == "calculateAvg" then
      local currTotalQuery, currAvg = string.match(val, "^([^|]*)|(.*)")
      local oldTotalQuery, oldAvg = string.match(fileContent[2], "^([^|]*)|(.*)")
      local diffTotalQuery = tonumber(currTotalQuery) - tonumber(oldTotalQuery)
      local newTotalAvg = (tonumber(currTotalQuery) * tonumber(currAvg)) - (tonumber(oldTotalQuery) * tonumber(oldAvg))
      local newAvg = 0
      if diffTotalQuery ~= 0 and newTotalAvg ~= 0 then
         newAvg = newTotalAvg / diffTotalQuery
      end
      local newVal = currTotalQuery .. "|" .. newAvg
      fileContent[1] = newVal
    end
    fileContent[ #fileContent + 1 ] = val
    f = io.open(path, 'w')
    for index, value in ipairs(fileContent) do
      if index ~= 2 then
        f:write(value..'\n')
      end
    end
    f:close()
  elseif count < 14 then
    fileContent[1] = val
    fileContent[ #fileContent + 1 ] = val
    f = io.open(path, 'w')
    if f then
      for index, value in ipairs(fileContent) do
        f:write(value..'\n')
      end
      f:close()
    end
  end
end

--Function to update the values in respective paths
--Path creation is done here and values are passed to actionUpdate()
local function update(dns)
  local dnsServ, totalQuery, success, fail, timeOut, avg , total  = 0, 0, 0, 0, 0, 0, 0
  dnsServ, totalQuery, success, fail, timeOut, avg = dns[1], dns[2], dns[3], dns[4], dns[5], dns[6]
  dnsServ = string.gsub(dnsServ, "([#]%d+)", "")
  path = "/tmp/dnsqueries/" .. dnsServ
  total = success + fail
  average = total .. "|" .. avg

  local spath = path ..  "_success"
  local fpath = path .. "_fail"
  local tpath = path .. "_timeout"
  local apath = path .. "_average"

  actionUpdate(spath, success, "update")
  actionUpdate(fpath, fail, "update")
  actionUpdate(tpath, timeOut, "update")
  actionUpdate(apath, average, "calculateAvg")
end

--Function ot Obtain each dns server query results
--Pass through values for each dns to update() function
local function getUpdate()
  local output
  local dnsEntries = {}
  local process = require("tch.process")
  local fp = process.popen("dig", {"+short", "-t", "TXT", "-c", "chaos", "servers.bind"})
  if fp then
    output = fp:read()
    fp:close()
  end
  if output then
    for entry in string.gmatch(output, '([^""]+)') do
      if string.match(entry, "#")then
        dnsEntries[ #dnsEntries + 1 ] = entry
      end
    end
  end
  if next(dnsEntries) then
    for k,v in pairs(dnsEntries) do
      if v then
        local dns = {}
        for word in string.gmatch(v, '([^ ]+)') do
          dns[ #dns + 1 ] = word
        end
        update(dns)
      end
    end
  end
end

function M.check(runtime, event)
  local scripthelpers = runtime.scripth
  local lfs = require("lfs")
  local datadir  = "/tmp/dnsqueries/"

  local lpfd = io.open(datadir)
  if not lpfd then
    if not lfs.mkdir(datadir) then
      return nil, "create ".. datadir.." failed"
    end
  else
    lpfd:close()
  end

  if event == "start" then
    if scripthelpers.checkIfInterfaceIsUp("wan") then
       M.check(runtime, "network_interface_wan_ifup")
    elseif scripthelpers.checkIfInterfaceIsUp("wwan") then
       M.check(runtime, "network_interface_wwan_ifup")
    end
  elseif event == "network_interface_wan_ifup" or event == "network_interface_wwan_ifup" then
    os.execute("rm -f " .. datadir .. "*") --Flush all QueryBackups when wan up detected
    getUpdate()
    if not timer then
      --Call timer for 5 mins
      timer = scripthelpers.fire_timed_event("query_update", 300, 1)
    end
  elseif event == "network_interface_wan_ifdown" or event == "network_interface_wwan_ifdown" then
    os.execute("rm -f " .. datadir .. "*") -- Flush all QueryBackups when wan down detected
  elseif event == "query_update" then
    getUpdate()
    --Call timer for 5 mins
    timer = scripthelpers.fire_timed_event("query_update", 300, 1)
  end
end

return M
