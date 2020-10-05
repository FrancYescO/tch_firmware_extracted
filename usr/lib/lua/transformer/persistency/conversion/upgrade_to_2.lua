--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local function convert(db)
  db:execSql([[
    CREATE TABLE IF NOT EXISTS objects2 (
      id INTEGER PRIMARY KEY,
      tp_id INTEGER NOT NULL REFERENCES typepaths(tp_id)
        ON DELETE CASCADE
        ON UPDATE RESTRICT,
      ireferences TEXT NOT NULL,
      key TEXT NOT NULL,
      parent INTEGER REFERENCES objects2(id)
        ON DELETE CASCADE
        ON UPDATE RESTRICT,
      alias TEXT,

      UNIQUE (tp_id, ireferences),
      UNIQUE (tp_id, key),
      UNIQUE (tp_id, parent, alias)
    );
  ]])

  db:execSql([[
    INSERT INTO objects2(id, tp_id, ireferences, key, parent)
      SELECT id, tp_id, ireferences, key, parent
      FROM objects;
  ]])

  db:execSql("DROP TABLE objects;")
  db:execSql("ALTER TABLE objects2 RENAME TO objects;")
  db:execSql("PRAGMA user_version=2;")
end

return {
  convert = convert
}
