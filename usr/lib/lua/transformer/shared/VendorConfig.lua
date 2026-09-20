local cfg = require("transformer.shared.ConfigCommon")
local proxy = require("datamodel")
local lfs = require("lfs")
local format, tonumber = string.format, tonumber
local open, stderr = io.open, io.stderr
local execute = os.execute

local function errmsg(fmt, ...)
    local msg = format(fmt, ...)
    stderr:write('*error: ', msg, '\n')
    return {msg}
end

-- Parameter list for main:
-- [1]: Config index to be exported
-- [2]: Location the exported file will be saved
-- [3]: Filename the exported file
local function main(...)
  local args = {...}
  if #args < 3 then
    errmsg("Please enter the appropriate parameters!")
    return 1
  end

  local banktemplate = "/overlay/%s/etc/config"
  local index, location, filename = unpack(args)

  -- Get instance name from index
  local name
  if tonumber(index) < 1 then
    local fd = open("/proc/banktable/booted")
    if fd then
      name = fd:read("*line")
      fd:close()
    end
  else
    local bank = format("bank_%s", index)
    local mode = lfs.attributes("/overlay/" .. bank, "mode")
    if mode == "directory" then
      name = bank
    end
  end

  if not name then
    errmsg("Invalid index number!")
    return 1
  end

  local path = format(banktemplate, name)

  local export_mapdata = cfg.export_init(location)
  export_mapdata.filename = filename
  export_mapdata.state = "Requested"
  cfg.export_start(export_mapdata, path)

  local sleep_time = 1
  local max_time = 5
  local total_time = 0
  repeat
    execute("sleep " .. sleep_time)
    total_time = total_time + sleep_time
    if export_mapdata.state ~= "Requested" then
      break
    end
  until (total_time >= max_time)
  if export_mapdata.state ~= "Complete" then
    if export_mapdata.state == "Requested" then
      errmsg("Timeout when generating the config file")
      return 1
    else
      errmsg(format('Generate error (state="%s", info="%s")', export_mapdata.state, export_mapdata.info or ""))
      return 1
    end
  end
  return 0
end

os.exit(main(...) or 0)
