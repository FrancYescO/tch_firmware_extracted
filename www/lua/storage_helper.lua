local storage = {}

local function store(key, value)
    storage[key] = value
end

local function retrieve(key, value)
    return storage[key]
end

local M = { store = store, retrieve = retrieve }

return M
