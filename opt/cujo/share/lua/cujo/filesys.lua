--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

cujo.filesys = {}

-- These api are public and can be used in configurations
-- They assume touch, rm, mkdir are available
function cujo.filesys.mkdir(path) os.execute('mkdir -p ' .. path) end
function cujo.filesys.touch(path) os.execute('touch ' .. path) end
function cujo.filesys.rm(path) os.execute('rm -f ' .. path) end

function cujo.filesys.readfrom(path, what)
	local file, err = io.open(path)
	if file == nil then return nil, err end
	local contents, err = file:read(what or 'l')
	file:close()
	return contents, err
end
