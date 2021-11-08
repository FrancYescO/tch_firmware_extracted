local process = require("tch.process")
local M = {}

local common = require 'transformer.mapper.nwcommon'
local match, format = string.match, string.format

local function get_src_by_host(host, iptype)
    if not (match(host, "(%d+%.%d+%.%d+%.%d+)") or match(host, "%:")) then
        -- if domain name, resolve to ip address
        if host then
          local p
          if iptype == "-4" then
            p = assert(process.popen("dnsget", { host }, "re"))
          else
            p = assert(process.popen("dnsget", { "-t", "AAAA", host }, "re"))
          end
          local output = p:read("*a")
          host = output:match("%S+%s+%S+%s+(%S+)")
          p:close()
        end
    end
    if host then
        -- get interface by route
        local p
        if iptype == "-4" then
          p = assert(process.popen("ip", {"route", "get", host}, "re"))
        else
          p = assert(process.popen("ip", {"-6", "route", "get", host}, "re"))
        end
        local output = p:read("*a")
        p:close()
        return match(output, "src%s+(%S+)")
    end
end

-- convert logical interface to physical
function M.get_physical_interface(interface, host, iptype)
  if interface and interface:len() ~= 0 then
    local addr
    local status = common.get_ubus_interface_status(interface)
    local iface = status and status["l3_device"]
    if not iface then
      return
    end
    if iptype == "-4" then
      addr = status['ipv4-address'] and status['ipv4-address'][1] and status['ipv4-address'][1]['address']
    else
      addr = status['ipv6-address'] and status['ipv6-address'][2] and status['ipv6-address'][2]['address']
    end
    return iface, addr
  else
    return "", get_src_by_host(host, iptype)
  end
end

function M.copy_ping_or_traceroute_result(user, fp, tmp_file)
  local output
  if user == "diagping" or user == "webui" then
    local tmp_fp = io.open(tmp_file, "w")
    if not tmp_fp then
      return
    end
    for line in fp:lines() do
      tmp_fp:write(line .. '\n')
      tmp_fp:flush()
      output = output and output .. line .. '\r\n' or line .. '\r\n'
    end
    tmp_fp:close()
  else
    output = fp:read("*a")
  end
  return output
end
return M
