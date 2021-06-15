#!/usr/bin/lua

local ubus = require("ubus")
local uloop = require("uloop")
local uci = require("uci")
local x = uci.cursor()
local ubus_conn = ubus.connect()
local uci_helper = require("transformer.mapper.ucihelper")
local scripth = require('wansensingfw.scripthelpers')
local log = require("tch.logger").new('supervision', 2)
local posix = require("tch.posix")
local cURL = require("cURL")
local curl = cURL.easy_init()
local json   = require("dkjson")

------------------------------------------------------------------
-- global parameters
------------------------------------------------------------------
local global = { mode = nil, v4 = nil, v6 = nil, enabled = nil }
local global_sts = { running_mode = "None", triggered = false }

-- bfd
local bfd_timer = { v4 = nil, v6 = nil}
local bfd_cfg = {}
local bfd_delayed = false
local bfd_sts = { failed_counter_v4 = 0, failed_counter_v6 = 0 }

-- dns
local dns_timer = { v4 = nil, v6 = nil}
local dns_cfg = {}
local dns_delayed = false
local dns_sts = { failed_counter_v4 = 0, failed_counter_v6 = 0, v4_pid = 0, v6_pid = 0 }

-- dns heartbeat
local hb_timer = { v4 = nil, v6 = nil}
local hb_cfg = {}

------------------------------------------------------------------
-- bfdecho functions
------------------------------------------------------------------
-- start timer of bfdecho
local function bfd_start_timer(ipv4)
  log:debug("bfd_start_timer" .. (ipv4 and " ipv4 " or " ipv6 ") .. bfd_cfg.poll_interval)
  if ipv4 then
    bfd_timer.v4:set(bfd_cfg.poll_interval * 1000)
  else
    bfd_timer.v6:set(bfd_cfg.poll_interval * 1000)
  end
end

local function bfd_get_destmac(nexthop)
  local fd = io.popen("ip neigh")
  local destmac = nil
  local line

  if fd then
    for line in fd:lines() do
      if string.match(line,nexthop) then
        destmac = string.match(line, "(%w+:%w+:%w+:%w+:%w+:%w+)")
        break
      end
    end
  fd:close()
  end

  return destmac
end

local function bfd_send_pkg(cmd, ipv4)
  local fd = io.popen(cmd)
  local status = nil

  if fd then
    local line = fd:read("*a")
    if line then
      status = string.match(line, (ipv4 and "bfdechov4" or "bfdechov6") .. ".state.status=(%d)")
    end
    fd:close()
  end

  return status
end

