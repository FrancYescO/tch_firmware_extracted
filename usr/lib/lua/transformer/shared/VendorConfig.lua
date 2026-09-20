local cfg = require("transformer.shared.ConfigCommon")
local proxy = require("datamodel")
local logger = require("transformer.logger")
local log = logger.new("VendorConfigUpload")

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

  local banktemplate = "/overlay/%s/etc/config"
  local index, location, filename = unpack(args)

  -- Get instance name from index
  local result = proxy.get(string.format("InternetGatewayDevice.DeviceInfo.VendorConfigFile.%s.Name", index))
  if not result then
      log:error("Invalid index number!")
      print(2)
      return
  end
  local path = string.format(banktemplate, result[1].value)

  local export_mapdata = cfg.export_init(location)
  export_mapdata.filename = filename
  export_mapdata.state = "Requested"
  cfg.export_start(export_mapdata, path)

  local sleep_time = 1
  local max_time = 5
  local total_time = 0
  repeat
    os.execute("sleep " .. sleep_time)
    total_time = total_time + sleep_time
    if export_mapdata.state ~= "Requested" then
      break
    end
  until (total_time >= max_time)
  if export_mapdata.state ~= "Complete" then
    if export_mapdata.state == "Requested" then
      log:error("Timeout when generating the config file")
      print(3)
    else
      log:error(string.format('Generate error (state="%s", info="%s")',
        export_mapdata.state, export_mapdata.info or ""))
      print(4)
    end
  else
    print(0)
  end
end

os.exit(main(...) or 0)
