
local require = require
local setmetatable = setmetatable
local exit = os.exit
local concat = table.concat

local uloop = require 'uloop'

local logger = require("tch.logger").new("execute")

local posix = require 'tch.posix'
local file = require 'tch.posix.file'

local ExternalOperation = {}
ExternalOperation.__index = ExternalOperation

function ExternalOperation:timeout(timeout)
  self.timeout_seconds = timeout
  return self
end

function ExternalOperation:onCompletion(on_complete, userdata)
  self.on_complete = on_complete
  self.userdata = userdata
  return self
end

local _sockets = {}

local function operation_for_socket(fd)
  return _sockets[fd]
end

local function close_socket(operation)
  local rd = operation.rd
  _sockets[rd:fd()] = nil
  operation.uloop_sk:delete()
  rd:close()
end

local function run_client_callback(operation, result)
  if operation.on_complete then
    operation.on_complete(result, operation.userdata)
  end
end

local function complete_external_operation(operation, result)
  -- this function can be called twice. once for normal completion and
  -- once when the timer expires. But we may only trigger the client once.
  if not operation.complete then
    close_socket(operation)
    run_client_callback(operation, result)
    operation.complete = true
  end
end

local function sk_read_cb(fd)
  local operation = operation_for_socket(fd)
  local rd = operation.rd
  while true do
    local new_data, errmsg = rd:read(1024)
    if new_data then
      if #new_data ~= 0 then
        -- store received data until done
        local data = operation.data
        data[#data + 1] = new_data
        logger:debug("received data %s", new_data)
      else
        local data = operation.data
        logger:debug("peer of %d closed connection, data entries: %d", fd, #data)
        complete_external_operation(
          operation,
          {data=concat(data)}
        )
        break
      end
    elseif errmsg == "WOULDBLOCK" then
      break
    elseif errmsg ~= "INTERRUPTED" then
      logger:error("recv() failed on %d: %s", fd, errmsg)
      complete_external_operation(
        operation,
        {error="internal error: recv() failed"}
      )
      break
    end
  end
end

local function add_to_uloop(self)
  local uloop_sk = uloop.fd_add(
                     self.rd:fd(),
                     sk_read_cb,
                     uloop.ULOOP_READ + uloop.ULOOP_EDGE_TRIGGER
                   )
  self.uloop_sk = uloop_sk
  self.data = {}
  _sockets[self.rd:fd()] = self
end

local function operation_timed_out(self)
  complete_external_operation(self, {error="timeout expired"})
end

local function add_timeout(self)
  if self.timeout_seconds then
    local function on_timeout()
      operation_timed_out(self)
    end
    uloop.timer(on_timeout, self.timeout_seconds*1000)
  end
end

local function child_exec_command(operation, output, parameters)
  local nullfd = file.open("/dev/null", file.O_RDWR + file.O_CLOEXEC)
  posix.dup2(nullfd:fd(), 0)
  posix.dup2(output:fd(), 1)
  posix.dup2(nullfd:fd(), 2)
  local _, err = posix.execv(operation.command, parameters)
  logger:crititcal("Execv failed with error message: %s", err)
  exit()
end

function ExternalOperation:invoke(parameters)
  local rd, wr = file.pipe(file.O_CLOEXEC + file.O_NONBLOCK)
  local pid = posix.fork()
  if pid~=0 then
    self.pid = pid
    wr:close()
    self.rd = rd
    add_to_uloop(self)
    add_timeout(self)
  else
    child_exec_command(self, wr, parameters)
  end
  return self
end

local M = {}

function M.ExternalOperation(command)
  return setmetatable({
    command = command,
  }, ExternalOperation)
end

return M