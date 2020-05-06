#!/usr/bin/env lua

-- ************* COPYRIGHT AND CONFIDENTIALITY INFORMATION **********************
-- -- **                                                                          **
-- -- ** Copyright (c) 2013 Technicolor                                           **
-- -- ** All Rights Reserved                                                      **
-- -- **                                                                          **
-- -- ** This program contains proprietary information which is a trade           **
-- -- ** secret of TECHNICOLOR and/or its affiliates and also is protected as     **
-- -- ** an unpublished work under applicable Copyright laws. Recipient is        **
-- -- ** to retain this program in confidence and is not permitted to use or      **
-- -- ** make copies thereof other than as permitted in a written agreement       **
-- -- ** with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS. **
-- -- **                                                                          **
-- -- ******************************************************************************

local runtime = { }
local M = {}

local popen = io.popen
local open = io.open


function M.exec_at_cmd(at_device_ctrl, at_cmd, timeOut)
        local result = {}
        timeOut=timeOut or (10*60*5)
        print("--exec_at_cmd::at_device_ctrl=", at_device_ctrl," at_cmd=", at_cmd, " timeout=", timeOut)
        local f = popen (string.format("MBD_TO_MAX=\"%s\" MBD_AT_CMD=\"%s\" gcom -s -d /dev/%s /etc/gcom/at_cmd.gcom",
                     timeOut, at_cmd, at_device_ctrl) )

        if f == nil then
                return result
        end

        -- parse line
        local at_output = f:read("*a")
        if (at_output == nil) then
                f:close()
                return {}
        end

        print("==start-raw: " .. at_output .. " :end-raw==")
        result=at_output
  
        f:close()
        return result
end

function M.at_info_cmd(at_ctrl, cmd)
  local rv = M.exec_at_cmd(at_ctrl, cmd)
  runtime.tprint(rv)
  runtime.log:debug(string.format("%s :: rv=%s", cmd, rv))
  return rv
end

function M.init (rt)
   runtime = rt
end

return M
