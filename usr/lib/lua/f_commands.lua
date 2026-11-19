--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2022 - 2022 -  Technicolor Delivery Technologies, SAS **
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



-- Add the commands in a string format for which you want to restrict to modify from ACS via sts file
local forbidden_cmds = {
    "button%.[^.]+%.handler",
    "button%.[^.]+$",
    "button$"
}

---------------------------------------------------------------------------------------
-- @module Scans the input command from commands list present in table "forbidden_cmds"
--         to ignore setting it to the system if it matches
---------------------------------------------------------------------------------------
local f_commands = {}


---------------------------------------------------------------------------------------
-- scan_for_forbidden
-- @parm command [table] command to parse for ignoring to set
-- return true  - if the input command is defined to ignore in "forbidden_cmds"
-- return false - if the input command is fine to set in  the system
---------------------------------------------------------------------------------------
function f_commands.scan_for_forbidden (cmd)
    local arg
    if cmd.option then
        arg = cmd.config .. "." .. cmd.section .. "." .. cmd.option
    elseif cmd.option == nil and cmd.section then
        arg = cmd.config .. "." .. cmd.section
    else
        -- Input argument is from do_add to add a new section
        arg = cmd[1]
    end
    for _, list in pairs(forbidden_cmds) do
        if arg:match(list) then
            return true
        end
    end
    return false
end

return f_commands
