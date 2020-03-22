local gmatch, gsub, format, find, sub, byte, char =
      string.gmatch, string.gsub, string.format, string.find, string.sub, string.byte, string.char
local concat = table.concat
local type, pairs, ipairs, select, loadfile, pcall =
      type, pairs, ipairs, select, loadfile, pcall

local M = {}
local touci = require("tch.configmigration.touci")
--local tprint = require("tch.tableprint")

local commit_list = {}

function M.append_commit_list(config)
  commit_list[config] = true
end

function M.commit_list()
  for k in pairs(commit_list) do
      touci.commit(k)
  end
end

local function create_map_env(config)
  local map_env = {
    config = config,
  }
  -- in your map you can access everything but you're
  -- not allowed to create new global variables
  setmetatable(map_env, {
    __index = _G,
    __newindex = function()
                   error("global variables are evil", 2)
                 end
  })
  return map_env
end

function M.get_g_user_ini(s_user_ini)
  local g_user_ini = {}
  local pos, pre_k

  while true do
    local s, e = find(s_user_ini, "%[ [%w_]+%.ini %]", pos)
    if not s then
       s, e = find(s_user_ini, "%[ endofarch %]", pos)
       if not s then break end
    end
    -- extract section name
    local k = sub(s_user_ini, s+2, e-2)
    -- update position for next iteration
    pos = e + 1
    -- create new global ini table if need
    if not g_user_ini[k] then
       g_user_ini[k] = {}
    end
    -- convert previous section from marker to string
    if g_user_ini[pre_k] then
       g_user_ini[pre_k] = sub(s_user_ini, g_user_ini[pre_k].s, s-1)
       -- remove heading and ending space
       g_user_ini[pre_k] = gsub(g_user_ini[pre_k], "^%s*(.-)%s*$", "%1")
    end
    -- only mark the start postion of section
    g_user_ini[k] = { s = e + 1 }
    -- update info for next iteration
    pre_k = k
  end
  return g_user_ini
end

local function encode_backslash_escape(s)
  return (gsub(s, "\\(.)", function (x)
            return format("\\%03d", byte(x))
          end))
end

local function decode_backslash_escape(s)
  return (gsub(s, "\\(%d%d%d)", function (d)
            return "\\"..char(d)
          end))
end

-- convert string to list when the same key has different value
local function set_kv_into_t(k, v, t)
  if not t[k] then
     t[k] = v
  else
     local tk = t[k]
     if type(tk) == "string" and tk ~= v then
        local tmp = tk -- save old string first
        t[k] = { tmp } -- convert original t[k] to a table storage
     end
     tk = t[k]
     if type(tk) == "table" then
        -- avoid duplicated value
        for _,i in ipairs(tk) do
            if i == v then return end
        end
        tk[#tk+1] = v
     end
  end
end

function M.str2kv(t, s)
  -- strict pattern at first
  s = gsub(encode_backslash_escape(s), '(([%w_%-]+)="([^"]-)")',
            function (...)
              local v = decode_backslash_escape(select(3, ...))
              set_kv_into_t(select(2, ...), v, t)
              -- %1 is the match key-value pairs, return "" to discard it
              -- since it was already processed
            return "" end)
  s = decode_backslash_escape(s)
  -- loose pattern at last
  for k, v in gmatch(s, "([%w_%-]+)=(%S+)") do
      set_kv_into_t(k, v, t)
  end
end

function M.map_1to1(section_string, t, g_user_ini)

  if t and t.key and t.map then
     local legacy_t = {}
     --fill in attributes of each instance
     for line in gmatch(section_string, t.key) do
         --print("key:", t.key) print("line:", line)
         M.str2kv(legacy_t, line)
     end
     if type(t._maps_store) == "table" then
        legacy_t._maps_store = t._maps_store
     end
     --tprint(legacy_t)

     for legacy_key, legacy_value in pairs(legacy_t) do
         local map2uci_entry = t.map[legacy_key]
         if type(map2uci_entry) == "table" then
            local ucicmd = {}
            -- default uci_config can be overwitten by the one in entry
            if t.uci_config then
               ucicmd.uci_config = t.uci_config
            end
            -- default uci_secname can be overwitten by the one in entry
            if t.uci_secname then
               if type(t.uci_secname) ~= "function" then
                  ucicmd.uci_secname = t.uci_secname
               else
                  ucicmd.uci_secname = t.uci_secname(legacy_key, legacy_value, legacy_t, g_user_ini)
               end
            end
            -- fill in command table will be applied to UCI
            for mk, mv in pairs(map2uci_entry) do
                if type(mv) == "function" then
                   ucicmd[mk] = mv(legacy_key, legacy_value, legacy_t, g_user_ini)
                else
                   ucicmd[mk] = mv
                end
            end
            -- if cannot find value in map table entry, use legacy value by default
            if not ucicmd.value then
               ucicmd.value = legacy_value
            end
            -- default action is "set"
            if not ucicmd.action then
               ucicmd.action = "set"
            end
            M.append_commit_list(ucicmd.uci_config)
            --tprint(ucicmd)
            local ucicmd_result = touci.touci(ucicmd)
            if ucicmd_result and type(t._maps_store) == "table" then
               t._maps_store._ucicmd_result = ucicmd_result
            end
         end
     end
  end
end

local function loc_is_key_exist(key, key_list)
  for _,v in ipairs(key_list) do
      if v[#v] == key[#key] then
         return true
      end
  end
end

function M.map_multiple(section_string, t, g_user_ini)
  if t and t.keycap and t.maps then
     local key_list = {}
     gsub(section_string, t.keycap,
             function (...)
               local keys = {...}
               if not t.allowdupkey then
                  -- add an auxiliary element to quick comparison
                  keys[#keys+1] = concat(keys, "|")
                  if not loc_is_key_exist(keys, key_list) then
                     key_list[#key_list+1] = keys
                  end
               else
                  key_list[#key_list+1] = keys
               end
             end)
     if not t.allowdupkey then
        -- remove the auxiliary element for quick comparison
        for _,v in ipairs(key_list) do
            v[#v] = nil
        end
     end
     --tprint(key_list)
     for _,keys in ipairs(key_list) do
        for _,v in ipairs(t.maps) do
            v._maps_store = keys
            if not v.type or v.type == "single" then
               v.key = v.keygen(keys)
               --tprint(v)
               M.map_1to1(section_string, v, g_user_ini)
            elseif v.type == "multiple" then
               v.keycap = v.keygen(keys)
               --tprint(v)
               M.map_multiple(section_string, v, g_user_ini)
            end
        end
     end
  end
end

function M.convert_map(section_string, map_table, g_user_ini)
  if type(map_table) ~= "table" or type(section_string) ~= "string" then return nil end

  for _,v in ipairs(map_table) do
      if not v.type or v.type == "single" then
         M.map_1to1(section_string, v, g_user_ini)
      elseif v.type == "multiple" then
         M.map_multiple(section_string, v, g_user_ini)
      end
  end
end

function M.run_handler(handler_file, config, g_user_ini)
  local handler, errmsg = loadfile(handler_file)
  if handler then
     local map_env = create_map_env(config)
     setfenv(handler, map_env)
     local rc, result = pcall(handler)
     if not rc then
        return nil, result
     elseif type(result) == "table" and result.convert then
        result.convert(g_user_ini)
        return true
     end
  else
     return nil, errmsg
  end
end

return M
