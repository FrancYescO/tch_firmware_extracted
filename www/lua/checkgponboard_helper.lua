local lfs = require("lfs")
local M = {}
function M.isGPONBoard()
    local result = false
    if lfs.attributes("/proc/rip/011b", "mode") == "file" then
	local fd = process.popen("hexdump", { "-n", "1", "/proc/rip/011b"})
        if fd then
	    for line in fd:lines() do
		local type = line:match("%w+%s+(%w+)")
		if type then
		    type = string.sub(type, 1, 2)
		    if type == "01" or type == "02" then
		        result = true
		    end
		end
	    end
	    fd:close()
	end
      end
      return result

end

return M
