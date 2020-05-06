--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2016 - 2016  -  Technicolor Delivery Technologies, SAS **
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

---
-- A module that contains the verification logic for a filesystem path.
--
-- @module modules.verifier.filesystem_path

local type, error = type, error

local match = string.match

local cli_input = require("verifier.cli_input")
-- TODO create an explicit string type verifier.

-- paths for access control are hard-coded for now
-- these should match the paths specified in completer/file_systempath
local access_paths = {
  "/var/log/",
}

local function raise_error()
  error("No valid file system path")
end

local function raise_error_no_access()
  error("No read access to this path")
end

local function validate_access(input)
  local access = false
  for _, ap in ipairs(access_paths) do
    -- Two checks needed: input may be shorter or longer than access path.
    -- Background: the second check is needed to make the filesystem_path completer work properly for e.g.
    --   `/va` -> `/var/log/`. This yields a concer however:
    --   It does not block access to e.g. a file `/va`, which matches partially with /var/log.
    --   To be further investigated on how we can improve this.
    if match(input, ap) or match(ap, input) then
      access = true
      break
    end
  end
  if not access then
    raise_error_no_access()
  end
end

--- Verify if the given input is a valid file system path.
--
-- @param input The input we need to verify.
-- @treturn string If the input is valid, it is returned.
-- @error No valid file system path.
--
local function verify(input)
  -- Other verifiers will raise an error if input is invalid
  cli_input(input)

  if type(input) ~= "string" then
    raise_error()
  else
    validate_access(input)
  end

  return input
end

return verify
