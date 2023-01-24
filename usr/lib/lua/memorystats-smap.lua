#!/usr/bin/lua

if #arg < 1 then
    print(string.format( "\nUSAGE: %s <filename>\n", arg[0]))
    print("Assumptions:")
    print("\t1. 'cat /proc/<pid>/smaps' lines are included (marks the start of a process's map)")
    print("\t2. There is a line that starts with '#####' after each complete smap (except the last one)\n\n")
    os.exit()
end

-- Only argument is the filename to process
local fName = arg[1]

-- Function parseBlock()
--   Parse and store the items output by smaps for each process that can be
--     totaled (ignores non-numerical data like flags)
--
--   Takes in the set of lines to operate on, the starting index of the block,
--   and the map to store data for
--   Returns true if a block was read, nil if not
local parseBlock = function(raw, idx, map)
    local line = raw[idx]
    if not string.match(line, "%x+%-%x+ [rwxp%-]+ %x+ %x+:%x+ %d+") then
        return nil
    end
    local name = string.match(line, "%x+%-%x+ [rwxp%-]+ %x+ %x+:%x+ %d+%s+(%C+)")
    local heap
    if not name or (name == "[heap]") then
        heap = true
    end
    for index = idx+1,idx+15 do
        line = raw[index]
        key, value = string.match(line, "([%w_]+):%s+(%d+)")
        if key then
            if not map[key] then
                map[key] = 0
            end
            map[key] = map[key] + value
            -- Add to heap totals if this block is on the heap
            if heap then
                key = "heap_" .. key
                if not map[key] then
                    map[key] = 0
                end
                map[key] = map[key] + value
            end
        end
    end
    return true
end

-- Function parseMap()
--   Parse all the blocks in a map and store the name
--
--   Takes in the set of lines for the file and the map to be parsed
local parseMap = function(raw, map)
    local idx = map["start_idx"]
    local line = raw[idx]
    map["name"] = string.match(line, "%x+%-%x+ [rwxp%-]+ %x+ %x+:%x+ %d+%s+(%C+)")
    while idx < map["stop_idx"] and parseBlock(raw, idx, map) do
        idx = idx + 16
    end
end

local lines = {}
local map_list = {}


-- Function parseMap()
--  write the map data to log file
--
--  Takes in the map to be printed and a set of keys for which values are
--  displayed
local printMap = function(map, keys)
    local file = io.open("/root/log/memory.log", "a")
    local heap = map["heap_Size"] == nil and nil or 1
    file:write(string.format("%s: (pid %d)", map["name"], map["pid"]) ..'\n')
    for _,key in ipairs(keys) do
        local heap_stat = ""
        local stat = string.format("%14s:  %7s kB", key, map[key])
        if heap then
            local heap_key = "heap_" .. key
            heap_stat = string.format(",    %19s:  %7s kB", "Heap " .. key, map[heap_key])
        end
        file:write(string.format("\t%s%s", stat, heap_stat)..'\n')
    end
    file:write('\n')
end

-- Read the file in, looking for start/stop markers, parse the data and then
-- write the output to log file
for line in io.lines(fName) do
    lines[#lines+1] = line
    pid = string.match(line, "cat /proc/(%d+)/smaps")
    if (pid) then
        map_list[#map_list+1] = {}
        map_list[#map_list]["start_idx"] = #lines + 1
        map_list[#map_list]["pid"] = pid
    end
    if (#map_list >= 1) and string.match(line, "^#####") then
        map_list[#map_list]["stop_idx"] = #lines - 1
    end
end
map_list[#map_list]["stop_idx"] = #lines
for map_idx = 1,#map_list do
    parseMap(lines, map_list[map_idx])
    --------------------------------------------------------------------
    -- Modify the list below to change the items output by printMap()!!!
    --------------------------------------------------------------------
    printMap(map_list[map_idx], { "Size", "Shared_Clean", "Shared_Dirty", "Private_Clean", "Private_Dirty" })
end

