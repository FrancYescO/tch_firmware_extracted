local proxy = require("datamodel")
local format, tonumber = string.format, tonumber
local open, stderr = io.open, io.stderr
local execute = os.execute

local function errmsg(fmt, ...)
    local msg = format(fmt, ...)
    stderr:write('*error: ', msg, '\n')
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

  local index, location, filename = unpack(args)
  -- Get instance name from index
  local name
  local rotate
  if tonumber(index) < 1 then
    name = "logread"
  else
    local result = proxy.get("uci.cwmpd.cwmpd_config.datamodel")
    local datamodel = result and result[1].value
    if datamodel ~= "Device" then
      datamodel = "InternetGatewayDevice"
    end
    local result = proxy.get(format("%s.DeviceInfo.VendorLogFile.%s.Name", datamodel, index),
      format("%s.DeviceInfo.VendorLogFile.%s.X_000E50_Rotate", datamodel, index))
    if result then
      name = result[1].value
      rotate = result[2].value
      rotate = tonumber(rotate)
    end
  end
  if not name then
    errmsg("Invalid index number!")
    return 1
  end
  if name == "logread" then
    execute("logread > " .. location .. filename)
  else
    local f = open(name, "r")
    if not f then
      errmsg("Invalid log file name!")
      return 1
    end
    f:close()
  if(rotate >= 1) then
    execute("cat `ls -r " .. name .."*` > " .. location .. filename)
  else
    execute("cp " .. name .. " " .. location .. filename)
 end
  end
  return 0
end

os.exit(main(...) or 0)
