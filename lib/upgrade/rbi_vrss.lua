local setmetatable = setmetatable
local ipairs = ipairs
local stdin = io.stdin
local stderr = io.stderr
local print = print

local function printf(fmt, ...)
	print(fmt:format(...))
end

local function die(msg)
	stderr:write(msg, '\n')
	os.exit(1)
end

local Reader = {}
Reader.__index = Reader

---  create a new reader for the given file
-- @param inputFile [FILE] the file to read from
local function newReader(inputFile)
	return setmetatable({
		inputFile = inputFile,
		fileOffset = 0,
		eof = false,
	}, Reader)
end

-- read in a block of data
-- The internal buffer is updated and the fileOffset is set to the offset
-- of the first byte of the buffer.
-- On end of file the _eof property is set
function Reader:_readnext()
	local buf = self._buf
	if buf then
		self.fileOffset = self.fileOffset + #buf
	end
	buf = self.inputFile:read(8192)
	self._buf = buf
	self._eof = (buf == nil)

	-- On platforms with little memory, allocated memory might not be freed
	-- in time if we leave it up to Lua to decide when to do garbage
	-- collection, causing the upgrade to fail because of memory shortage.
	collectgarbage()
	collectgarbage()
end

-- read all remaining data in the file
-- this will cause _eof to be set and fileOffset to reflect the total filesize
function Reader:consumeAll()
	while not self._eof do
		self:_readnext()
	end
end

--- return a number of bytes from the given offset in the file
-- @param offset (number) the offset in the file. This must be >= the current
--    file offset
-- @param length (number) the maximum number of bytes to read
-- @return the number of bytes currently available or nil of no bytes are
--    available
function Reader:_bytesAvailable(offset, length)
	local buf = self._buf
	if not buf or (#buf==0) then
		return
	end
	local fileOffset = self.fileOffset
	if (fileOffset<=offset) and (offset<fileOffset + #buf) then
		local from = offset - fileOffset + 1
		local to = from + (length and (length-1) or #buf)
		return buf:sub(from, to)
	end
end

--- read a number of bytes
-- @param offset (number) the offset in the file >=the current fileoffset
--    (you can not go back)
-- @param size (number) the number of byte to read
-- @return the requested bytes (all of them) or nil, errmsg in case the data
--   is not available
function Reader:pullData(offset, size)
	local data = ''
	while true do
		local buf = self:_bytesAvailable(offset, size-#data)
		if self._eof then
			return nil, "unexpected EOF found"
		end
		if buf then
			if #buf==0 then
				return nil, "Internal read error, no data"
			end
			data = data .. buf
			offset = offset + #buf
			if #data==size then
				return data
			end
		else
			self:_readnext()
		end
	end
end

-- convert the BIG endian bytes to a number
local function mkInt(s)
	local n = 0
	for _, b in ipairs{ s:byte(1, #s)} do
		n = n*256 + b
	end
	return n
end

-- get the version from the given reader
local function readVersion(rdr)
	-- read in the first 32 bytes containing the Linux signature and the
	-- offset to the info blocks
	local s, err = rdr:pullData(0, 32)
	if not s then
		return err
	end

	if s:sub(18, 21)~="LINU" then
		return nil, "not a valid rbi, Linux kernel not detected"
	end
	local offset = mkInt(s:sub(13, 16))		local data = s:sub(5, #s)


	-- read the total size of the info block area. This size includes the 4
	-- byte for the size as well
	s, err = rdr:pullData(offset, 4)
	if not s then
		return nil, err
	end
	local infoSize = mkInt(s)
	if infoSize<12 then
		-- the minimum size is 12 for the infoblocks containing a single
		-- info block with no data
		return nil, "invalid size for info blocks"
	end

	local infoEnd = offset+infoSize

	-- read in the info block until VRSS is found ar the end is reached
	offset = offset + 4
	while offset<infoEnd do
		-- read the size of the current info block
		s, err = rdr:pullData(offset, 4)
		if not s then
			return err
		end
		local size = mkInt(s)
		if offset+size>infoEnd then
			return nil, "invalid size for infoblock"
		end
		-- read in the reset of the info block. note that size again include
		-- the 4 bytes used to store the size.
		s, err = rdr:pullData(offset+4, size-4)
		if not s then
			return err
		end
		local id = s:sub(1,4)
		local info
		if id == 'VRSS' then
			-- We found the version. Info block data is always a multiple of 4
			-- bytes so the version is padded with NUL bytes at the end.
			-- so remove them.
			return s:sub(5, #s):gsub("%z*", "")
		end
		-- skip to the next block
		offset = offset+size
	end
	return '-'
end

--- process the given filename (or stdin)
-- OUTPUT:
--   print out the total filesze and VRSS content found.
--   If no VRSS infoblock is present output just a dash
-- RETURN
--   The exit code will be zero if infoblocks can be found or one if not
local function main(filename)
	local infile = stdin
	if filename then
		local err
		infile, err = io.open(filename, 'rb')
		if not infile then
			die(err)
		end
	end
	local version = "-"
	local rdr = newReader(infile)
	local version, err = readVersion(rdr)
	if not version then
		die(err)
	end
	rdr:consumeAll()
	infile:close()
	printf("%d %s", rdr.fileOffset, version)
end

main(arg[1])
