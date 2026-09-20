--Configration table for the different default and eth3 wan
--the first level is config file
--the second level is sectionname
--the third level is for specific options:
--  Each item table represents one parameter for setting or delete
--   #1 string or table - when type is a table, it means this parameter is in anonymous section, @1 is sectiontype
--   #2 string or table - the default network value
--   #3 string or table - the network value for eth3 wan
-- keyworks .set, .add. .del are operations
local config_maps = {
    network = {
        lan = {
            {"ifname", "eth0 eth1 eth2 eth3", "eth0 eth1 eth2"}
        },
        wan = {
            {"ifname", {[".del"] = "eth3"},  {[".add"] = "eth3"}},
        },
    },
}

return config_maps

