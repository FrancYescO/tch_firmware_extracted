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
        switch_vlan = {
            {{"vlan", "1", ".set"}, {ports = "0* 1* 2* 3* 5* 8t"}, {ports = "0* 1* 2* 5* 8t"}},
            {{"vlan", "2", ".add"}, nil, {device = "bcmsw_ext", vlan = "2", ports = "3* 8t"}},
        },
        vlan_eth3 = {
            {"vid", "1", "2"},
        },
        lan = {
           {"ifname", "vlan_eth0 vlan_eth1 vlan_eth2 vlan_eth3 vlan_eth5", "vlan_eth0 vlan_eth1 vlan_eth2 vlan_eth5"},
        },
        wan = {
            {"ifname", {[".del"] = "vlan_eth3"},  {[".add"] = "vlan_eth3"}},
            {"type", {[".del"] = "bridge"}, {[".add"] = "bridge"}},
        },
        phy_eth3 = {
            {"mtu", "1500",  "1538"}},
    },
}

return config_maps

