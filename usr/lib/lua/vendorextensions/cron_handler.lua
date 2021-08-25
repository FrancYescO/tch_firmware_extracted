#!/usr/bin/env lua
local M = {}
local runtime = {}
local os = require("os")
local lfs = require("lfs")

function M.remove_cron_jobs()
  os.execute("crontab -c /etc/crontabs/ -l | grep -v 'DeploySoftwareNow' | crontab -c /etc/crontabs/ -")
end

function M.scheduleAgentSoftwareDeployment(randomTime)
  -- parse the hour, minute and seconds for scheduling cron job, and store it in local variables
  local hour, minute = randomTime:match("^(%d%d):(%d%d):%d%d$")

  if not hour then
    runtime.log:critical("Scheduling cron job for agent software upgrade failed")
    return
  end

  if lfs.attributes("/etc/crontabs/root", "mode") == "file" then
    -- Remove if any cron jobs related to firmware upgrade is present.
    os.execute("crontab -c /etc/crontabs/ -l | grep -v 'DeploySoftwareNow' | crontab -c /etc/crontabs/ -")

    -- Save the existing cron jobs if any to temp file /tmp/.agent_firmware_upgrade
    os.execute("crontab -c /etc/crontabs/ -l 2>/dev/null > /tmp/.agent_firmware_upgrade")
  end

  -- Now append the given multiap agent firmware upgrade job to the list of existing cron jobs
  local f = io.open("/tmp/.agent_firmware_upgrade", "a")
  if not f then
    error("could not append /tmp/.agent_firmware_upgrade")
  end
  f:write(string.format("%d %d * * * ubus call mapVendorExtensions.controller triggerAction \'{\"Action\":\"DeploySoftwareNow\"}\'\n", minute, hour))
  f:close()

  -- Set the cron job
  os.execute("crontab -c /etc/crontabs/ /tmp/.agent_firmware_upgrade")

  -- Remove temp file /tmp/reboot
  os.remove("/tmp/.agent_firmware_upgrade")
end

function M.checkTimeInterval(param, time)
  local cursor = require('uci').cursor()
  local startTime, endTime
  if param == "deployment_window_start" then
    startTime = time
    endTime = cursor:get("vendorextensions", "agent_software_deployment", "deployment_window_end")
  else
    startTime = cursor:get("vendorextensions", "agent_software_deployment", "deployment_window_start")
    endTime = time
  end
  local curDateTime = os.date("*t")
  local startHour, startMin, startSec = startTime:match("^(%d%d):(%d%d):(%d%d)$")
  local endHour, endMin, endSec = endTime:match("^(%d%d):(%d%d):(%d%d)$")
  local startDateTime = {year = curDateTime.year, month = curDateTime.month, day = curDateTime.day, hour = startHour, min = startMin, sec = startSec}
  local endDateTime = {year = curDateTime.year, month = curDateTime.month, day = curDateTime.day, hour = endHour, min = endMin, sec = endSec}
  local startTimeInEpoch = os.time(startDateTime)
  local endTimeInEpoch = os.time(endDateTime)
  return startTimeInEpoch, endTimeInEpoch, startTime
end

function M.generateAndSetRandomTime(param, time)
  local startTimeInEpoch, endTimeInEpoch, startTime = M.checkTimeInterval(param, time)
  local cursor = require('uci').cursor()
  -- If stopTime - startTime is less than 20 minutes, random time = start time
  if endTimeInEpoch - startTimeInEpoch < 1200 then
    cursor:set("vendorextensions", "agent_software_deployment", "deployment_window_random", startTime)
    cursor:commit("vendorextensions")
    M.scheduleAgentSoftwareDeployment(startTime)
    return
  end
  -- Generate a random time in interval: [startTime, stopTime - 20minutes]
  --math.randomseed(tostring(os.time()):reverse():sub(1, 6))
  math.randomseed(os.time())
  local randomTimeInEpoch = math.random(startTimeInEpoch, endTimeInEpoch - 1200)
  local randomDateTime = os.date("*t", randomTimeInEpoch)
  local randomTime = string.format("%02d:%02d:%02d", randomDateTime.hour, randomDateTime.min, randomDateTime.sec)
  cursor:set("vendorextensions", "agent_software_deployment", "deployment_window_random", randomTime)
  cursor:commit("vendorextensions")
  M.scheduleAgentSoftwareDeployment(randomTime)
end

function M.init(rt)
  runtime = rt
  local cursor = runtime.uci.cursor()
  -- get agent software deployment window start time
  local startTime = cursor:get("vendorextensions", "agent_software_deployment", "deployment_window_start") or ""
  cursor:close()
  M.generateAndSetRandomTime("deployment_window_start", startTime)
end

return M
