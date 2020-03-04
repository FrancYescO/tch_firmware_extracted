local uci = require('uci')
local tmhelper = require("tmhelper")
local cursor_state

local QoS_config = {}

local TM_prof_id = {}
local TM_prof_name = {}
local TM_id_dev = { ETH = {}, XTM = {} }

local hardware = {} --FAP/Runner/..
local max_TM_profiles --depends on hardware

-- return library
local M = {}

local function check_hardware()
  if tmhelper.file_exists('/usr/bin/setupfapbcmtm') then
    tmhelper.dbg_printf("hardware info : FAP")
    hardware.fap = true
    max_TM_profiles = 7 --8 available but 0 is reserved for non-TCP
    return true
  end
  if tmhelper.file_exists('/usr/bin/setuprunner') then
    tmhelper.dbg_printf("hardware info : Runner")
    hardware.runner = true
    return true
  end
  return false
end

local function is_unsigned(n)
  return n and n > 0 and n == math.floor(n)
end

local function load_TM_state_dev(TM_state, devtype)
  for _, id in ipairs(TM_state[devtype.."_id"] or {}) do
    id = tonumber(id)

    local name = TM_prof_name[id]
    if not name then --mark id as in use
      name = TM_state["prof_"..id]
      TM_prof_name[id] = name
      TM_prof_id[name] = id
      tmhelper.dbg_printf("%s populates TM profile '%s' (id=%d)", devtype, name, id)
    end
    TM_id_dev[devtype][id] = name
  end
end

local function load_TM_state(module)
  local TM_state = cursor_state:get_all("qos", "TM")
  if not TM_state then return end
  tmhelper.dbg_printf("load TM state (module='%s')", module or "")

  --Populate TM_prof_name and TM_id_dev
  if module and module:lower() ~= "xtm" then
    load_TM_state_dev(TM_state, "XTM")
  end

  --Populate TM_prof_name
  if module and module:lower() ~= "ethernet" then
    load_TM_state_dev(TM_state, "ETH")
  end
end

local function save_TM_state()
  cursor_state:revert("qos", "TM")
  cursor_state:set("qos", "TM", "state")
  --update UCI state
  for id, name in pairs(TM_prof_name) do
    cursor_state:set("qos", "TM", "prof_"..id, name)
  end
  for dev, dev_ids in pairs(TM_id_dev) do
    tmhelper.dbg_printf("save_TM_state for dev "..dev)
    local ids = {}
    for id in pairs(dev_ids) do table.insert(ids, id) end
    cursor_state:set("qos", "TM", dev.."_id", ids)
  end

  cursor_state:save("qos")
end

local function config_TM_profile_RED(id, qos_profile)
  if not id then --find first free id
    id = 1
    while TM_prof_name[id] do
      if max_TM_profiles and id >= max_TM_profiles then return end
      id = id + 1
    end
  end

  if hardware.fap then
    --execute tmctl
    tmhelper.exec_tmctl("setqprof --qprofid %d --redminthr %d --redmaxthr %d --redpct %d",
      id, qos_profile.min_thr, qos_profile.max_thr, qos_profile.drop_prob)
  end

  return id
end

