local M = {}
--[[************* COPYRIGHT AND CONFIDENTIALITY INFORMATION ***************
--** Copyright © 2014 - 2016 TECHNICOLOR DELIVERY TECHNOLOGIES, SAS       **
--** - All Rights Reserved                                                **
--** Technicolor hereby informs you that certain portions                 **
--** of this software module and/or Work are owned by Technicolor         **
--** and/or its software providers.                                       **
--** Distribution copying and modification of all such work are reserved  **
--** to Technicolor and/or its affiliates, and are not permitted without  **
--** express written authorization from Technicolor.                      **
--** Technicolor is registered trademark and trade name of Technicolor,   **
--** and shall not be used in any manner without express written          **
--** authorization from Technicolor                                       **
--*************************************************************************
--]]

function M.entry(runtime)
   -- initialize ltebackup_delay_counter
   runtime.ltebackup_delay_counter = 0
   return true
end

function M.exit(runtime, l2type)
   local uci = runtime.uci

   local x = uci.cursor()
   local origL2 = x:get("wansensing", "global", "l2type")

   if l2type == "ETH" then
      -- update the 802.1p qos value in Ethwan connection 
      x:set("qos","IPTV","pcp","4")
      x:set("qos","VoIP_traffic","pcp","5")
      x:commit("qos")
      os.execute("/etc/init.d/qos reload")

   elseif l2type == "VDSL" then
      -- Apply the BRCM WA
      -- avoid to reload xtm if sensed l2type is not changed
      if origL2 ~= l2type then
         x:set("xtm","ptm0", "ptmdevice")
         x:set("xtm","ptm0", "path","fast")
         x:set("xtm","ptm0", "priority","low")
         x:commit("xtm")
         os.execute("/etc/init.d/xtm reload")
      end
      -- 802.1p qos value no need to be set in VDSL connection
      x:delete("qos","IPTV","pcp")
      x:delete("qos","VoIP_traffic","pcp")
      x:commit("qos")
      os.execute("/etc/init.d/qos reload")

   elseif l2type == "ADSL" then
      -- Apply the BRCM WA
      -- avoid to reload xtm if sensed l2type is not changed
      if origL2 ~= l2type then
         x:delete("xtm", "ptm0")
         x:commit("xtm")
         os.execute("/etc/init.d/xtm reload")
      end

   end
   runtime.ltebackup_curl_delay_counter_value = 5
   runtime.ltebackup_curl_delay_counter = 0
   return true
end

return M

