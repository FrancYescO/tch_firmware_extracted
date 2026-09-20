--*** Worker_throughput Thread ***
--Worker Thread to calculate Throughtput values for all interfaces
--All calculated throught put values will be compared and peak values will be stored
--/tmp/throughtput/ directory will be created
--Files will be created and values will be stored in respective

local M = {}
local timer

M.SenseEventSet = {
    ['start'] = true,
    ['throughput_calculate'] = true,
    ['reset_throughput'] = true,
}

--Function to read the path and return the values
local function readfile(path)
  local val = 0
  f = io.open(path, "r")
  if f then
    val = f:read()
    f:close()
  end
  return val
end

--Function to write the values in respected path
local function writefile(path,val)
  f = io.open(path, "w")
  if f then
    f:write(val)
    f:close()
  end
end

--Function to reset peak values every 15mins
local function  reset_throughput(datadir,dirpath,tail_upath,tail_dpath,intfs)
  for _,intf in ipairs(intfs) do

    local peak_upload_path = datadir .. intf .. "_peak_upload"
    local peak_download_path = datadir .. intf .. "_peak_download"
    local old_upload_path = datadir .. intf .. "_oldtotal_upload"
    local old_download_path = datadir .. intf .. "_oldtotal_download"
    local fu_name = dirpath .. intf .. tail_upath
    local fd_name =  dirpath .. intf .. tail_dpath
    local resetval = 0

    curr_tot_upload = readfile(fu_name)
    curr_tot_download = readfile(fd_name)

    writefile(old_upload_path,curr_tot_upload)
    writefile(old_download_path,curr_tot_download)
    writefile(peak_upload_path,resetval)
    writefile(peak_download_path,resetval)
  end
end

--Function to calculate peak load values
--To update if the peak values reaches for every 5 seconds
local function throughput_update(datadir,dirpath,tail_upath,tail_dpath,intfs)
  for _,intf in ipairs(intfs) do

    local peak_upload_path = datadir .. intf .. "_peak_upload"
    local peak_download_path = datadir .. intf .. "_peak_download"
    local old_upload_path = datadir .. intf .. "_oldtotal_upload"
    local old_download_path = datadir .. intf .. "_oldtotal_download"
    local fu_name = dirpath .. intf .. tail_upath
    local fd_name =  dirpath .. intf .. tail_dpath

    curr_tot_upload = readfile(fu_name)
    curr_tot_download = readfile(fd_name)
    old_total_upload = readfile(old_upload_path)
    old_peak_upload = readfile(peak_upload_path)
    old_total_download = readfile(old_download_path)
    old_peak_download = readfile(peak_download_path)

    new_peak_upload = tonumber(curr_tot_upload) - tonumber(old_total_upload)
    if new_peak_upload >= tonumber(old_peak_upload) then
      writefile(peak_upload_path,new_peak_upload)
    end

    new_peak_download = tonumber(curr_tot_download) - tonumber(old_total_download)
    if new_peak_download >= tonumber(old_peak_download) then
      writefile(peak_download_path,new_peak_download)
    end

    writefile(old_upload_path,curr_tot_upload)
    writefile(old_download_path,curr_tot_download)
  end
end

function M.check(runtime, event)
  local scripthelpers = runtime.scripth
  local lfs = require("lfs")
  local datadir  = "/tmp/throughput/"

  local lpfd = io.open(datadir)
  if not lpfd then
    if not lfs.mkdir(datadir) then
      return nil,nil, "create ".. datadir.." failed"
    end
  else
    lpfd:close()
  end
  local dirpath = "/sys/class/net/"
  local tail_upath = "/statistics/tx_bytes"
  local tail_dpath = "/statistics/rx_bytes"
  local intfs = { "br-lan" , "dsl0" , "eth4" , "wwan0" , "wl0_1" , "wl1_1", "atm_8_35", "ptm0" }

  if event == "start" then
    if not timer then
      timer = scripthelpers.fire_timed_event("reset_throughput", 1, 1)
    end
    timer = scripthelpers.fire_timed_event("throughput_calculate", 5, 1)
  elseif event == "throughput_calculate" then
    throughput_update(datadir,dirpath,tail_upath,tail_dpath,intfs)
    --Call timer for 5 sec
    timer = scripthelpers.fire_timed_event("throughput_calculate", 5, 1)
  elseif event == "reset_throughput" then
    reset_throughput(datadir,dirpath,tail_upath,tail_dpath,intfs)
    --Call timer for 15mins
    timer = scripthelpers.fire_timed_event("reset_throughput", 900, 1)
  end
end

return M