local function apply_drop_profile_RED(devtype, devname, qid, name, qos_profile)
  --create/update TM profile if not yet done
  local id = TM_prof_id[name]
  if not id or not TM_id_dev[devtype][id] then
    id = config_TM_profile_RED(id, qos_profile)
    if not id then return end
    tmhelper.dbg_printf("created TM profile '%s' (id=%d)", name, id)
    TM_prof_name[id] = name
    TM_prof_id[name] = id
    TM_id_dev[devtype][id] = name
  end

  if hardware.fap then
    if qos_profile.tcp_only then
      --set TM queue WRED drop algorithm (priomask covers flow values 32-63 which corresponds with QOS_MARK_FLAG_TCP = 0x0400)
      tmhelper.exec_tmctl("setqdropalg --devtype %s --if %s --qid %d --dropalg %d --qprofid 0 --qprofidhi %d --priomask0 0x0 --priomask1 0xffffffff",
        tmhelper.TM_devtype[devtype], devname, qid, tmhelper.TM_dropalg["WRED"], id)
    else
      --set TM queue RED drop algorithm (applies to all frames)
      tmhelper.exec_tmctl("setqdropalg --devtype %s --if %s --qid %d --dropalg %d --qprofid %d --qprofidhi 0 --priomask0 0x0 --priomask1 0x0",
        tmhelper.TM_devtype[devtype], devname, qid, tmhelper.TM_dropalg["RED"], id)
    end
    return
  end

  if hardware.runner then
    if qos_profile.tcp_only then
      --set TM queue WRED drop algorithm (priomask covers flow values 32-63 which corresponds with QOS_MARK_FLAG_TCP = 0x0400)
      tmhelper.exec_tmctl("setqdropalgx --devtype %s --if %s --qid %d --dropalg %d --loredminthr 0 --loredmaxthr 0 --loredpct 0" ..
                 " --hiredminthr %d --hiredmaxthr %d --hiredpct %d --priomask0 0x0 --priomask1 0xffffffff",
        tmhelper.TM_devtype[devtype], devname, qid, tmhelper.TM_dropalg["WRED"], qos_profile.min_thr, qos_profile.max_thr, qos_profile.drop_prob)
    else
      --set TM queue RED drop algorithm (applies to all frames)
--    temporary workaround (CS3278284): configuring RED not possible, use WRED with priomask zero
      tmhelper.exec_tmctl("setqdropalgx --devtype %s --if %s --qid %d --dropalg %d --loredminthr %d --loredmaxthr %d --loredpct %d" ..
                 " --hiredminthr 0 --hiredmaxthr 0 --hiredpct 0 --priomask0 0x0 --priomask1 0x0",
        tmhelper.TM_devtype[devtype], devname, qid, tmhelper.TM_dropalg["WRED"], qos_profile.min_thr, qos_profile.max_thr, qos_profile.drop_prob)
    end
    return
  end
end

local function apply_drop_profile_DROPTAIL(devtype, devname, qid)
  --set TM queue drop algorithm
  if hardware.fap then
    tmhelper.exec_tmctl("setqdropalg --devtype %s --if %s --qid %d --dropalg %d",
      tmhelper.TM_devtype[devtype], devname, qid, tmhelper.TM_dropalg["DROPTAIL"])
    return
  end
  if hardware.runner then
    tmhelper.exec_tmctl("setqdropalgx --devtype %s --if %s --qid %d --dropalg %d",
      tmhelper.TM_devtype[devtype], devname, qid, tmhelper.TM_dropalg["DROPTAIL"])
    return
  end
end

local function load_QoS_profiles()  --currently RED only
  local profiles = {}

  cursor_state:foreach("qos", "profile_RED",
    function(s)
      local name = s[".name"]
      if not name or name == "" then return end
      name = name:lower()
      local p = {
        min_thr = tonumber(s["min_threshold"]),
        max_thr = tonumber(s["max_threshold"]),
        drop_prob = tonumber(s["drop_probability"]),
        tcp_only = (tonumber(s["tcp_only"]) ~= 0),
      }
      if not is_unsigned(p.min_thr) then p.min_thr = 0 end
      if not is_unsigned(p.max_thr) then p.max_thr = 0 end
      if not is_unsigned(p.drop_prob) then p.drop_prob = 0 end
      -- some sanity checks and corrections
      if p.max_thr == 0 or p.max_thr > 512 then
        -- tmctl utility doesn't know max queue size so assuming 512
        p.max_thr = 512
      end
      if hardware.runner then -- runner only accepts drop_prob = 100
        p.drop_prob = 100
        if p.min_thr > p.max_thr then
          p.min_thr = p.max_thr
        end
      else
        if p.min_thr >= p.max_thr then
          p.min_thr = 0
          p.drop_prob = 0
        end
        if p.drop_prob > 100 then
          p.drop_prob = 100
        end
      end

      profiles[name] = p
      tmhelper.dbg_printf("load RED profile '%s' (min_thr=%u, max_thr=%u, drop_prob=%u, tcp_only=%u)",
        name, p.min_thr, p.max_thr, p.drop_prob, p.tcp_only and 1 or 0)
    end)

  QoS_config.profiles = profiles
end

