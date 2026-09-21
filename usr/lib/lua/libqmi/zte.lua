local Mapper = {}
Mapper.__index = Mapper

local M = {}

function Mapper:get_device_capabilities(device, info)
    if device.pid == "0257" then
        for i=#info.radio_interfaces,1,-1 do
            local radio = info.radio_interfaces[i]
            if radio.radio_interface == "auto" then
                table.remove(info.radio_interfaces, i)
            elseif radio.radio_interface == "lte" then
                radio.supported_bands = nil
            end
        end
    end
end

function M.create(pid)
    local mapper = {
        mappings = {
            get_device_capabilities = "augment"
        }
    }

    setmetatable(mapper, Mapper)
    return mapper
end

return M
