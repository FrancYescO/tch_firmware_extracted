local M = {}

function M.entry(runtime, l2type)
   local logger = runtime.logger

--   logger:notice("The L3Sense entry scripts will build the sense infrastructure on l2type interface " .. tostring(l2type))

   -- setup sensing config
   -- HB: I dont think we need to do much here---
   --     sensing interfaces already build in L2Exit function
   --     real sensing is done in the L3SenseMain function
   
   return true
end

function M.exit(runtime,l2type, transition)
   local logger = runtime.logger
   
--   logger:notice("The L3Exit: transition " .. transition .. " using l2type " .. tostring(l2type))
   
  
   
   return true
end

return M