local function send_bfdecho_msg(ipv4)
  local interface = ipv4 and global.v4 or global.v6
  local data = ubus_conn:call("network.interface." .. interface, "status", {})
  local failed_counter = ipv4 and "failed_counter_v4" or "failed_counter_v6"

  if global_sts.running_mode ~= "BFD" then
    return
  end

  if data and data["up"] then
    local timeout = bfd_cfg.timeout
    local intf = data["device"]
    local enabled_key = ipv4 and "ipv4_enabled" or "ipv6_enabled"
    local ip_key = ipv4 and "ipv4-address" or "ipv6-address"
    local enabled = bfd_cfg[enabled_key]
    local src_ip, destmac

    -- src_ip
    if enabled == "0" then
      bfd_sts[failed_counter] = 0
      ubus_conn:send("bfdecho", {interface = interface, state = "1"})
      log:notice("send_bfdecho_msg : " .. (ipv4 and " ipv4 " or " ipv6 " .. " not enabled"))
      bfd_start_timer(ipv4)
      return
    end
    src_ip = data[ip_key] and data[ip_key][1] and data[ip_key][1].address

    -- nexthop
    local nexthop = ""
    for j=1, #data["route"] do
      local source = string.match(data["route"][j].source, "(.*)\/%d+")
      if not source then
        source = data["route"][j].source
      end
      if data["route"][j].nexthop and data["route"][j].nexthop ~= "0.0.0.0" and data["route"][j].nexthop ~= "::" and src_ip == source then
        nexthop = data["route"][j].nexthop
        break
      end
    end

    -- random delay once for bfd and dns
    if not bfd_delayed and not dns_delayed then
      local delay = bfd_cfg.delay
      if delay ~= 0 then
        math.randomseed(tostring(os.time()):reverse():sub(1, 6))
        delay = math.random(1, delay)
        log:info("bfdecho random delay " .. delay)
        os.execute("sleep " .. delay)
      end
      bfd_delayed = true
    end

    -- destmac
    destmac = bfd_get_destmac(nexthop)
    if destmac == nil and ipv4 then
      -- Fix:  HPQC 12948. Sometimes getting destmac of the nexthop is not successful after wan is up immediately
      log:notice("send_bfdecho_msg : " .. "arping -c 1 -f -D " .. nexthop .. " -I " ..  intf)
      os.execute("arping -c 1 -f -D " .. nexthop .. " -I " ..  intf .. "; sleep 5")
      destmac = bfd_get_destmac(nexthop)
    end

    -- send bfd echo package
    if intf and destmac and src_ip and timeout then
      local serial_number = x:get("env", "var", "serial") or ""
      local oui = x:get("env", "var", "oui") or ""
      local payload = oui .. "-" .. serial_number
      local cmd = "/usr/sbin/bfdecho --intf " .. intf .. " --dmac " ..  destmac  .. " --srcip " .. src_ip .. " --destip " .. src_ip .. " --timeout " .. timeout .. " -p " .. payload
      if bfd_cfg.dscp then
        log:info("bfdecho dscp : " .. bfd_cfg.dscp)
        cmd = cmd .. " --qos " .. bfd_cfg.dscp
      end

      local state = bfd_send_pkg(cmd, ipv4)
      if state then
        if state == "0" then
          bfd_sts[failed_counter] = bfd_sts[failed_counter] + 1
          log:error("send bfdecho failed " .. bfd_sts[failed_counter] .. (ipv4 and " ipv4 " or " ipv6 "))
        elseif state == "1" then
          bfd_sts[failed_counter] = 0
          ubus_conn:send("bfdecho", {interface = interface, state = "1"})
          log:info("send bfdecho OK for" .. (ipv4 and " ipv4 " or " ipv6 "))
        end
      else
        bfd_sts[failed_counter] = bfd_sts[failed_counter] + 1
        log:error("send_bfdecho_msg : unknown error for" .. (ipv4 and " ipv4 " or " ipv6 "))
      end
    elseif src_ip == nil then
        log:error("send_bfdecho_msg : src_ip is nil for" .. (ipv4 and " ipv4 " or " ipv6 "))
    else
      bfd_sts[failed_counter] = bfd_sts[failed_counter] + 1
      if destmac == nil then
        log:error("send_bfdecho_msg : destmac is nil for" .. (ipv4 and " ipv4 " or " ipv6 "))
      end
      if intf == nil then
        log:error("send_bfdecho_msg : intf is nil for" .. (ipv4 and " ipv4 " or " ipv6 "))
      end
      if timeout == nil then
        log:error("send_bfdecho_msg : timeout is nil for" .. (ipv4 and " ipv4 " or " ipv6 "))
      end
    end
  else
    bfd_sts[failed_counter] = 0
  end

  if bfd_sts[failed_counter] >= bfd_cfg.failed_limit then
    -- send bfdecho NOK only when failed counter reached failed limit
    log:error("send bfdecho failed for" .. (ipv4 and " ipv4 " or " ipv6 ") .. "reached failed_limit")
    ubus_conn:send("bfdecho", {interface = interface, state = "0"})
    bfd_sts[failed_counter] = 0
  end

  bfd_start_timer(ipv4)
end

local function send_bfdecho_msg_v4()
  send_bfdecho_msg(true)
end

local function send_bfdecho_msg_v6()
  send_bfdecho_msg(false)
end

local function exec_bfd_supervision()
  if global.enabled == "1" then
    if global.v4 ~= nil and bfd_cfg.ipv4_enabled == "1" then
      bfd_timer.v4 = uloop.timer(send_bfdecho_msg_v4)
      send_bfdecho_msg_v4()
    end
    if global.v6 ~= nil and bfd_cfg.ipv6_enabled == "1" then
      bfd_timer.v6 = uloop.timer(send_bfdecho_msg_v6)
      send_bfdecho_msg_v6()
    end
  end
