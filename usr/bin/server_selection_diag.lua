#!/usr/bin/env lua
local tonumber, assert, io, string =
      tonumber, assert, io, string
local format, match = string.format, string.match
local logger = require 'transformer.logger'
local cursor = require("uci").cursor()
local common = require 'transformer.mapper.nwcommon'
local posix = require 'tch.posix'
local inet_pton = posix.inet_pton
local process = require("tch.process")

local log_config = {
    level = 3,
    stderr = false
}

local config = "tr143"
local cmdline
local output

local ipaddress = {}
local host_list = {}
local state = "Completed"
local fastest_host
local minimum_response_time
local average_response_time
local maximum_response_time
local ipaddress_used
local response = {}
local interface
local protocol_version = "Any"
local selected_version = {}
local protocol = "ICMP"
local repetition = 1
local timeout = 0
local udpecho_prog = "/usr/bin/udp_echo_diag"
local resfile = "/tmp/serverselection.out"

local interface_ipv4
local interface_ipv6



logger.init(log_config.level, log_config.stderr)
logger = logger.new("ServerSelection", log_config.level)

local function output_result()
  -- output the result to uci
  cursor:set(config, "ServerSelectionDiagnostics", "DiagnosticsState", state)
  if state == "Completed" then
    cursor:set(config, "ServerSelectionDiagnostics", "FastestHost", fastest_host)
    cursor:set(config, "ServerSelectionDiagnostics", "MinimumResponseTime", minimum_response_time)
    cursor:set(config, "ServerSelectionDiagnostics", "AverageResponseTime", average_response_time)
    cursor:set(config, "ServerSelectionDiagnostics", "MaximumResponseTime", maximum_response_time)
    cursor:set(config, "ServerSelectionDiagnostics", "IPAddressUsed", ipaddress_used)
  else
    cursor:set(config, "ServerSelectionDiagnostics", "MinimumResponseTime", 0)
    cursor:set(config, "ServerSelectionDiagnostics", "AverageResponseTime", 0)
    cursor:set(config, "ServerSelectionDiagnostics", "MaximumResponseTime", 0)
  end
  cursor:commit(config)
end

local function summary_result()
  state = "Error_Other"
  for i,v in ipairs(host_list) do
    if response[i]["state"] == "Completed" then
      if state ~= "Completed" then
        fastest_host = v
        state = "Completed"
        minimum_response_time = response[i]["min"]
        average_response_time = response[i]["avg"]
        maximum_response_time = response[i]["max"]
        ipaddress_used = ipaddress[i]
      else
        if response[i]["avg"] < average_response_time then
          fastest_host = v
          minimum_response_time = response[i]["min"]
          average_response_time = response[i]["avg"]
          maximum_response_time = response[i]["max"]
          ipaddress_used = ipaddress[i]
        end
      end
      minimum_response_time = math.modf(minimum_response_time+0.5)
      maximum_response_time = math.modf(maximum_response_time+0.5)
    elseif response[i]["state"] == "Error_CannotResolveHostName" and state ~= "Completed" then
      state = "Error_CannotResolveHostName"
    elseif response[i]["state"] == "Error_Internal" and state == "Error_Other" then
      state = "Error_Internal"
    end
  end
end

local function check_protocolversion(str)
  local version
  local ip = inet_pton(posix.AF_INET, str)
  if ip then
      version = "IPv4"
  else
    ip = inet_pton(posix.AF_INET6, str)
    if ip then
      version = "IPv6"
    else
      version = "Any"
    end
  end
  return version
end

local function extract_host(str)
  local host
  local port
  local version = check_protocolversion(str)
  if version == "IPv4" or version == "IPv6" then
    host = str
  else
    host = match(str, "%s*%[*(.+)%]%s*:?")
    if host then
      port = match(str, "%]:(.+)%s*")
    else
      host= match(str, "%s*([^:]+)")
      if host then
        port = match(str, ":(.+)%s*")
      end
    end
  end
  return host, port
end

local function dns_host_address(host_str, version)
  local host_ip
  if version == "IPv6" then
    local p = process.popen("dnsget", {"-t", "AAAA", host_str}, "re")
    output = p:read("*a")
    p:close()
    host_ip = match(output, "AAAA%s*([%S.:]+)")
    if host_ip then
      local ip = inet_pton(posix.AF_INET6, host_ip)
      if not ip then
        host_ip = nil
      end
    end
  else
    local p = process.popen("dnsget", {"-t", "A", host_str}, "re")
    output = p:read("*a")
    p:close()
    host_ip = match(output, "A%s*(%d+.%d+.%d+.%d+).*")
  end
  return host_ip
end

