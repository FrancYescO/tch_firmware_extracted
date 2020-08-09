local popen = io.popen

local M = {}

M.execute_cmd = function(full_cmd)
  local f = popen(full_cmd)
  local res = {}
  for line in f:lines() do
    res[#res + 1] = line
  end
  f:close()
  return res
end

return M