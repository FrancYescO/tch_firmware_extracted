--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

-- luacheck: globals debug
-- luacheck: read globals debug_logging
function debug(...)
    if debug_logging then
        print(string.format(...))
    end
end