local function get_addresses(host_str)
  if not host_str or host_str:len() == 0 then
    return "Error_CannotResolveHostName"
  end

  local interface_ip
  local host_ip
  local version = check_protocolversion(host_str)
  if interface then
    -- Assign interface
    if version == "IPv4" then
      -- IPv4 host
      if not interface_ipv4 or protocol_version == "IPv6" then
        return "Error_Other"
      else
        interface_ip = interface_ipv4
        host_ip = host_str
      end
    elseif version == "IPv6" then
      -- IPv6 host
      if not interface_ipv6 or protocol_version == "IPv4" then
        return "Error_Other"
      else
        interface_ip = interface_ipv6
        host_ip = host_str
      end
    else
      -- Any host
      if interface_ipv4 then
        host_ip = dns_host_address(host_str, "IPv4")
        interface_ip = interface_ipv4
      end
      if not host_ip and interface_ipv6 then
        host_ip = dns_host_address(host_str, "IPv6")
        interface_ip = interface_ipv6
      end
    end
  else
    -- no assigned interface
    if version == "IPv4" and protocol_version == "IPv6" then
      return "Error_Other"
    elseif version == "IPv6" and protocol_version == "IPv4" then
      return "Error_Other"
    end
    if protocol_version ~= "IPv6" then
      if version == "Any" then
        host_ip = dns_host_address(host_str, "IPv4")
      elseif version == "IPv4" then
        host_ip = host_str
      end
    end

    if host_ip then
      local p = process.popen("ip", {"route", "get", host_ip}, "re")
      output = p:read("*a")
      p:close()
      interface_ip = match(output, "src%s+([%S.:]+)")
    end
    if (not host_ip) or (not interface_ip) then
      if version == "Any" then
        host_ip = dns_host_address(host_str, "IPv6")
      elseif version == "IPv6" then
        host_ip = host_str
      end
      if host_ip then
        local p = process.popen("ip", {"-6", "route", "get", host_ip}, "re")
        output = p:read("*a")
        p:close()
        interface_ip = match(output, "src%s+([%S:]+)")
      end
    end
  end

  if not host_ip then
    return "Error_CannotResolveHostName"
  elseif not interface_ip then
    return "Error_Other"
  else
    return "Completed", interface_ip, host_ip
  end
end

local function parse_interface()
  if interface then
    local interface_version = check_protocolversion(interface)
    if interface_version == "IPv4" then
      interface_ipv4 = interface
    elseif interface_version == "IPv6" then
      interface_ipv6 = interface
    else
      local iface = common.get_ubus_interface_status(interface)
      if iface then
        if iface["ipv4-address"] and iface["ipv4-address"][1] and iface["ipv4-address"][1]["address"] then
           interface_ipv4 = iface["ipv4-address"][1]["address"]
        end
        if iface["ipv6-address"] and iface["ipv6-address"][1] and iface["ipv6-address"][1]["address"] then
           interface_ipv6 = iface["ipv6-address"][1]["address"]
        end
      end
    end
    if not interface_ipv4 and not interface_ipv6 then
      state = "Error_Other"
      return
    elseif protocol_version == "IPv4" then
      interface_ipv6 = nil
      if not interface_ipv4 then
        state = "Error_Other"
        return
      end
    elseif protocol_version == "IPv6" then
      interface_ipv4 = nil
      if not interface_ipv6 then
        state = "Error_Other"
        return
      end
    end
  end
end

local function do_ping()
  parse_interface()
  if state ~= "Completed" then
    output_result()
    logger:notice("The Server Selection invalid interface")
    return
  end

  for i,v in ipairs(host_list) do
    local index = 0
    local sum = 0
    response[i] = {}
    if v and v:len() ~= 0 then
      local host_ip
      local host = extract_host(v)
      response[i]["state"], ipaddress[i], host_ip = get_addresses(host)
      if response[i]["state"] == "Completed" then
        response[i]["state"] = "Error_Internal"
        response[i]["min"] =1000000000
        response[i]["max"] =0
        response[i]["avg"] =0
        if not timeout or timeout == 0 then
          cmdline = {"-c", "1", "-I", ipaddress[i], host_ip}
        else
          local tm = math.modf(timeout/1000)
          if tm == 0 then
            tm = 1
          end
          cmdline = {"-c", "1", "-W", tm, "-I", ipaddress[i], host_ip}
        end

        while index < repetition do
          index = index+1
          local p = process.popen("ping", cmdline, "re")
          output = p:read("*a")
          p:close()
          if match(output, "^ping: bad address") and response[i]["state"] == "Error_Internal" then
            response[i]["state"] = "Error_CannotResolveHostName"
          else
            local value
            local min
            min = match(output, "min/avg/max = (%d+%.%d+)/(%d+%.%d+)/(%d+%.%d+) ms")
            if min then
              value = tonumber(min)*1000
              response[i]["state"] = "Completed"
              sum = sum + 1
              if response[i]["min"] > value then
                response[i]["min"] = value
              end
              if response[i]["max"] < value then
                response[i]["max"] = value
              end
              response[i]["avg"] = response[i]["avg"]+value
            end
          end
        end
        if response[i]["state"] == "Completed" and sum > 0 then
          response[i]["avg"] = response[i]["avg"]/sum
          response[i]["avg"] = math.modf(response[i]["avg"]+0.5)
        end
      end
    else
      response[i]["state"] = "Error_CannotResolveHostName"
    end
  end
  summary_result()
  output_result()
