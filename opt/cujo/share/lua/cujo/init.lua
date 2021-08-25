--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local function errhandler(err)
    io.stderr:write(string.format('init error: %s\n', debug.traceback(err, 2)))
    os.exit(1)
end

local function load_and_start()
    local path = assert(package.searchpath('cujo.rabid', package.path))
    local rabid_start = assert(loadfile(path))()
    rabid_start()
end

require'coutil.spawn'.catch(errhandler, 'startup-loader', load_and_start)
require'coutil.socket'.run()
