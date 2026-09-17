local uc = require("uciconv")
local o = uc.uci('old')
local n = uc.uci('new')
local getenv = os.getenv
local open = io.open

local debugfile = getenv('DEBUG')

local function echo_debug(fmt, ...)

        local s = fmt:format(...)
        io.stderr:write(s, '\n')
        if debugfile then
                local f = open(debugfile, 'a')
                if f then
                        f:write(s, '\n')
                        f:close()
                end
        else
                io.stderr:write('error opening file', '\n')
        end
end

function safe_uci_set(config, section, attribute, value)
  if (value ~= NULL) then
    n:set(config, section, attribute, value)
  else
    echo_debug("uci not found in old config: %s.%s.%s", config, section, attribute);
  end
end

function migrate_uci(config, section, attribute)
  safe_uci_set(config, section, attribute, o:get(config, section, attribute))
end

-- Migrate controller/agent status
echo_debug("Migrating contoller/agent status...")
migrate_uci('multiap','controller','enabled')
migrate_uci('multiap','agent','enabled')

migrate_uci('multiap','agent','controller_reached_once')

-- Migrate island protection states
v=n:get('multiap','island_protection')
if (v ~= nil) then
  echo_debug("Migrating island_protection...")
  migrate_uci('multiap','island_protection','bss_list')
end

-- Migrate FH creds

echo_debug("Migrating Cred0...")
migrate_uci('multiap','cred0','ssid')
migrate_uci('multiap','cred0','wpa_psk_key')
migrate_uci('multiap','cred0','security_mode')
migrate_uci('multiap','cred0','operational_state')
migrate_uci('multiap','cred0','public_state')

-- Migrate to split SSID for 2G and 5G

echo_debug("Migrating Cred1...")

local cpy_frm = 'cred0'
v = o:get('multiap','cred1','state')
if (v == '1') then
  cpy_frm = 'cred1'
  echo_debug("split mode active   : Migrate cred1 => cred1 ")
else
  echo_debug("split mode inactive : Migrate cred0 => cred1 ")
end

v = o:get('multiap',cpy_frm,'ssid') safe_uci_set('multiap','cred1','ssid',v)
v = o:get('multiap',cpy_frm,'wpa_psk_key') safe_uci_set('multiap', 'cred1', 'wpa_psk_key',v)
v = o:get('multiap',cpy_frm,'security_mode') safe_uci_set('multiap', 'cred1', 'security_mode',v)
v = o:get('multiap',cpy_frm,'operational_state') safe_uci_set('multiap','cred1','operational_state',v)
v = o:get('multiap',cpy_frm,'public_state') safe_uci_set('multiap','cred1','public_state',v)

-- Migrate BH creds

echo_debug("Migrating Cred2...")
migrate_uci('multiap','cred2','ssid')
migrate_uci('multiap','cred2','wpa_psk_key')
migrate_uci('multiap','cred2','security_mode')
migrate_uci('multiap','cred2','operational_state')
migrate_uci('multiap','cred2','public_state')

v = n:get('multiap', 'cred3')
if(v ~= nil) then
  echo_debug("Migrating Cred3...")
  migrate_uci('multiap','cred3','ssid')
  migrate_uci('multiap','cred3','wpa_psk_key')
  migrate_uci('multiap','cred3','security_mode')
  migrate_uci('multiap','cred3','operational_state')
  migrate_uci('multiap','cred3','public_state')
end

v = n:get('multiap', 'cred4')
if(v ~= nil) then
  echo_debug("Migrating Cred4...")
  migrate_uci('multiap','cred4','ssid')
  migrate_uci('multiap','cred4','wpa_psk_key')
  migrate_uci('multiap','cred4','security_mode')
  migrate_uci('multiap','cred4','operational_state')
  migrate_uci('multiap','cred4','public_state')
end

n:commit('multiap')
