#!/usr/bin/env lua
local logger = require("tch.logger")
local posix = require("tch.posix")
local file = require("tch.posix.file")
local json = require ("dkjson")
logger.init("ee_action", 6, posix.LOG_PID + posix.LOG_CONS, posix.LOG_USER)
local log = logger.new("ee_action", 6)

file.fcntl(0, file.F_SETFD, file.FD_CLOEXEC)
file.fcntl(1, file.F_SETFD, file.FD_CLOEXEC)
file.fcntl(2, file.F_SETFD, file.FD_CLOEXEC)

local known_actions = {
  starting = "start",
  stopping = "stop",
  downloading = "inspect",
  installing = "install",
  uninstalling = "uninstall",
}

local function io_write(msg)
  io.write(msg)
  io.flush()
  io.close()
end

local function process(encoded_package)
  if not encoded_package or encoded_package == "lcm.ee_action" then
    logger:error("We need the package encoded in JSON format")
    error("We need the package encoded in JSON format")
  end
  local decoded_package = json.decode(encoded_package)
  local action = decoded_package.state
  local package_ID = decoded_package.ID
  local ee_name = decoded_package.execenv
  log:debug("%s triggered on package %s from EE %s", action, package_ID, ee_name)
  if action == "downloading" then
    -- Common for all EE's, handle here
    local f, errmsg = io.open(decoded_package.downloadfile, "w")
    if not f then
      return nil, errmsg
    end
    logger:debug("downloadfile: %s", decoded_package.downloadfile)
    local success = false
    if decoded_package.URL and decoded_package.URL:match("^file://") then
      -- We currently (03/2018) do not build curl with file protocol support. Catch it here.
      f:close()
      local origin = decoded_package.URL:match("^file://(.*)")
      origin = origin:gsub("%.%.", "") -- Let's not allow redirections
      local fd_in
      fd_in, errmsg = io.open(origin, "r")
      if fd_in then
        fd_in:close()
        local tch_process = require("tch.process")
        tch_process.execute("cp", {origin, decoded_package.downloadfile})
        success = true
      end
    else
      local lcurl = require("lcurl.safe")
      local curl = lcurl.easy()

      -- initialize curl
      -- curl:setopt(lcurl.OPT_VERBOSE, true) -- run curl in verbose mode
      curl:setopt(lcurl.OPT_CAPATH, "/etc/ssl/certs")
      curl:setopt(lcurl.OPT_SSL_VERIFYPEER, 1)
      curl:setopt(lcurl.OPT_SSL_VERIFYHOST, 2)
      curl:setopt(lcurl.OPT_WRITEFUNCTION, f)
      curl:setopt(lcurl.OPT_URL, decoded_package.URL)
      curl:setopt(lcurl.OPT_FAILONERROR, 1)

      if decoded_package.username and decoded_package.password then
        curl:setopt(lcurl.OPT_HTTPAUTH, lcurl.AUTH_ANY)
        curl:setopt(lcurl.OPT_PASSWORD, decoded_package.password)
        curl:setopt(lcurl.OPT_USERNAME, decoded_package.username)
      end

      logger:notice("starting download of %s:%s", decoded_package.execenv, decoded_package.URL)

      local err
      success, err = curl:perform()
      logger:debug("success: %s, errmsg: %s", success and "true" or "false", tostring(err))

      if not success then
        if err:no() == 22 then
          -- lookup the http error code
          errmsg = string.format("Download failed with HTTP errorcode %s", curl:getinfo_response_code())
        else
          errmsg = string.format("%s (%s) ErrorCode:%d",
                                 err:name(),
                                 err:msg() == "Error" and "N/A" or err:msg(),
                                 err:no()
                   )
        end
      end

      -- cleanup
      curl:close()
      f:close()
    end
    if not success then
      io_write(errmsg)
      return
    end
  end
  local ee_loader = require("lcm.execenv.ee_loader")
  if not ee_loader then
    error("Can't find the Execution Environment loader")
  end
  local ee = ee_loader.load_ee(ee_name)
  if not ee then
    error("Can't find given Execution Environment")
  end
  if not ee[known_actions[action]] then
    error("Illegal action for given Execution Environment.")
  end
  local return_value, errcode, errmsg = ee[known_actions[action]](ee, decoded_package)
  if type(return_value) == "table" then
    local encoded_return_value = json.encode(return_value)
    io_write(encoded_return_value)
    return
  end
  if not errcode or not errmsg then
    io_write("")
    return
  end
  if errcode and errmsg then
    errmsg = tostring(errcode)..": "..errmsg
  else
    errmsg = errcode
  end
  io_write(errmsg)
end

process(...)