end

------------------------------------------------------------------
-- dns functions
------------------------------------------------------------------
-- Get the DNS server list from system file (IPv4/IPv6 adresses)
local function get_DNS_servers(ipv4)
  local servers = {}

  local resolvfile = uci_helper.get_from_uci({config = "dhcp", sectionname = dns_cfg.dnsmasq_cfg, option = "resolvfile"})
  local match_expr = ipv4 and "nameserver%s+(%d+%.%d+%.%d+%.%d+)" or "nameserver%s+([a-f0-9A-F]*:[a-f0-9A-F:]*:[a-f0-9A-F.]*)%s*"

  local pipe = resolvfile and io.open(resolvfile or "/tmp/resolv.conf.d/resolv.conf.auto", "r")
  if pipe then
    for line in pipe:lines() do
      local server = line:match(match_expr)
      if server then
        table.insert(servers, server)
      end
    end
    pipe:close()
  end

  return servers
end

-- DNS Connectivity Check: Do a DNS check to ensure IP connectivity works
-- @return {boolean} whether the interface is up and a dns query was possible
local function dns_testing_set(ipv4)
  local domain_name = dns_cfg.domain_name
  local apple_com = 'apple.com'
  local google_dns = ipv4 and '8.8.8.8' or '2001:4860:4860::8888'
  local timeout = dns_cfg.timeout
  local retry = 1

  --DNS Check
  log:notice("Launching DNS Request " .. (ipv4 and "ipv4" or "ipv6"))
  local server_list = get_DNS_servers(ipv4)
  if server_list ~= nil then
    for _,v in ipairs(server_list)
    do
      log:notice("Launching DNS Request with DNS server " .. v)
      local status, hostname_or_error = scripth.dns_check(domain_name, v, domain_name, nil, nil, (not ipv4), retry, timeout)
      if status and hostname_or_error then
        return true
      end
    end
    log:notice("Trying again - Launching DNS Request with GOOGLE DNS server")
    local status, hostname_or_error = scripth.dns_check(apple_com, google_dns, apple_com, nil, nil, (not ipv4), retry, timeout)
    if status and hostname_or_error then
      return true
    end
  else
    log:notice("Launching DNS Request with default DNS server")
    local status, hostname_or_error = scripth.dns_check(domain_name, nil, domain_name, nil, nil, (not ipv4), retry, timeout)
    if status and hostname_or_error then
      return true
    end
  end

  return false
end

-- start timer of dns (poll_interval)
local function dns_start_timer_long(ipv4)
  log:debug((ipv4 and "ipv4" or "ipv6") .. " dns_start_timer " .. dns_cfg.poll_interval)
  if ipv4 then
    dns_timer.v4:set(dns_cfg.poll_interval * 1000)
  else
    dns_timer.v6:set(dns_cfg.poll_interval * 1000)
  end
end

-- start timer of dns (retry_interval)
local function dns_start_timer_short(ipv4)
  log:debug((ipv4 and "ipv4" or "ipv6") .. " dns_start_timer " .. dns_cfg.retry_interval)
  if ipv4 then
    dns_timer.v4:set(dns_cfg.retry_interval * 1000)
  else
    dns_timer.v6:set(dns_cfg.retry_interval * 1000)
  end
end

local function dns_kill_process(ipv4, ipv6)
  if ipv4 and dns_sts.v4_pid > 0 then
    log:debug("kill dns ipv4 process")
    os.execute("kill -9 " .. dns_sts.v4_pid)
    dns_sts.v4_pid = 0
    dns_sts.failed_counter_v4 = 0
  end
  if ipv6 and dns_sts.v6_pid > 0 then
    log:debug("kill dns ipv6 process")
    os.execute("kill -9 " .. dns_sts.v6_pid)
    dns_sts.v6_pid = 0
    dns_sts.failed_counter_v6 = 0
  end
end

