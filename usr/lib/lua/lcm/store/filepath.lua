
local require = require
local concat = table.concat

local lfs = require 'lfs'

local M = {}

local pathsep = "/"
if package.config then
  pathsep = package.config:sub(1, 1)
end

function M.pathsep()
  return pathsep
end

function M.split(dirname, separator)
  separator = separator or pathsep
  local path = {}

  local sep = dirname:find(separator, 0, true)
  if sep==1 then
    -- absolute path
    path[1] = ""
  else
    -- relative path
    path[1] = "."
    sep = 0
  end

  while sep do
    sep = sep+1
    local next_sep = dirname:find(separator, sep, true)
    local step = dirname:sub(sep, next_sep and next_sep-1)
    if step == "." then
      -- do nothing
    elseif step == ".." then
      -- go up
      if #path>1 then
        path[#path] = nil
      end
    elseif step ~= "" then
      path[#path+1] = step
    end
    sep = next_sep
  end

  return path
end

function M.join(path, separator)
  return concat(path, separator or pathsep)
end

function M.mkdir(path)
  local partial = path[1]
  for i=2,#path do
    partial = partial.."/"..path[i]
    local mode = lfs.attributes(partial, "mode")
    if mode then
      if mode~="directory" then
        return nil, "non directory detected: "..partial
      end
      -- otherwise the partial path exists and is a directory
      -- nothing to do
    else
      -- the partial path does not exist, create it
      local ok, err = lfs.mkdir(partial)
      if not ok then
        return nil, "failed to create "..partial.." ("..err..")"
      end
    end
  end
  return true
end

return M