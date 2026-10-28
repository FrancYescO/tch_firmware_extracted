local M = {
  TM_devtype = { ETH = 0, EPON = 1, GPON = 2, XTM = 3 },
  TM_dropalg = { DROPTAIL = 0, RED = 1, WRED = 2 },
  tmctl_path = "/usr/bin/tmctl",
  logging_enabled = false,
  tmctl_logging_enabled = false
}

--- Helper function to check if a file exists
-- @param name The file name
-- @return true if the file exist or false otherwise
function M.file_exists(name)
  local f = io.open(name,"r")
  if f ~= nil then io.close(f) return true else return false end
end

function M.error_printf(...) --luacheck: no unused args
  print("[tmhelper error] " .. string.format(unpack(arg)))
end

function M.dbg_printf(...) --luacheck: no unused args
  if not M.logging_enabled then return end
  print("[tmhelper debug] " .. string.format(unpack(arg)))
end

--- Helper function to trace execute the passed commands
-- @param str The command which needs to be executed
function M.exec_tmctl(...) --luacheck: no unused args
  local str = M.tmctl_path .. " " .. string.format(unpack(arg))
  if M.tmctl_logging_enabled then
    print(str)
  else
    str = str .. " > /dev/null 2>&1"
    M.dbg_printf(str)
  end
  os.execute(str)
end

--- Helper function to check if the tmctl utility exists
-- @return true if the tmctl exists or false otherwise
function M.tmctl_present()
  if not M.file_exists(M.tmctl_path) then
    M.error_printf("tmctl utility not present")
    return false
  end
  return true
end

function M.enable_logging(enable)
  M.logging_enabled = enable
end

function M.enable_tmctl_logging(enable)
  M.tmctl_logging_enabled = enable
end

return M