local function run_dns_test(ipv4, failed_counter)
  local pid = posix.fork()
  if not pid then
    log:error("supervision fork failed")
    return
  elseif pid == 0 then -- pid 0 is the child process
    local interface = ipv4 and global.v4 or global.v6
    if dns_testing_set(ipv4) then
      cmd='ubus send supervision.timeout ' .. "'" .. '{"state":"1","interface":"' .. interface .. '"}' .. "'"
    else
      cmd='ubus send supervision.timeout ' .. "'" .. '{"state":"0","interface":"' .. interface .. '"}' .. "'"
    end
    -- to receive ubus event itself,  uloop timer is actually working in blocking mode
    os.execute(cmd)
    os.exit(0)
  elseif pid > 0 then -- parent process
    -- get child pid in parent
    if ipv4 then
      dns_sts.v4_pid = tonumber(pid)
    else
      dns_sts.v6_pid = tonumber(pid)
    end
  end
end

-- send_dns_query
-- OK: wait long timeout for next query
-- NOK: retry limit times ; then long timeout or interface up event for next query
local function send_dns_query(ipv4)
  local interface = ipv4 and global.v4 or global.v6
  local enabled_key = ipv4 and "ipv4_enabled" or "ipv6_enabled"
  local enabled = dns_cfg[enabled_key]
  local failed_counter = ipv4 and "failed_counter_v4" or "failed_counter_v6"

  if global_sts.running_mode ~= "DNS" then
    return
  end

  if enabled == "0" then
    ubus_conn:send("dns", {interface = interface, state = "1"})
    dns_start_timer_long(ipv4)
    return
  end

  -- check if wan is up Or wan6 is up and has global IPv6 address
  -- For Telstra, only when wan6 is up and has global IPv6 address, wan6 is applicable for upper layer application
  local status = ipv4 and scripth.checkIfInterfaceIsUp(interface) or scripth.checkIfInterfaceHasIP(interface, true)

  log:info("send_dns_query interface " .. interface .. " is " .. (status and "up" or "down"))
  if not status then
    dns_sts[failed_counter] = 0
    dns_start_timer_long(ipv4)
  else
    -- random delay once for bfd and dns
    if not dns_delayed and not bfd_delayed then
      local delay = dns_cfg.delay
      if delay ~= 0 then
        math.randomseed(tostring(os.time()):reverse():sub(1, 6))
        delay = math.random(1, delay)
        log:info("dns random delay " .. delay)
        os.execute("sleep " .. delay)
      end
      dns_delayed = true
    end

   run_dns_test(ipv4, failed_counter)
  end
end

-- send_dns_query_v4
local function send_dns_query_v4()
  return send_dns_query(true)
end

-- send_dns_query_v6
local function send_dns_query_v6()
  return send_dns_query(false)
end

-- handle wan/wan6 'ifup" action to send dns_query as the poll_interval is long
local function handle_interface_ifup(msg)
  if global_sts.running_mode ~= "DNS" then
    return
  end
  -- Reject bad events
  if type(msg) ~= "table" or (not msg.interface) or type(msg.interface) ~= "string" or (not msg.action) or type(msg.action) ~= "string" then
    log:debug("ignoring network interface event");
    return
  end
  -- send dns query if interface is "ifup", refresh timer to longer incase last timer was triggered yet
  if (msg.interface == global.v4 or msg.interface == global.v6) and msg.action == "ifup" then
    local ipv4 = (msg.interface == "wan")
    log:info("interface " .. msg.interface .. " is up");
    dns_start_timer_long(ipv4)
    send_dns_query(ipv4)
    return
  end
end

local function handle_timeout(msg)
  if global_sts.running_mode ~= "DNS" then
    return
  end
  -- Reject bad events
  if type(msg) ~= "table" or (not msg.interface) or type(msg.interface) ~= "string" or (not msg.state) or type(msg.state) ~= "string" then
    log:debug("ignoring invalid supervison event");
    return
  end
  if msg.interface == global.v4 or msg.interface == global.v6 then
    local ipv4 = (msg.interface == "wan")
    local failed_counter = ipv4 and "failed_counter_v4" or "failed_counter_v6"

    if msg.state == "1" then
      dns_sts[failed_counter] = 0
      ubus_conn:send("dns", {interface = msg.interface, state = "1"})
      log:info(msg.interface .. " send dns query OK")
      dns_start_timer_long(ipv4)
    else
      -- retry 'failed_limit' times for a whole dns_testing_set
      dns_sts[failed_counter] = dns_sts[failed_counter] + 1
      log:info(msg.interface .. " send dns query failed " .. dns_sts[failed_counter])
      if dns_sts[failed_counter] >= dns_cfg.failed_limit then
        -- send dns query NOK only when failed counter reached failed limit
        ubus_conn:send("dns", {interface = msg.interface, state = "0"})
        dns_sts[failed_counter] = 0 -- reset timer and wait for interface up event to re-trigger a new dns_testing_set or timeout
        dns_start_timer_long(ipv4)
      else
        dns_start_timer_short(ipv4) -- retry interval (5s)
      end
    end
    return
  end
