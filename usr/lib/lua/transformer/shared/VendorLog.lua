local cfg = require("transformer.shared.ConfigCommon")
local proxy = require("datamodel")
local logger = require("transformer.logger")
local log = logger.new("VendorLogUpload")

-- Parameter list for main:
-- [1]: Config index to be exported
-- [2]: Location the exported file will be saved
-- [3]: Filename the exported file
local function main(...)
  local args = {...}
  if #args < 3 then
    log:error("Please enter the appropriate parameters!")
    print(1)
    return
  end

  local index, location, filename = unpack(args)
  -- Get instance name from index
  local result = proxy.get(string.format("InternetGatewayDevice.DeviceInfo.VendorLogFile.%s.Name", index))
  if not result then
      log:error("Invalid index number!")
      print(2)
      return
  end
  local name = string.format("%s", result[1].value)
  if name == "logread" then
      os.execute("logread > " .. location .. filename)
  else
      os.execute("cp " .. name .. " " .. location .. filename)
  end
  print(0)
end

os.exit(main(...) or 0)
