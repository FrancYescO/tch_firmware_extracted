-- This config file is provided for service modification or addition or deletion via TR-069 / GUI
-- The key is service type, content is table for providing default activities

-- Append table
-- This table is defined for the services when a new profile is added,
-- if the service type section is existing, the new profile is added in the current service section
-- if the service type is not existing, a new service section is created
-- Hence, the service provisioning in the table can be configured per gateway
local append_cfg = {
    HOLD = {
        provisioned = "1",
        activated = "1",
        servicetype = "profile"
    },
    MWI = {
        provisioned = "1",
        activated = "1",
        servicetype = "profile"
    },
    CLIP = {
        provisioned = "1",
        activated = "1",
        servicetype = "profile"
    },
    CLIR = {
        provisioned = "0",
        activated = "0",
        servicetype = "profile"
    },
}

-- Add table
-- This table is defined for the services when a new profile is added,
-- whether the service type is existing or not, a new service section configuration is created.
-- Hence, the service provisioning in the table can be configed per profile/device
local add_cfg = {
}

-- This table is all the default configuration for services
-- append  - is key for append table
-- add     - is key for add table
local services_default_cfg = {
    append = append_cfg,
    add = add_cfg,
    named_service_section = false
}

-- This table list the profile priority for outgoing map
local outgoingmap_order = {
    sip_profile = '1',
    fxo_profile = '2'
}

-- This table list default values for dial plan
local dial_plan_entry_default = {
    dial_plan = 'dial_plan_generic',
    enabled = '1',
    allow = '1',
    include_eon = '0',
    priority = 'high',
    data = '0',
    apply_forced_profile = '1',
    min_length = '3',
    max_length = '30',
    position_of_modify = '0',
    remove_number_of_characters = '3',
    insert = '',
}

local function dial_plan_pattern_generator(id)
    return '^*' .. (id+1) .. '*'
end

local profile_default = {
    services = services_default_cfg,
    outgoingmap_order = outgoingmap_order,
    f_port_enabled = false, --for iinet the mmpbxbrcmfxonet.fxo_profile.enabled should not be changed to disable
    dial_plan_entry_default = dial_plan_entry_default,
    dial_plan_pattern_generator = dial_plan_pattern_generator,
    naming_rule = "firstAvailableId",
}

return profile_default