end

-- use 'dig' to run dns query
-- Telstra requires any reply from server indicates server is reachable, so just parse the size of the reply
local function dns_run_dig(query, server, v6, attempts, timeout)
  local cmd = 'dig'
  cmd = cmd .. ' ' .. ((server ~= nil) and ("@" .. server) or '')
  cmd = cmd .. (v6 and ' -6' or ' -4')
  cmd = cmd .. (v6 and ' -t AAAA' or ' -t A')
  cmd = cmd .. ' +time=' .. timeout .. ' +tries=' .. attempts
  cmd = cmd .. ' +noall +answer ' .. query .. ' 2>/dev/null'

  log:notice("dns_run_dig::trigger dns query by " .. cmd)

  local pipe = io.popen(cmd, 'r')
  local resolvedhostname, resolvedaddressesv4, resolvedaddressesv6
  if pipe then
    for line in pipe:lines() do
      resolvedhostname = string.match(line,"([^%s]+)%.%s")
      if resolvedhostname then
        if v6 then
          local addr6 = string.match(line,"%s+([a-f0-9]*:[a-f0-9:]*:[a-f0-9]*)")
          if addr6 then
            if not resolvedaddressesv6 then
              resolvedaddressesv6 = {}
            end
            resolvedaddressesv6[#resolvedaddressesv6+1] = addr6
          end
        else
          local addr = string.match(line,"%s+(%d+%.%d+%.%d+%.%d+)")
          if addr then
            if not resolvedaddressesv4 then
              resolvedaddressesv4 = {}
            end
            resolvedaddressesv4[#resolvedaddressesv4+1] = addr
          end
        end
      end
    end
    pipe:close()

    if resolvedhostname and (resolvedaddressesv4 or resolvedaddressesv6) then
      return resolvedhostname, resolvedaddressesv4, resolvedaddressesv6
    else
      return nil -- unresolved , not an error
    end
  else
    log:error("Failed to run dig")
  end
end

local function dns_lookup(query, server, v6, attempts, timeout)
  local status, resolvedhostname_or_error, resolvedaddressesv4, resolvedaddressesv6 = pcall(dns_run_dig, query, server, v6, attempts, timeout)
  return status, resolvedhostname_or_error, resolvedaddressesv4, resolvedaddressesv6
end

local function exec_dns_supervision()
  if global.enabled == "1" then
    if global.v4 ~= nil and dns_cfg.ipv4_enabled == "1" then
      dns_timer.v4 = uloop.timer(send_dns_query_v4)
      send_dns_query_v4()
    end
    if global.v6 ~= nil and dns_cfg.ipv6_enabled == "1" then
      dns_timer.v6 = uloop.timer(send_dns_query_v6)
      send_dns_query_v6()
    end
  end
end

------------------------------------------------------------------
-- dns heartbeat functions
------------------------------------------------------------------
local function heartbeat_testing_set(ipv4, interface, intfaddr)
  local domain_name = hb_cfg.domain_name
  local timeout = hb_cfg.timeout
  local retry = 1
  local status, hostname_or_error, resolvedv4addr, resolvedv6addr

  --DNS Check
  log:notice("Launching DNS Heartbeat " .. (ipv4 and "ipv4" or "ipv6"))
  local server_list = get_DNS_servers(ipv4)

  if server_list[1] ~= nil then
    log:notice("Launching Heartbeat Request with DNS server " .. server_list[1])
  else
    log:notice("Launching Heartbeat Request with default DNS server")
  end
  status, hostname_or_error, resolvedv4, resolvedv6 = dns_lookup(domain_name, server_list[1], (not ipv4), retry, timeout)

  -- Send HTTPS POSTs if dns_lookup was successfull and feature is enabled
  local enabled_key = ipv4 and "ipv4_https_post" or "ipv6_https_post"
  local enabled = hb_cfg[enabled_key]
  local resolvedaddrs = ipv4 and resolvedv4 or resolvedv6
  if status and intfaddr and type(resolvedaddrs) == "table" and #resolvedaddrs > 0 and enabled == "1" then
    local env_var_uci = uci_helper.getall_from_uci({config = "env", sectionname = "var"})
    local headers = { "Content-Type: application/json" }
    local data = { ["IP"] = intfaddr,
                   ["Serial-Number"] = env_var_uci.serial,
                   ["AVC"] = env_var_uci.provisioning_code,
                   ["Model"] = env_var_uci.prod_friendly_name }

    curl:setopt_capath("/etc/ssl/certs")
    curl:setopt_ssl_verifypeer(0)
    curl:setopt_ssl_verifyhost(0)
    curl:setopt_timeout(30)
    curl:setopt_httpheader(headers)
    curl:setopt_post(1)
    curl:setopt_postfields(json.encode(data))

    for _, addr in ipairs(resolvedaddrs) do
      log:notice("Send Heartbeat HTTPS POST to " .. addr)
      curl:setopt_url("https://" .. (ipv4 and addr or "[" .. addr .. "]"))
      local success, err = pcall(function () curl:perform() end)
      if success then
        local response_code = curl:getinfo_response_code()
        if response_code >= 200 and response_code < 300 then
          log:notice("Heartbeat HTTPS POST accepted with code " .. tostring(response_code))
        else
          log:notice("Heartbeat HTTPS POST rejected with code " .. tostring(response_code))
        end
        break
      else
        local _, errmsg = pcall(tostring, err)  -- to be really safe pcall() the tostring function
        log:error("Sending Heartbeat HTTPS POST failed: %s", errmsg or "<no error msg>")
      end
    end
  end
  return status
end

local function heartbeat_start_timer(ipv4)
  log:debug("heartbeat_start_timer" .. (ipv4 and " ipv4 " or " ipv6 ") .. hb_cfg.poll_interval)
  if ipv4 then
    hb_timer.v4:set(hb_cfg.poll_interval * 1000)
  else
    hb_timer.v6:set(hb_cfg.poll_interval * 1000)
  end
end

local function send_heartbeat_query(ipv4)
  if global_sts.running_mode ~= "DNS" then -- not enabled for DNS supervision mode
    local interface = ipv4 and global.v4 or global.v6
    local enabled_key = ipv4 and "ipv4_enabled" or "ipv6_enabled"
    local enabled = hb_cfg[enabled_key]

    if enabled == "1" and interface ~= nil then
      local intfaddr = scripth.checkIfInterfaceHasIP(interface, not ipv4)
      log:info("send_heartbeat_query interface " .. interface .. " is " .. (intfaddr and "up" or "down"))
      if intfaddr then
        log:notice("send_heartbeat_query test")
        heartbeat_testing_set(ipv4, interface, intfaddr)
      end
    end
  end
  heartbeat_start_timer(ipv4) -- always online
end

local function send_heartbeat_query_v4()
  send_heartbeat_query(true)
end

local function send_heartbeat_query_v6()
  send_heartbeat_query(false)
end

local function exec_dns_heartbeat()
  hb_timer.v4 = uloop.timer(send_heartbeat_query_v4)
  send_heartbeat_query_v4()
  hb_timer.v6 = uloop.timer(send_heartbeat_query_v6)
  send_heartbeat_query_v6()
end

------------------------------------------------------------------
-- supervision functions
------------------------------------------------------------------
local function supervision_clean(ipv4, ipv6)
  if global_sts.running_mode == "DNS" then
    dns_kill_process(true, true)
  elseif global_sts.running_mode == "BFD" then
    if ipv4 then
      bfd_sts.failed_counter_v4 = 0
    end
    if ipv6 then
      bfd_sts.failed_counter_v6 = 0
    end
  end
  global_sts.running_mode = "None"
end

local function supervision_enable()
  global_sts.running_mode = global.mode
  if global.mode == "BFD" then
    exec_bfd_supervision()
  elseif global.mode == "DNS" then
    exec_dns_supervision()
  end
end

local function handle_rpc_start(req)
  log:notice("handle_rpc_start : old running mode " .. global_sts.running_mode .. ", triggered " .. (global_sts.triggered and "yes" or "no"))

  if global_sts.running_mode ~= "None" then
    log:notice("supervision already triggered, need to stop firstly")
  else
    global_sts.triggered = true
    if global.enabled == "1" then
      supervision_enable()
    end
  end

  log:notice("handle_rpc_start : new running mode " .. global_sts.running_mode)
  ubus_conn:reply(req, {})
end

local function handle_rpc_stop(req)
  log:notice("handle_rpc_stop : old running mode " .. global_sts.running_mode .. ", triggered " .. (global_sts.triggered and "yes" or "no"))

  if global_sts.triggered then
    global_sts.triggered = false
    supervision_clean(true, true)
  end

  log:notice("handle_rpc_stop : new running mode " .. global_sts.running_mode)
  ubus_conn:reply(req, {})
end

local function legal_dscp(dscp)
  if dscp then
    local dscp_table = {af11 = true, af12 = true, af13 = true, af21 = true, af22 = true, af23 = true,
                        af31 = true, af32 = true, af33 = true, af41 = true, af42 = true, af43 = true,
                        cs0 = true, cs1 = true, cs2 = true, cs3 = true, cs4 = true, cs5 = true, cs6 = true, cs7 = true,
                        ef = true,
                        lowdelay = true, throughput = true, reliability = true}

    return dscp_table[string.lower(dscp)]
  end

  return true
end

local function supervision_cfg_load()
  local global_uci = uci_helper.getall_from_uci({config = "supervision", sectionname = "global"})
  local bfd_uci = uci_helper.getall_from_uci({config = "supervision", sectionname = "bfdecho_config"})
  local dns_uci = uci_helper.getall_from_uci({config = "supervision", sectionname = "dns_config"})
  local hb_uci = uci_helper.getall_from_uci({config = "supervision", sectionname = "heartbeat_config"})
  local default_domain = 'fbbwan.telstra.net'

  -- Function that should be called when a new transaction is started.
  uci_helper.start()

  -- global cfg
  if global_uci.mode == nil or (global_uci.interface == nil and global_uci.interface6 == nil) then
    log:error("missing global configurations")
    return false
  end

  if global_uci.mode ~= "DNS" and global_uci.mode ~= "BFD" and global_uci.mode ~= "Disabled"then
    log:error("invalid mode " .. global_uci.mode)
    return false
  end

  -- set trace_level : 1~6
  if global_uci.trace_level ~= nil then
    local trace_level = tonumber(global_uci.trace_level)
    if trace_level ~= nil then
      if trace_level <= 0 then
        trace_level = 1
      end
      if trace_level >= 7 then
        trace_level = 6
      end
      log:set_log_level(trace_level)
    end
  end

  if global_uci.mode == "Disabled" then
    log:notice("supervision daemon is not enabled")
  end

  if global_uci.enabled == "0" then
    log:notice("supervision global enabled is 0")
  end

  global.mode             = global_uci.mode
  global.v4               = global_uci.interface
  global.v6               = global_uci.interface6
  global.enabled          = global_uci.enabled or "1"

  -- bfdecho cfg
  bfd_cfg.poll_interval   = tonumber(bfd_uci.poll_interval) or 30
  bfd_cfg.timeout         = tonumber(bfd_uci.timeout) or 1
  bfd_cfg.ipv4_enabled    = bfd_uci.ipv4_enabled or "1"
  bfd_cfg.ipv6_enabled    = bfd_uci.ipv6_enabled or "1"
  bfd_cfg.delay           = tonumber(bfd_uci.delay) or 0
  bfd_cfg.failed_limit    = tonumber(bfd_uci.failed_limit) or 4
  if legal_dscp(bfd_uci.dscp) then
    bfd_cfg.dscp = bfd_uci.dscp
  else
    log:notice("dscp value is not legal")
    return false
  end

  -- dns cfg
  dns_cfg.poll_interval   = tonumber(dns_uci.poll_interval) or 300
  dns_cfg.timeout         = tonumber(dns_uci.timeout) or 5
  dns_cfg.failed_limit    = tonumber(dns_uci.failed_limit) or 4
  dns_cfg.retry_interval  = tonumber(dns_uci.retry_interval) or 5 --retry interval between failed dns_checks (fasttimeout)
  dns_cfg.ipv4_enabled    = dns_uci.ipv4_enabled or "1"
  dns_cfg.ipv6_enabled    = dns_uci.ipv6_enabled or "1"
  dns_cfg.delay           = tonumber(dns_uci.delay) or 0
  dns_cfg.dnsmasq_cfg     = dns_uci.dnsmasq_cfg or "dnsmasq"

  if dns_uci.domain_name == nil or dns_cfg.domain_name == '' then
    dns_cfg.domain_name = default_domain
  else
    dns_cfg.domain_name = dns_uci.domain_name
  end
  log:debug("supervision_cfg_load domain_name : " .. dns_cfg.domain_name)

  -- dns heartbeat cfg
  hb_cfg.poll_interval   = tonumber(hb_uci.poll_interval) or 300
  hb_cfg.timeout         = tonumber(hb_uci.timeout) or 5
  hb_cfg.ipv4_enabled    = hb_uci.ipv4_enabled or "1"
  hb_cfg.ipv6_enabled    = hb_uci.ipv6_enabled or "1"
  hb_cfg.ipv4_https_post = hb_uci.ipv4_https_post or "0"
  hb_cfg.ipv6_https_post = hb_uci.ipv6_https_post or "0"

  if hb_uci.domain_name == nil or hb_cfg.domain_name == '' then
    hb_cfg.domain_name = default_domain
  else
    hb_cfg.domain_name = hb_uci.domain_name
  end
  log:debug("supervision_cfg_load heartbeat domain_name : " .. hb_cfg.domain_name)
  return true
end

local function handle_rpc_reload(req)
  log:notice("handle_rpc_reload : old uci mode " .. global.mode .. ", triggered " .. (global_sts.triggered and "yes" or "no"))

  supervision_cfg_load()

  log:notice("handle_rpc_reload : new uci mode " .. global.mode .. ", old running mode " .. global_sts.running_mode)

  if global_sts.running_mode ~= "None" then --supervision triggered, supervision mode / enable changed from GUI
    if global.enabled == "0" then
      -- stop
      supervision_clean(true, true)
    elseif global.mode ~= global_sts.running_mode then
      -- stop
      supervision_clean(true, true)
      -- re-enable
      supervision_enable()
    end
  elseif global_sts.triggered then -- running mode "None", supervision triggered, supervision mode / enable changed from GUI
    if global.enabled == "1" then
      -- re-enable
      supervision_enable()
    end
  end

  log:notice("handle_rpc_reload : new running mode " .. global_sts.running_mode .. ", triggered " .. (global_sts.triggered and "yes" or "no"))
  ubus_conn:reply(req, {})
end

local function supervision_init()
  if not supervision_cfg_load() then
    return false
  end

  if not ubus_conn then
    log:error("ubus connection failed")
    return false
  end

  -- initialize the scripthelpers
  scripth.init({ubus = ubus_conn, uci = uci, logger = log})
  -- rewrite dns_lookup function locally as 'dnsget' not support ipv6
  scripth.dns_lookup = dns_lookup

  -- register RPC callback
  ubus_conn:add({ ['supervision'] = { start = {handle_rpc_start, {}}, stop = {handle_rpc_stop, {}}, reload = {handle_rpc_reload, {}} } })

  -- ubus listen for dns supervision
  ubus_conn:listen({['supervision.timeout'] = handle_timeout})
  ubus_conn:listen({['network.interface'] = handle_interface_ifup})

  return true
end

local function supervision_run()
  log:notice("supervision daemon starting ...")

  if not supervision_init() then
    return
  end

  uloop.init()
  exec_dns_heartbeat()
  uloop.run()
end

-- Run supervision test
supervision_run()
