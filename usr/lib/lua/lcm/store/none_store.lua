
-- This is a dummy store type.
-- It doesn't actually store anything, it only satisfies the store API
-- It is used as a safe fallback and for documentation purposes.
local M = {}


function M.init(location)
  -- initialize the storage layer.
  -- the given location string can be used to determine where to
  -- store the actual data.
  -- As this is a dummy implementation it is completely ignored.
  -- Whatever this function returns will be passed in as the first
  -- argument for the other functions as the store_info parameter.
end

function M.save(store_info, pkg)
  -- save the table pkg to the storage.
  -- the table MUST have a string ID field 
end

function M.list(store_info)
  -- return a list of package ID's in the store
  return {}
end

function M.load(store_info, ID)
  -- load the actual data identified by ID and return it as a table
end

function M.remove(store_info, ID)
  -- remove the given ID from the store.
end

return M