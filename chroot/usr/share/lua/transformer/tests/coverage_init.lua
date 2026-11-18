local match = string.match
local ipairs = ipairs

local filtered_out = {
  "%.map$",
  "/usr/lib/lua/transformer/shared/",
  "/tmp/"
}

local cache = {}

require("luacov").sethook(function(filename)
  if cache[filename] ~= nil then
    return cache[filename]
  end
  for _, pattern in ipairs(filtered_out) do
    if match(filename, pattern) then
      cache[filename] = false
      return false
    end
  end
  local lib = match(filename, "/usr/lib/lua/([^/]+)")
  if lib ~= "transformer" then
    cache[filename] = false
    return false
  end
  cache[filename] = true
  return true
end)
