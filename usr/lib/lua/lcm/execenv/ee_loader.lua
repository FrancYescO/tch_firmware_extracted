local require, type, ipairs, pcall = require, type, ipairs, pcall

local M = {}

--document the "hidden" dependencies so they show up in the dependency diagram
--$ require "lcm.execenv.opkg"
--$ require "lcm.execenv.lxc_opkg"
--$ require "lcm.execenv.memory"

M.load_ee = function(ee_name)
  local uci = require("uci")
  -- The global UCI_CONFIG can be set when running tests. If set we want to
  -- use it. Otherwise it's nil and the context is created with the default conf_dir.
  local cursor = uci.cursor(UCI_CONFIG)
  local uci_config = cursor:get("lcmd.daemon_config.execution_environments")
  if uci_config and type(uci_config) == "table" then
    for _, execenv_name in ipairs(uci_config) do
      if execenv_name == ee_name then
        -- A configuration has been found
        uci_config = cursor:get_all("lcmd." .. ee_name)
        if uci_config and uci_config[".type"] then
          local ok, ee_type = pcall(require, "lcm.execenv."..uci_config[".type"])
          if ok and ee_type then
            return ee_type.init(uci_config)
          end
        end
      end
    end
  end
end

return M