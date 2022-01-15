local ipairs, tostring, type = ipairs, tostring, type
local lines = io.lines

local simple = 1
local folded = 2
local multi = 3
local ignore = 4

local control_fields = {
  ["Alternatives"] = simple, -- TODO double check in opkg source code
  ["Architecture"] = simple,
  ["Auto-Installed"] = simple,
  ["Conffiles"] = multi,
  ["Conflicts"] = folded,
  ["Depends"] = folded,
  ["Description"] = multi,
  ["Essential"] = simple,
  ["Filename"] = simple, -- Used in package index
  ["Installed-Size"] = simple,
  ["Installed-Time"] = simple,
  ["License"] = ignore,
  ["LicenseFiles"] = ignore,
  ["MD5sum"] = simple, -- Used in package index
  ["Maintainer"] = simple,
  ["Package"] = simple,
  ["Pre-Depends"] = folded,
  ["Priority"] = simple,
  ["Provides"] = folded,
  ["Recommends"] = folded,
  ["Replaces"] = folded,
  ["Require-User"] = ignore,
  ["Section"] = simple,
  ["SHA256sum"] = simple, -- Used in package index
  ["Size"] = simple, -- Used in package index
  ["Source"] = simple,
  ["Status"] = simple,
  ["Suggests"] = folded,
  ["Tags"] = simple,
  ["Version"] = simple,
}

local function parse_single_line(line, field, value)
  if not line:match("^%s") then
    -- Not a multi-line field
    field = line:match("^(%S+):")
    value = line:match("^%S+:%s*(.*)$")
    if not control_fields[field] then
      return nil, "Unknown field encountered: "..tostring(field)
    end
  else
    if control_fields[field] ~= folded and control_fields[field] ~= multi then
      return nil, "Illegal line encountered: "..tostring(line)
    else
      value = value .. line
    end
  end
  return field, value
end

local function parse_control(opkg_package, control_file_or_array)
  local iterator, state, initial
  if type(control_file_or_array) == "string" then
    iterator, state, initial = lines(control_file_or_array)
  else
    local real_iterator, it_next
    real_iterator, state, initial = ipairs(control_file_or_array)
    iterator = function(it_state, it_init)
      if it_next then
        it_init = it_next
      end
      local line
      it_next, line = real_iterator(it_state, it_init)
      return line
    end
  end
  local field, value
  for line in iterator, state, initial do
    field, value = parse_single_line(line, field, value)
    if not field then
      -- The error message is now in 'value'.
      return nil, value
    end
    opkg_package[field] = value
  end
  return opkg_package
end

local M = {}

M.new_package = function(control_file_or_array)
  local opkg_package = {}
  return parse_control(opkg_package, control_file_or_array)
end

M.update_package = function(opkg_package, control_file_or_array)
  return parse_control(opkg_package, control_file_or_array)
end

-- TODO add validation?
M.check_status = function(opkg_package, wanted_check, flag_check, status_check)
  local status = opkg_package.Status
  if not status then
    return false
  end
  local state_wanted, state_flag, state_status = status:match("^[^%s]+%s[^%s]+%s[^%s]+$")
  if wanted_check and state_wanted ~= wanted_check then
    return false
  end
  if flag_check and state_flag ~= flag_check then
    return false
  end
  if status_check and state_status ~= status_check then
    return false
  end
  return true
end

return M