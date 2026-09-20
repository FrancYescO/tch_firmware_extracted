
local error = error
local concat = table.concat

local M = {}

local faultDefs = {
    RequestDenied = 9001;
    InternalError = 9002;
    InvalidArguments = 9003;
    InvalidName = 9005;
    InvalidType = 9006;
    InvalidValue = 9007;
    InvalidWrite = 9008;
}

--- make a constant name
-- ie all uppercase and with underscores
-- so RequestDenied becomes REQUEST_DENIED
-- @param name the Upper camel case name to convert (must start with uppercase
--   letter !!)
local function makeConstantName(name)
    local parts = {}
    for part in name:gmatch("([A-Z][a-z0-9]*)") do
        parts[#parts+1] = part:upper()
    end
    return concat(parts, '_')
end

-- raise a transformer error
local function raise_error(code, fmt, ...)
    local msg = fmt:format(...)
    error({errcode=code, errmsg=msg})
end


-- fill the module (M) with the constants and functions to raise the
-- transformer error.
for name, errcode in pairs(faultDefs) do
    M[makeConstantName(name)] = errcode
    local function raise(fmt, ...)
        raise_error(errcode, fmt, ...)
    end
    M[name] = raise
end

return M
