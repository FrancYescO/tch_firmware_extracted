-- This config file is provided for VoiceService.VoiceProfile.Line.map
-- The key is service type, content is table for providing default activities

-- Append table
-- This table is defined for the services when a new profile is added,
-- if the service type section is existed, the new profile is added in the current service section
-- if the service type is not existed, a new service section is created
-- Hence, the service provisioning in the table can be configed per gateway
local append_cfg = {
    HOLD = {
        provisioned = "1",
        activated = "1",
    },
}

-- Add table
-- This table is defined for the services when a new profile is added,
-- whether the service type is existed or not, a new service section configuration is created.
-- Hence, the service provisioning in the table can be configed per profile
local add_cfg = {
    ACR = {
        provisioned = "1",
        activated = "0",
    },
    CLIP = {
        provisioned = "1",
        activated = "1",
    },
    CFBS = {
        provisioned = "1",
        activated = "0",
    },
    CFNR = {
        provisioned = "1",
        activated = "0",
        timeout = "60",
    },
    CFU = {
        provisioned = "1",
        activated = "0",
    },
    CLIR = {
        provisioned = "0",
        activated = "0",
    },
    CALL_RETURN = {
        provisioned = "1",
        activated = "0",
    },
    MWI = {
        provisioned = "0",
        activated = "0",
    },
}

-- This talbe is all the default configuration for services
-- append  - is key for append table
-- add     - is key for add table
local services_default_cfg = {
    append = append_cfg,
    add = add_cfg
}

local profile_default = {
    services = services_default_cfg,
}
return profile_default

