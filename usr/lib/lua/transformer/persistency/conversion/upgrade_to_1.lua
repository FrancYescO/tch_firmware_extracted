--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local xpcall = pcall
local pathfinder = require 'transformer.pathfinder'

local last_id = 0

local function convert_typepath_info(db)
  local info = {}

  local paths = db:execSql(
    "select distinct typepath from objects;",
    nil,
    {}
  )

  for _, row in ipairs(paths) do
    local path = row.typepath
    local subpaths = {}
    for p in path:gmatch("([^.]*)%.") do
      if pathfinder.isMultiInstance(p) then
        subpaths[#subpaths] = {subpaths[#subpaths][1]..p..'.', true}
      else
        subpaths[#subpaths+1] = {p..'.', false}
      end
    end
    local fullpath=""
    local parent_id = 0 --root
    for _, p in ipairs(subpaths) do
      fullpath = fullpath..p[1]
      local id = info[fullpath]
      if not id then
        id = last_id + 1
        last_id = id
        db:execSql([[
          INSERT INTO typepaths(tp_id, typepath_chunk, parent, is_multi)
          VALUES( :id, :chunk, :parent, :multi)
        ]],
        {
          id = id,
          chunk = p[1],
          parent = parent_id,
          multi = p[2] and 1 or 0
        })
        info[fullpath] = id
      end
      parent_id = id
    end
  end
  return info
end

local function copy_objects(db, typepaths)
  local rows = db:execSql([[
    SELECT id, typepath, ireferences, key, parent
    FROM objects
    ORDER BY id;
  ]],
  nil,
  {})
  for _, row in ipairs(rows) do
    row.tp_id = typepaths[row.typepath]
    db:execSql([[
      INSERT INTO new_objects(id, tp_id, ireferences, key, parent)
      VALUES( :id, :tp_id, :ireferences, :key, :parent);
    ]],
    row)
  end
end

local function convert(db)
  db:execSql([[
    CREATE TABLE IF NOT EXISTS typepaths (
      tp_id INTEGER PRIMARY KEY,
      typepath_chunk VARCHAR NOT NULL,
      parent INTEGER REFERENCES typepaths(tp_id)
        ON DELETE CASCADE
        ON UPDATE RESTRICT,
      is_multi BOOLEAN NOT NULL
    );
  ]])
  db:execSql([[
    INSERT OR IGNORE
    INTO typepaths(
      tp_id, typepath_chunk, is_multi)
    VALUES(
      0, "(root)", 0
    );
  ]])
  local tp = convert_typepath_info(db)

  db:execSql( [[
    CREATE TABLE IF NOT EXISTS new_objects (
      id INTEGER PRIMARY KEY,
      tp_id INTEGER NOT NULL REFERENCES typepaths(tp_id)
        ON DELETE CASCADE
        ON UPDATE RESTRICT,
      ireferences TEXT NOT NULL,
      key TEXT NOT NULL,
      parent INTEGER REFERENCES new_objects(id)
        ON DELETE CASCADE
        ON UPDATE RESTRICT,

      UNIQUE (tp_id, ireferences),
      UNIQUE (tp_id, key)
    );
  ]])
  copy_objects(db, tp)

  db:execSql("DROP TABLE objects;")
  db:execSql("ALTER TABLE new_objects RENAME TO objects;")

  db:execSql("PRAGMA user_version=1;")
end

return {
  convert=function(db)
    function doit()
      return convert(db)
    end
    xpcall(doit, function(err)
      print(debug.traceback(err))
    end)
  end
}
