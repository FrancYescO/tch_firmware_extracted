--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local module = {}

-- These api are public and can be used in configurations
-- They assume touch, rm, mkdir are available
function module.mkdir(path) os.execute('mkdir -p ' .. path) end
function module.touch(path) os.execute('touch ' .. path) end
function module.rm(path) os.execute('rm -f ' .. path) end

function module.readfrom(path, what)
    local file, err = io.open(path)
    if file == nil then return nil, err end
    local contents, err = file:read(what or 'l')
    file:close()
    return contents, err
end

return module
