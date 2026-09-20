local M = {}

-- Update the list of wan interfaces
--   1. remove "eth4", "vlan_data" and "atm_wan" from the wan interface list
--   2. add a new wan interface into the list
--
--   currifname: current interface list
--   wanifname: the wan interface to be added inside the list
local function update_ifname(currifname, wanifname)
   local new_intf
   if currifname == nil then
      return wanifname
   end

   new_intf = currifname
   if type(new_intf) == "string" then
      -- remove "eth4", "vlan_data" and "atm_wan"
      new_intf = new_intf:gsub("eth4", "")
      new_intf = new_intf:gsub("vlan_data", "")
      new_intf = new_intf:gsub("atm_wan", "")
      new_intf = new_intf:gsub("^%s*(.-)%s*$", "%1")
      -- add new wan interface
      new_intf = (new_intf == "" and wanifname) or new_intf .. " " .. wanifname
   else
      for key,itr in pairs(new_intf) do
         if itr == "eth4" or itr == "vlan_data" or itr == "atm_wan"then
            new_intf[key] = nil
         end
      end
      table.insert(new_intf, wanifname)
      end
   return new_intf
end

function M.entry(runtime)
   local uci = runtime.uci
   local conn = runtime.ubus

   if not uci or not conn then
      return false
   end

   local x = uci.cursor()

   -- bring down the data interface
   conn:call("network.interface.wan", "down", { })

   -- bring down the video interface
   conn:call("network.interface.iptv", "down", { })

   -- bring down the voice interface
   conn:call("network.interface.voip", "down", { })

   -- bring down the management interface
   conn:call("network.interface.mgmt", "down", { })

   x:commit("network")

   return true
end

function M.exit(runtime, l2type)
   local uci = runtime.uci
   local conn = runtime.ubus

   if not uci or not conn then
      return false
   end

   local x = uci.cursor()
   local current_wanifs = x:get("network", "wan", "ifname")
   if l2type == "ETH" then
      x:set("network", "wan", "ifname", update_ifname(current_wanifs, "eth4"))
      x:delete("network", "vlan_data", "type")
      x:delete("network", "vlan_data", "vid")
      x:delete("network", "vlan_data", "ifname")
      x:set("network", "vlan_data", "name","phy_eth4")

      x:set("network", "iptv", "ifname", "vlan_iptv")
      x:set("network", "vlan_iptv", "type", "8021q")
      x:set("network", "vlan_iptv", "ifname", "eth4")
      x:set("network", "vlan_iptv", "name", "vlan_iptv")

      x:set("network", "voip", "ifname", "vlan_voip")
      x:set("network", "vlan_voip", "type", "8021q")
      x:set("network", "vlan_voip", "ifname", "eth4")
      x:set("network", "vlan_voip", "name", "vlan_voip")

      x:set("network", "mgmt", "ifname", "vlan_mgmt")
      x:set("network", "vlan_mgmt", "type", "8021q")
      x:set("network", "vlan_mgmt", "ifname", "eth4")
      x:set("network", "vlan_mgmt", "name", "vlan_mgmt")
      x:set("network", "vlan_mgmt", "vid", "294")

   elseif l2type == "VDSL" then
      x:set("network", "wan", "ifname", update_ifname(current_wanifs, "vlan_data"))

      x:set("network", "vlan_data", "type", "8021q")
      x:set("network", "vlan_data", "vid", "835")
      x:set("network", "vlan_data", "ifname", "ptm0")
      x:set("network", "vlan_data", "name","vlan_data")

      x:set("network", "iptv", "ifname", "vlan_iptv")
      x:set("network", "vlan_iptv", "type", "8021q")
      x:set("network", "vlan_iptv", "ifname", "ptm0")
      x:set("network", "vlan_iptv", "name", "vlan_iptv")

      x:set("network", "voip", "ifname", "vlan_voip")
      x:set("network", "vlan_voip", "type", "8021q")
      x:set("network", "vlan_voip", "ifname", "ptm0")
      x:set("network", "vlan_voip", "name", "vlan_voip")

      x:set("network", "mgmt", "ifname", "vlan_mgmt")
      x:set("network", "vlan_mgmt", "type", "8021q")
      x:set("network", "vlan_mgmt", "ifname", "ptm0")
      x:set("network", "vlan_mgmt", "name", "vlan_mgmt")
      x:set("network", "vlan_mgmt", "vid", "834")

      x:set("xtm","ptm0", "ptmdevice")
      x:set("xtm","ptm0", "path","fast")
      x:set("xtm","ptm0", "priority","low")
      x:commit("xtm")
      os.execute("/etc/init.d/xtm reload")

   elseif l2type == "ADSL" then
      x:set("network", "wan", "ifname", update_ifname(current_wanifs, "atm_wan"))
      x:set("network", "vlan_data", "name","atm_wan")
      x:delete("network", "vlan_data", "type")
      x:delete("network", "vlan_data", "ifname")

      x:set("network", "iptv", "ifname", "atm_iptv")
      x:set("network", "vlan_iptv", "name","atm_iptv")
      x:delete("network", "vlan_iptv", "type")
      x:delete("network", "vlan_iptv", "ifname")

      x:set("network", "voip", "ifname", "atm_voip")
      x:set("network", "vlan_voip", "name","atm_voip")
      x:delete("network", "vlan_voip", "type")
      x:delete("network", "vlan_voip", "ifname")

      x:set("network", "mgmt", "ifname", "atm_mgmt")
      x:set("network", "vlan_mgmt", "name","atm_mgmt")
      x:delete("network", "vlan_mgmt", "type")
      x:delete("network", "vlan_mgmt", "ifname")

      x:delete("xtm", "ptm0")
      x:commit("xtm")
      os.execute("/etc/init.d/xtm reload")

   end

   x:delete("network", "wan", "auto")
   x:delete("network", "iptv", "auto")
   x:delete("network", "voip", "auto")
   x:delete("network", "mgmt", "auto")
   x:commit("network")

   os.execute("/etc/init.d/network reload")
   conn:call("network.interface.wan", "up", { })
   conn:call("network.interface.iptv", "up", { })
   conn:call("network.interface.voip", "up", { })
   conn:call("network.interface.mgmt", "up", { })

   return true
end

return M