end

local function do_udpecho()
  -- do udp echo and capture output
  if interface then
    local interface_version = check_protocolversion(interface)
    if interface_version == "Any" then
      local iface = common.get_ubus_interface_status(interface)
      if iface and iface["l3_device"] then
        interface = iface["l3_device"]
      end
    end
  end

  for i,v in ipairs(host_list) do
    response[i] = {}
    if v and v:len() ~= 0 then
      if timeout and timeout > 0 then
        cmdline = {"--resfile", resfile, "--repetitions", repetition, "--protocol", protocol_version, "--individual", "0","--intertime", "1", "--timeout", timeout}
      else
        cmdline = {"--resfile", resfile, "--repetitions", repetition, "--protocol", protocol_version, "--individual", "0", "--intertime", "1"}
      end
      response[i]["state"] = "Completed"
      local host
      local port
      host, port = extract_host(v)
      if host then
        cmdline[#cmdline + 1] = "--host"
        cmdline[#cmdline + 1] = host
        if port and port:len() ~= 0 then
          cmdline[#cmdline + 1] = "--port"
          cmdline[#cmdline + 1] = port
        end
        if interface and interface:len() ~= 0 then
          cmdline[#cmdline + 1] = "--intf"
          cmdline[#cmdline + 1] = interface
        end
        local p = process.popen(udpecho_prog, cmdline)
        p:close()
        local file = io.open(resfile, "r")
        if not file then
          state = "Error_Internal"
          output_result()
          logger:notice("The Server Selection open result file fail")
          return
        end
        -- Read back the diagnostics result from temp file
        for line in file:lines() do
          local name
          local value
          name, value = match(line, "([^=]+)=(.+)")
          if name == "DiagnosticsState" then
            response[i]["state"] = value
          elseif name == "IPAddressUsed" then
            ipaddress[i] = value
          elseif name == "MinimumResponseTime" then
            response[i]["min"] = tonumber(value)
          elseif name == "AverageResponseTime" then
            response[i]["avg"] = tonumber(value)
          elseif name == "MaximumResponseTime" then
            response[i]["max"] = tonumber(value)
          elseif name == "SuccessCount" then
            if value == "0" then
              response[i]["state"] = "Error_Internal"
            end
          end
        end
        file:close()
      else
        response[i]["state"] = "Error_CannotResolveHostName"
      end
    else
      response[i]["state"] = "Error_CannotResolveHostName"
    end
  end
  summary_result()
  output_result()
end

local function get_host()
  local host = cursor:get(config, "ServerSelectionDiagnostics", "HostList")
  if host and host:len() ~= 0 and host ~= "\'\'" then
    local v
    for v in string.gmatch(host, "[^,%s]+") do
      host_list[#host_list + 1] = v
    end
  else
    state = "Error_CannotResolveHostName"
    logger:notice("The Server Selection HostList empty")
    output_result()
    return
  end
end

local function selection()
  -- get ping configuration from UCI
  local str = cursor:get(config, "ServerSelectionDiagnostics", "ProtocolVersion")
  if str then
    protocol_version = str
  end
  str = cursor:get(config, "ServerSelectionDiagnostics", "Protocol")
  if str then
    protocol = str
  end
  str = cursor:get(config, "ServerSelectionDiagnostics", "NumberOfRepetitions")
  if str then
    repetition = tonumber(str)
    if not repetition or repetition == 0 then
      state = "Error_Other"
      logger:notice("The Server Selection NumberOfRepetitions is invalid")
      output_result()
      return
    end
  end
  str = cursor:get(config, "ServerSelectionDiagnostics", "Timeout")
  if str then
    timeout = tonumber(str)
    if not timeout then
      state = "Error_Other"
      logger:notice("The Server Selection Timeout is invalid")
      output_result()
      return
    end
  end
  str = cursor:get(config, "ServerSelectionDiagnostics", "Interface")
  if str and str:len() ~= 0 and str ~= "\'\'" then
    interface = str
  end
  get_host()
  if state ~= "Completed" then
    return
  end

  if protocol == "ICMP" then
    do_ping()
  else
    do_udpecho()
  end
end

local diagstate = cursor:get(config, "ServerSelectionDiagnostics", "DiagnosticsState")
if diagstate and diagstate == "Requested" then
  if arg[1] then
    udpecho_prog = arg[1]
  end
  if arg[2] then
    resfile = arg[2]
  end
  -- selection()
  local err, err_msg = pcall(selection)
  if not err then
    state = "Error_Internal"
    logger:critical(err_msg)
  end

else
  logger:notice("The Server Selection DiagnosticsState not Requested")
end