local function load_QoS_classes()
  local classes = {}

  cursor_state:foreach("qos", "class",
    function(s)
      local name = s[".name"]
      if not name or name == "" then return end
      name = name:lower()
      local cl = {
        priority = tonumber(s["priority"]),
        weigth = tonumber(s["weight"]),
        drop_profile = s["drop_profile"],
      }

      classes[name] = cl
      tmhelper.dbg_printf("load class '%s' [drop='%s']", name, cl.drop_profile or "")
    end)

  QoS_config.classes = classes
end

local function load_QoS_classgroups()
  local classgroups = {}

  cursor_state:foreach("qos", "classgroup",
    function(s)
      local name = s[".name"]
      if not name or name == "" then return end
      name = name:lower()
      local classes = s["classes"]
      if not classes or classes == "" then return end
      local cg = {
        classes = {},
        classes_t = {},
      }
      for cl in string.gmatch(classes, "%S+") do
        local cl_t = QoS_config.classes[cl:lower()]
        if not cl_t then return end
        table.insert(cg.classes, cl)
        table.insert(cg.classes_t, { id = #cg.classes_t , t = cl_t })
      end

      classgroups[name] = cg
      tmhelper.dbg_printf("load classgroup '%s' [%s]", name, table.concat(cg.classes, ", "))
    end)

  QoS_config.classgroups = classgroups
end

local function config_device(devtype, devname, classgroup)
  if not devname or devname == "" then return end
  if not classgroup or classgroup == "" then return end

  tmhelper.dbg_printf("config %s device '%s' (%s)", devtype, devname, classgroup)

  local cg = QoS_config.classgroups[classgroup:lower()]
  if not cg then return end

  for _, cl in ipairs(cg.classes_t) do
    local profile_name = cl.t.drop_profile
    --first check if profile is present in qos config
    local qos_profile
    if profile_name then
      profile_name = profile_name:lower()
      qos_profile = QoS_config.profiles[profile_name]
    end
    if qos_profile then
      tmhelper.dbg_printf("apply profile RED for '%s' (qid=%d, profile='%s')", devname, cl.id, profile_name)
      apply_drop_profile_RED(devtype, devname, cl.id, profile_name, qos_profile)
    else
      tmhelper.dbg_printf("apply profile DROPTAIL for '%s' (qid=%d)", devname, cl.id)
      apply_drop_profile_DROPTAIL(devtype, devname, cl.id)
    end
  end
end

local function config_xtm_device(s)
  config_device("XTM", s[".name"], s["QoS_classgroup"])
end

local function config_xtm()
  cursor_state:foreach("xtm", "atmdevice", config_xtm_device)
  cursor_state:foreach("xtm", "ptmdevice", config_xtm_device)
end

local function config_ethernet_device(s)
  local devicetype = cursor_state:get("ethernet", s[".name"], "devicetype") or "ETH"
  if not tmhelper.file_exists("/sys/class/net/" .. s[".name"] .. "/operstate") then
    tmhelper.error_printf("Interface " .. s[".name"] .. " not ready for configuration")
    return
  end
  config_device(devicetype, s[".name"], s["QoS_classgroup"])
end

local function config_ethernet()
  cursor_state:foreach("ethernet", "port", config_ethernet_device)
end

-- initialisation
-- check if 'tmctl' utility is present
if not tmhelper.tmctl_present() then
  return
end

-- check if board uses FAP or Runner
if not check_hardware() then
  tmhelper.error_printf("hardware info not available")
  return
end

-- library definition

function M.reload(module)
  tmhelper.dbg_printf("reload start")
  local _ = (function()
    cursor_state = uci.cursor(nil, "/var/state")

    load_QoS_profiles()
    load_QoS_classes()
    load_QoS_classgroups()

    load_TM_state(module)

    if not module or module == "xtm" then
      config_xtm()
    end
    if not module or module == "ethernet" then
      config_ethernet()
    end

    save_TM_state()
  end)()
  tmhelper.dbg_printf("reload end")
end

function M.enable_logging(enable)
  tmhelper.enable_logging(enable)
end

function M.enable_tmctl_logging(enable)
  tmhelper.enable_tmctl_logging(enable)
end

return M
