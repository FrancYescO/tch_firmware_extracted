--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2017 - 2018     Technicolor Delivery Technologies, SAS **
** - All Rights Reserved                                                **
** Technicolor hereby informs you that certain portions                 **
** of this software module and/or Work are owned by Technicolor         **
** and/or its software providers.                                       **
** Distribution copying and modification of all such work are reserved  **
** to Technicolor and/or its affiliates, and are not permitted without  **
** express written authorization from Technicolor.                      **
** Technicolor is registered trademark and trade name of Technicolor,   **
** and shall not be used in any manner without express written          **
** authorization from Technicolor                                       **
*************************************************************************/
--]]

local require = require
local ipairs = ipairs
local logger = require("tch.logger")
local lfs = require("lfs")

--document the "hidden" dependencies so they show up in the dependency diagram
--$ require "lcm.execenv.opkg"
--$ require "lcm.execenv.lxc_opkg"
--$ require "lcm.execenv.memory"

local s_execenvs = {}
local s_index_by_name = {}

local M = {}

local function valid_ee_api(ee)
  return ee.list and
         ee.install and
         ee.start and
         ee.stop and
         ee.uninstall and
         ee.executing and
         ee.inspect and
         ee.specs
end

function M.init(config)
  if config and type(config.execution_environments) == "table" then
    for _, ee_name in ipairs(config.execution_environments) do
      logger:debug("Loading execution environment %s", ee_name)
      local ee_type = config[ee_name] and config[ee_name][".type"]
      local ee
      if not ee_type then
        logger:error("Couldn't find an execenv type for %s", ee_name)
      else
        local ok, ee_type_module = pcall(require, "lcm.execenv."..ee_type)
        if ok and ee_type_module then
          ee = ee_type_module.init(config[ee_name])
          if not ee then
            logger:error("Failed to load execenv type for %s [type: %s]", ee_name, ee_type)
          end
        else
          logger:error("Couldn't load the execenv type for %s [type: %s]", ee_name, ee_type)
        end
      end
      if ee and not valid_ee_api(ee) then
        logger:error("EE loaded for %s doesn't meet the API requirements.", ee_name)
        ee = nil
      end
      if ee then
        if lfs.attributes("/tmp/lcm_" .. ee.specs.name, "mode") ~= "directory" then
          local ok = lfs.mkdir("/tmp/lcm_" .. ee.specs.name)
          if not ok then
            logger:error("Failed to create tmpdir for EE: %s", ee.specs.name)
            ee = nil
          end
        end
      end
      if ee then
        s_execenvs[#s_execenvs + 1] = ee
        local name = ee.specs.name
        s_index_by_name[name] = ee
      end
    end
  else
    logger:info("No execution environments found to load.")
  end
end

function M.query(name)
  if name then
    return s_index_by_name[name]
  end
  return s_execenvs
end

return M
