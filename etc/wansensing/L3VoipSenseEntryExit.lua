local M = {}

function M.entry(runtime)
   local uci = runtime.uci
   local conn = runtime.ubus
   local logger = runtime.logger
   local x = uci.cursor()

   -- initialize a flag indicating the beginning of an interval
   runtime.voip_checkinterval_begin = true

   -- no need to build the sense configuration if the previous l3type was me
   local origL3 = x:get("wansensing", "global", "l3type")
   if origL3 == "L3VoipSense" then
      return true
   end

   logger:notice("Establishing voip connectivity to check TELENOR/IPSE mode")

   x:set("network", "voip", "auto", '1')
   x:commit("network")

   x:set("mwan", "voip_only", "interface", "voip")
   x:commit("mwan")

   -- this reload + up of wan will reload mwan rules too
   conn:call("network", "reload", { })
   conn:call("network.interface.voip", "up", { })

   return true
end

function M.exit(runtime, l2type)
   runtime.voip_checkinterval_begin = false
   return true
end

return M
