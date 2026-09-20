--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

--- The access to the transformer database
--[[
The transformer database consists of three tables: typepaths, objects and counters. Transformer
does not access the database directly, it goes through some access functions. These
functions are listed below.

Table: Typepaths
----------------
This table stores all persistent information about typepaths in the datamodel tree.

It has the following fields:
  * tp_id: an auto generated integer (this is the primary key)
  * typepath_chunk: the last chunk of the typepath.
  * parent: the typepath id of the parent typepath.
  * is_multi: if this typepath is a multi-instance typepath or not.

The actual format of the typepath_chunks is of no concern to the db, it are just string. The full typepath
can be found by iterating from a typepath chunk, through the parents untill the root typepath chunk
(indicated by parent id 0). Concatenating in reverse order yields the typepath.
The is_multi is inherently already present in the chunk, but is stored explicitly to avoid unneeded recalculations.

Access functions for the 'typepaths' table:
  * insertTypePath
  * getTypePathChunkByID

Table: Objects
--------------

This table stores all persistent information about object instances in the tree.

It has the following fields:
  * id : an auto generated integer (this is the primary key)
  * tp_id : the type path ID of the object. This references the ID used in the 'typepaths' table. (This is an integer)
  * ireferences : a string representing the instance references (these can be numbers or strings)
  * key : a string representing the key of the object
  * parent : the id of the parent object
  * alias : a string representing the alias of the object

The format and content of ireferences and key is of no concern to the
db, they are always strings.

The combination (tp_id, ireferences) must be unique, the combination
(tp_id, key) must be unique and the combination (tp_id, parent, alias) must be unique.

Access functions for the Objects table:
  * insertObject
  * deleteObject
  * getObject
  * getObjectByKey
  * getObjectByAlias
  * getChildren
  * getSiblings
  * getParents
  * getAlias
  * getAliases
  * setAliasForId
  * setAliasForKey

Table: Counters
---------------

This is a support table that persists the Transformer internal counters that
generate instance numbers.

It has the following fields:
  * parentid : The ID of the parent object in the Objects table. (This is an integer)
  * tp_chunk_id : The typepath chunk ID of the child portion of the typepath (for example: List.{i}. is the child portion of Multi.{i}.List.{i})
                  This references the typepaths table (This is an integer)
  * value : The last used instance number for the <parentid, child> tuple.

The primary key is (parentid, tp_chunk_id).

Access functions for the Counters table:
  * getCount
  * setCount

Additional functions:
---------------------

The following functions are table independent and are exposed to support a higher level
transaction model:
  * startTransaction
  * rollbackTransaction
  * commitTransaction

This file implements these functions on top of SQLite.
This can be changed but the functions must provide the same interface.
--]]


local error = error
local tonumber = tonumber
local tostring = tostring
local concat = table.concat
local pairs = pairs
local ipairs = ipairs
local format = string.format
local pcall = pcall
local setmetatable = setmetatable
local type = type

local DATABASE_USER_VERSION = 2

local M = {
  DATABASE_USER_VERSION = DATABASE_USER_VERSION
}

local logger = require("transformer.logger")
local sqlite = require("lsqlite3")

--- Return the full database path.
-- @param dbpath The directory where the database should reside. Nil is not allowed.
-- @param dbname The optional name of the transformer. If not given, 'transformer.db' is used.
local function get_fulldbpath(dbpath, dbname)
  dbname = dbname or 'transformer.db'
  local fmt
  if dbpath:sub(#dbpath)=='/' then
    fmt="%s%s"
  else
    fmt="%s/%s"
  end
  return fmt:format(dbpath, dbname)
end

--- Raise an error or return a row.
-- @param ok if true return row, otherwise raise error
-- @param result_or_error the result or the error (depending on ok). if ok
--        is false this must be a db error object.
-- This function is designed to take the result of query as input to enable
-- the idiom 'r = check(query{....})' where r is the actual result of the
-- query or an error is raised in case the query failed.
local function check(ok, result_or_error)
  if not ok then
    -- result_or_error is now error
    local fmt="SQL error %d, %s"
    local msg=fmt:format(result_or_error.err, result_or_error.msg)
    error(msg)
  end
  -- result_or_error is now result (but can be nil)
  return result_or_error
end

--[[
--- Print the given row in a debug log.
-- @param row The row that needs to be printed.
-- @param prefix An optional prefix to show in the log. If nil
--        'ROW' will be used.
local function dump_row(row, prefix)
  prefix = prefix or "ROW"
  local s={}
  for k, v in pairs(row) do
    s[#s+1] = format("%s=%s", tostring(k), tostring(v))
  end
  logger:debug("%s: %s", prefix, concat(s, ", "))
end
--]]

--- Create a database error object.
-- @param dbh The database handler to create the error for.
-- @param db_err The SQLite error code.
-- @return A database error object with the following members:
--    err The db_err passed in, normally a SQLite error code.
--    msg A string describing the error for the most recent failed call.
local function make_dberr(dbh, db_err)
  return {err=db_err, msg=dbh:errmsg()}
end

--- Run a SQL statement.
-- @param #table db A database object (containing _handle and _stats members)
-- @param #string sql The text of the SQL statement to execute
-- @param #boolean run_once If true the statement is meant to run only once and its
--    prepared handle is not cached in the given database. If false (the default) the
--    handle is cached and reused for later invocations.
-- @param #table vars A table providing the named parameters of the statement.
--    If the statement has no parameters this can be left out.
-- @param #table results_param A table to append the retrieved rows to. If provided this
--    is also the value result of the function.
--    If this is nil only the first row is returned and it becomes the value
--    result of this function.
-- @return #boolean, #table The boolean will be true if the statement ran without error
--    and false if some error occurred. The table will contain the result if no error occurred
--    or an database error table otherwise.
local function query(db, sql, run_once, vars, results_param)
  local dbh = db._handle
  local db_err

  -- the actual function to call on the statement handle on completion
  -- this will be reset for a cached statement and finalize for a
  -- statement that is to be run only once.
  local reset

  --logger:debug("QUERY: %s", sql)

  -- get the prepared statement handle for the SQL statement
  local stmt = db._stats[sql]
  if stmt then
    reset = stmt.reset
  else
    stmt, db_err = dbh:prepare(sql)
    if run_once then
      reset = stmt and stmt.finalize
    else
      reset = stmt and stmt.reset
      db._stats[sql] = stmt
    end
  end
  if stmt==nil then
    return false, make_dberr(dbh, db_err)
  end

  -- bind the variables, if given
  -- note that the statement will fail if parameters are provided in the SQL
  -- but they are not bound here.
  if vars then
    --dump_row(vars, "VARS")
    db_err = stmt:bind_names(vars)
    if db_err~=sqlite.OK then
      return false, make_dberr(dbh, db_err)
    end
  end

  -- results is initialized from parameter, but replaced with the exact return
  -- value in the step loop. It can get replaced with an error spec
  local results = results_param

  -- ok will be set to false on error. In this case results will be set
  -- to an error spec
  local ok = true

  -- step loop, retrieve all result rows (if any)
  while true do
    db_err = stmt:step()
    if db_err==sqlite.ROW then
      local row = stmt:get_named_values()
      --dump_row(row)
      if results then
        results[#results+1] = row
      else
        -- only interested in the first row
        results = row
        break
      end
    elseif db_err==sqlite.DONE then
      break
    else
      -- some error occured
      ok = false
      results = make_dberr(dbh, db_err)
      --logger:debug("e=%s, msg=%s", results.err, results.msg)
      break
    end
  end
  reset(stmt)
  --logger:debug("DONE %s", ok and "true" or "false")
  return ok, results
end

--- Utility wrapper to execute an SQL statement once.
-- @param db The database to run the SQL statement against.
-- @param sql The SQL statement to execute.
-- @param vars The varibles to plug into the statement
local function execSql(db, sql, vars, results)
  return check(query(db, sql, true, vars, results))
end

local function close(db)
  if db._handle then
    for _, stmt in pairs(db._stats) do
      stmt:finalize()
    end
    db._stats = nil
    db._handle:close()
    db._handle = nil
  end
end


local function dbfile_open(db, dbpath, dbname)
  local convert = require 'transformer.persistency.convert'

  repeat
    local db_ok
    local filepath
    local h, _, errmsg
    if dbpath~=nil then
      filepath = get_fulldbpath(dbpath, dbname)
      h, _, errmsg = sqlite.open(filepath)
    else
      h, _, errmsg = sqlite.open_memory()
    end
    if h==nil then
      error(errmsg)
    end

    -- fill in minimal set to make execSql/query work
    db._handle = h -- The actual handle to the database
    db._stats = {} -- A table containing the prepared SQL statements.

    -- Turn the enforcement of foreign keys on in SQLite.
    -- This is needed for the foreign key clause. (REFERENCES...)
    execSql(db, "PRAGMA foreign_keys=1;")
    -- Use WAL journal mode; measurements have shown this to be faster.
    -- Set locking mode to exclusive so no shared memory wal-index is created;
    -- apparently it doesn't work on target and we don't need it anyhow because
    -- Transformer is the only process accessing the database.
    execSql(db, "PRAGMA locking_mode=EXCLUSIVE;")
    execSql(db, "PRAGMA journal_mode=WAL;")
    execSql(db, "PRAGMA wal_autocheckpoint=128;")


    local temp_db = {
      _handle = h,
      _stats = {},
      execSql=function(...) return execSql(...) end,
      startTransaction=function(self) return execSql(self, "BEGIN") end,
      rollbackTransaction=function(self) return execSql(self, "ROLLBACK") end,
      commitTransaction=function(self) return execSql(self, "COMMIT") end
    }
    if convert.convert(temp_db, DATABASE_USER_VERSION) then
      db_ok = true
    else
      -- converting the database failed. We have no choice but to delete it
      -- and open an empty one
      close(db)
      if filepath then
        os.remove(filepath)
        -- alose remove the wal file
        os.remove(filepath..'-wal')
      end
    end
  until db_ok

  -- make sure the convert module can be garbage collected
  package.loaded['transformer.persistency.convert'] = nil


end


--- Opens an internal database object and populates the required fields.
-- @param db The table in which to create the internal object.
-- @param dbpath The path of the database name. If nil open a memory database.
-- @param dbname The name of the database file. If nil use transformer.db
-- NOTE: This function raises an error if opening the database fails for some reason.
local function open(db, dbpath, dbname)
  dbfile_open(db, dbpath, dbname)


  -- Create typepaths table
  execSql(db, [[
    CREATE TABLE IF NOT EXISTS typepaths (
      tp_id INTEGER PRIMARY KEY,
      typepath_chunk VARCHAR NOT NULL,
      parent INTEGER REFERENCES typepaths(tp_id)
        ON DELETE CASCADE
        ON UPDATE RESTRICT,
      is_multi BOOLEAN NOT NULL
    );
  ]])

  -- Insert root tp_chunk with tp_id 0
  execSql(db, [[
    INSERT OR IGNORE
    INTO typepaths(
      tp_id, typepath_chunk, is_multi)
    VALUES(
      0, "(root)", 0
    );
  ]])

  -- Create named index on typepaths table, so we can drop it later.
  execSql(db, [[
    CREATE UNIQUE INDEX IF NOT EXISTS main.typepath_index ON typepaths (typepath_chunk, parent);
  ]])

  -- Create objects table
  execSql(db, [[
    CREATE TABLE IF NOT EXISTS objects (
      id INTEGER PRIMARY KEY,
      tp_id INTEGER NOT NULL REFERENCES typepaths(tp_id)
        ON DELETE CASCADE
        ON UPDATE RESTRICT,
      ireferences TEXT NOT NULL,
      key TEXT NOT NULL,
      parent INTEGER REFERENCES objects(id)
        ON DELETE CASCADE
        ON UPDATE RESTRICT,
      alias TEXT,

      UNIQUE (tp_id, ireferences),
      UNIQUE (tp_id, key),
      UNIQUE (tp_id, parent, alias)
    );
  ]])

  -- Create counters table
  execSql(db, [[
    CREATE TABLE IF NOT EXISTS counters (
      parentid INTEGER NOT NULL,
      tp_chunk_id INTEGER NOT NULL,
      value INTEGER NOT NULL,

      PRIMARY KEY(parentid, tp_chunk_id),
      FOREIGN KEY(parentid) REFERENCES objects(id)
        ON DELETE CASCADE
        ON UPDATE RESTRICT,
      FOREIGN KEY(tp_chunk_id) REFERENCES typepaths(tp_id)
        ON DELETE CASCADE
        ON UPDATE RESTRICT
    );
  ]])

  execSql(db, string.format("PRAGMA user_version=%d;", DATABASE_USER_VERSION))

  -- We keep track of the row_id of objects internally to avoid the overhead of an extra
  -- query to the database after an INSERT statement.
  db._lastid = execSql(db,
    "SELECT MAX(id) as m FROM objects;"
  ).m or 0
  -- We keep track of the row_id of typepaths internally to avoid the overhead of an extra
  -- query to the database after an INSERT statement.
  db._last_tpid = execSql(db,
    "SELECT MAX(tp_id) as m FROM typepaths;"
  ).m or 0
end

local db = {}

--- Close the DB connection
-- After this the object can no longer be used.
function db:close()
  close(self)
end

local transaction = 1

--- Generate a new transaction ID.
-- @return #string A new transaction name is returned, guaranteed to be unique
--                 within one transformer session.
local function generateTransactionName()
  local key = "transaction"..transaction
  transaction = transaction + 1
  return key
end

--- Start a database transaction.
-- @param #boolean outer If the transaction is the outermost transaction or not.
-- @return #string The name of the save point (if any), nil otherwise.
-- SQLite supports nested transactions, but they are called save points. If we are
-- starting an inner transaction, we translate it to a save point.
function db:startTransaction(outer)
  local transaction
  local sqlStatement = "BEGIN"
  if not outer then
    transaction = generateTransactionName()
    sqlStatement = "SAVEPOINT "..transaction
  end
  check(query(self, sqlStatement, true))
  return transaction
end

--- Roll back a previously started transaction.
-- @param #string savepoint The name of the save point to roll back to. If not provided,
--                          the entire transaction stack is rolled back.
-- NOTE: If you provide an unknown save point name, an error will be raised.
function db:rollbackTransaction(savepoint)
  local sqlStatement = "ROLLBACK"
  if savepoint then
    sqlStatement = sqlStatement.." TO "..savepoint
  end
  check(query(self, sqlStatement, true))
end

--- Commit a previously started transaction.
-- @param #string savepoint The name of the save point to be committed. If not provided,
--                          the entire transaction stack is committed.
-- NOTE: If you provide an unknown save point name, an error will be raised.
-- NOTE: Committing an inner transaction actually only merges the transaction with its parent
--       transaction. The outer transaction also needs to be committed before the changes are
--       actually persisted. Committing the outer transaction is equivalent to calling 'COMMIT'.
function db:commitTransaction(savepoint)
  local sqlStatement = "COMMIT"
  if savepoint then
    sqlStatement = "RELEASE "..savepoint
  end
  check(query(self, sqlStatement, true))
end

--- Retrieve the typepath chunk ID of a given typepath chunk and parent ID.
-- @param #table db The database table itself.
-- @param #string tp_chunk The typepath chunk we are interested in.
-- @param #number parent_id The typepath chunk ID of the parent typepath.
-- @return #number The typepath chunk ID is returned if found.
-- @return #nil Nil is returned if no typepath chunk matches the given parameters.
local function getChunkID(db, tp_chunk, parent_id)
  local ok, row_or_e = query(
    db,
    [[
      SELECT tp_id
      FROM typepaths
      WHERE typepath_chunk=:typepath_chunk AND parent=:parent;
    ]],
    false,
    {
      typepath_chunk = tp_chunk,
      parent = parent_id,
    }
  )
  if ok and row_or_e then
    return row_or_e.tp_id
  end
end

--- Insert a typepath chunk into the database.
-- @param #table db The database table itself.
-- @param #table tp_chunk_table The typepath chunk information we wish to insert. This table contains the
--                              chunk itself and if the typepath it represents is a multi-instance typepath.
-- @param #number parent_id The typepath chunk ID of the parent typepath.
-- @return #number The typepath chunk ID is returned if inserted successfully.
-- @return #nil Nil is returned if the insertion of the chunk led to a constraint violation. Any other error
--              will be propagated.
local function insertChunk(db, tp_chunk_table, parent_id)
  local tp_chunk = tp_chunk_table.chunk
  local chunk_id = getChunkID(db, tp_chunk, parent_id)
  if not chunk_id then
    chunk_id = db._last_tpid + 1
    local obj = {
      tp_id = chunk_id,
      typepath_chunk = tp_chunk,
      parent = parent_id,
      is_multi = tp_chunk_table.multi and 1 or 0
    }
    local ok, e = query(
      db,
      [[
        INSERT
        INTO typepaths(
          tp_id, typepath_chunk, parent, is_multi)
        VALUES(
          :tp_id, :typepath_chunk, :parent, :is_multi
        )
      ]],
      false,
      obj
    )
    if not ok then
      if e.err==sqlite.CONSTRAINT then
        return nil, e.msg
      else
        check(false, e)
      end
    end
    db._last_tpid = chunk_id
  end
  return chunk_id
end

--- Insert a typepath into the database.
-- @param #table tp_chunks The typepath we wish to insert divided in chunks. Each entry in the table should contain
--                         another table with a 'chunk' field containing the actual chunk and a 'is_multi' field denoting
--                         if the typepath is a multi-instance typepath or not.
-- @return #number The typepath chunk ID of the last part of the typepath is returned if inserted successfully. If the typepath
--                 couldn't be inserted for any reason, an error is thrown.
function db:insertTypePath(tp_chunks)
  local index = #tp_chunks
  local chunk_id = 0 -- Start at the root
  while index > 0 and chunk_id do
    chunk_id = insertChunk(self, tp_chunks[index], chunk_id)
    index = index - 1
  end
  if not chunk_id or chunk_id == 0 then
    error("No typepath to insert")
  end
  return chunk_id
end

--- Fetch the row in the 'typepaths' table with the given typepath ID.
-- @param #number tp_id The database ID of a type path in the tree.
-- @return #table A table representation of the typepath chunk or nil if not found.
-- There is at most one such row due to the database constraints.
--
-- The table representation has the following layout:
-- {
--   typepath_chunk=...
--   parent=...
--   is_multi=...
-- }
-- The values are the corresponding values retrieved from the DB
function db:getTypePathChunkByID(tp_id)
  local row = check(query(
    self,
    [[
      SELECT tp_id, typepath_chunk, parent, is_multi
      FROM typepaths
      WHERE tp_id=:tp_id
    ]],
    false,
    {tp_id=tp_id}
  ))
  return row
end

--- Fetch the row from the 'objects' table with the given typepath ID and ireferences.
-- @param #number tp_id The database ID of a type path in the tree.
-- @param #string ireferences A representation of the instance references.
-- @return #table A table representation of an object or nil if not found.
-- There is at most one such row due to the database constraints.
--
-- The table representation has the following layout:
-- {
--   id=...
--   tp_id=...
--   ireferences=...
--   key=...
--   parent=...
-- }
-- The values are the corresponding values retrieved from the DB
function db:getObject(tp_id, ireferences)
  local row = check(query(
    self,
    [[
      SELECT id, tp_id, ireferences, key, parent
      FROM objects
      WHERE tp_id=:tp_id AND ireferences=:ireferences
    ]],
    false,
    {tp_id=tp_id, ireferences=ireferences}
  ))
  return row
end

--- Fetch the row from the 'objects' table with the given typepath ID and key.
-- @param #number tp_id The database ID of a type path in the tree.
-- @param #string key The key associated with a certain object instance.
-- @return #table A table representation of an object or nil if not found
-- There will be at most one such row due to database constraints.
--
-- For the table representation, see db:getObject
function db:getObjectByKey(tp_id, key)
  local row = check(query(
    self,
    [[
      SELECT id, tp_id, ireferences, key, parent
      FROM objects
      WHERE tp_id=:tp_id AND key=:key
    ]],
    false,
    {tp_id=tp_id, key=key}
  ))
  return row
end

--- Fetch the row from the 'objects' table with the given typepath ID and alias.
-- @param #number tp_id The database ID of a type path in the tree.
-- @param #string alias The alias associated with a certain object instance.
-- @return #table A table representation of an object or nil if not found
-- There will be at most one such row due to database constraints.
--
-- For the table representation, see db:getObject
function db:getObjectByAlias(tp_id, alias)
  local row = check(query(
    self,
    [[
      SELECT id, tp_id, ireferences, key, parent
      FROM objects
      WHERE tp_id=:tp_id AND alias=:alias
    ]],
    false,
    {tp_id=tp_id, alias=alias}
  ))
  return row
end

--- retrieve the Alias info
-- @param #number tp_id The database id of the type path in the tree
-- @param #string key The key associated with the instance
-- @return #table A table with the id, parent, ireferences and alias values or nil if there
--   is no such row. There is at most one such row due to database constraints
function db:getAlias(tp_id, key)
  local row = check(query(
    self,
    [[
      SELECT id, parent, ireferences, alias
      FROM objects
      WHERE tp_id=:tp_id AND key=:key
    ]],
    false,
    {tp_id=tp_id, key=key}
  ))
  return row
end

--- retrieve all aliases for a type/parent combo
-- @param #number tp_id The database id of the typepath in the tree
-- @param #number parent The database id of the parent object
-- @return #table a list of rows with the id, ireferences and alias of all the
--   children of parent with the given type
function db:getAliases(tp_id, parent)
  local rows = check(query(
    self,
    [[
      SELECT alias
      FROM objects
      WHERE tp_id=:tp_id AND parent=:parent
            AND alias NOT NULL
    ]],
    false,
    {tp_id=tp_id, parent=parent},
    {}
  ))
  return rows
end

--- Set the alias value for an object with the given database ID
-- @param #number id The id of the object in the database
-- @param #string alias The new alias value
-- @return #boolean True if everything succeeded, false if a duplicate alias was given.
-- This function can raise an error when a database error occurs.
function db:setAliasForId(id, alias)
  local ok, e = query(
    self,
    [[
      UPDATE objects
      SET alias=:alias
      WHERE id=:id
    ]],
    false,
    {id=id, alias=alias}
  )
  if not ok then
    if e.err==sqlite.CONSTRAINT then
      return false, "duplicate value"
    else
      check(false, e)
    end
  end
  return true
end

--- Set the alias value for an object with the given typepath ID and given key
-- @param #number tp_id The database id of the type path that needs to be updated
-- @param #string key The key of the object that needs to be updated
-- @param #string alias The new alias value
-- @return #boolean True if everything succeeded, false if a duplicate alias was given.
-- This function can raise an error when a database error occurs.
function db:setAliasForKey(tp_id, key, alias)
  local ok, e = query(
    self,
    [[
      UPDATE objects
      SET alias=:alias
      WHERE tp_id=:tp_id AND key=:key
    ]],
    false,
    {tp_id=tp_id, key=key, alias=alias}
  )
  if not ok then
    if e.err==sqlite.CONSTRAINT then
      return false, "duplicate value"
    else
      check(false, e)
    end
  end
  return true
end

--- Get the children of a given parent, limited by the given typepath ID.
-- @param #number parentID The database ID of the parent object.
-- @param #number tp_id The database ID of the type path of the children.
-- @return #table A list of objects and additionally (in the same table)
-- a mapping between key and table index. The objects in the list have the
-- same layout as the objects returned from getObject.
-- The additional mapping between key and table index is essential for the
-- correct operation of Transformer. (This needs to match the table returned
-- by the entries function from the mappings.)
function db:getChildren(parentID, tp_id)
  local children = check(query(
    self,
    [[
      SELECT id, tp_id, ireferences, key, parent
      FROM objects
      WHERE tp_id=:tp_id AND parent=:parent
    ]],
    false,
    {tp_id=tp_id, parent=parentID},
    {}
  ))
  for i, row in ipairs(children) do
    -- row.key is a string, so this will never override an existing table entry.
    children[row.key] = i
  end
  return children
end

--- Get all possible instances of the given typepath ID.
-- @param #number tp_id The database ID of the typepath for which to retrieve all instances.
-- @return #table A list of objects with the given typepath ID.
-- The table representation has the following layout:
-- {
--   key=...
--   parent=...
-- }
-- The values are the corresponding values retrieved from the DB.
function db:getSiblings(tp_id)
  local siblings = check(query(
    self,
    [[
      SELECT key, parent
      FROM objects
      WHERE tp_id=:tp_id
    ]],
    false,
    {tp_id=tp_id},
    {}
  ))
  return siblings
end

--- Get all possible parent objects for a given typepath ID.
-- @param #number tp_id The database ID of the typepath for which to retrieve all possible parent objects.
-- @return #table A list of objects with the given typepath ID as parent.
-- The table representation has the following layout:
-- {
--   id=...
--   tp_id=...
--   key=...
--   parent=...
-- }
-- The values are the corresponding values retrieved from the DB.
function db:getParents(tp_id)
  local parents = check(query(
    self,
    [[
      SELECT id, tp_id, key, parent
      FROM objects
      WHERE id IN
        (SELECT DISTINCT parent
         FROM objects
         WHERE tp_id=:tp_id)
    ]],
    false,
    {tp_id=tp_id},
    {}
  ))
  return parents
end

--- Insert a new object in the 'objects' table.
-- @param #number tp_id The database ID of the typepath of the new object.
-- @param #string ireferences The instance reference string.
-- @param #string key The key of the new object.
-- @param #number parent The database id of the parent object.
-- @return #table The inserted row or nil and and error message in
-- case there was a constraint violation.
-- Layout of the result is the same as in getObject.
function db:insertObject(tp_id, ireferences, key, parent)
  local keyType = type(key)
  if keyType~='string' then
    return nil, 'key is not a string but '..keyType
  end
  local nextID = self._lastid + 1
  local obj = {
    id=nextID,
    tp_id=tp_id,
    ireferences=ireferences,
    key=key,
    parent=parent
  }
  local ok, e = query(
    self,
    [[
      INSERT
      INTO objects(
        id, tp_id, ireferences, key, parent)
      VALUES(
        :id, :tp_id, :ireferences, :key, :parent
      )
    ]],
    false,
    obj
  )
  if not ok then
    if e.err==sqlite.CONSTRAINT then
      return nil, e.msg
    else
      check(false, e)
    end
  end
  self._lastid = nextID
  return obj
end

--- Remove a row from the 'objects' table.
-- @param #number tp_id The database ID of the typepath of the object that needs to be deleted.
-- @param #string ireferences The instance reference string.
-- @return nil
-- Removes the row with the given typepath and ireferences. There will be at most
-- one such row due to database constraints.
-- Additionally, all rows that have this row as parent will be deleted
-- recursively. (Triggered by the cascading delete)
function db:deleteObject(tp_id, ireferences)
  check(query(
    self,
    [[
      DELETE
      FROM objects
      WHERE tp_id=:tp_id AND ireferences=:ireferences
    ]],
    false,
    {tp_id=tp_id, ireferences=ireferences}
  ))
end

--- Get the value of a counter from the 'counters' table.
-- @param #number parentid The id of the parent object in the 'objects' table.
-- @param #number tp_id The database ID of the typepath chunk of the child portion of the type path.
-- @return #number The current value of the counter or 0 if not present
function db:getCount(parentid, tp_id)
  local row = check(query(
    self,
    [[
      SELECT value
      FROM counters
      WHERE parentid=:parentid
        AND tp_chunk_id=:tp_chunk_id
    ]],
    false,
    {
      parentid=parentid,
      tp_chunk_id=tp_id
    }
  ))
  return row and row.value or 0
end

--- Set the value of a counter in the 'counters' table.
-- @param #number parentid The id of the parent object in the Objects table.
-- @param #number tp_id The database ID of the typepath chunk of the child portion of the type path.
-- @param #string value The new value for the counter.
-- @return nil
function db:setCount(parentid, tp_id, value)
  value = tonumber(value)
  check(query(
    self,
    [[
      INSERT OR REPLACE
      INTO counters(parentid, tp_chunk_id, value)
      VALUES (:parentid, :tp_chunk_id, :value)
    ]],
    false,
    {
      parentid=parentid,
      tp_chunk_id=tp_id,
      value=value
    }
  ))
end

db.__index = db
function M.new(dbpath, dbname)
  local result_db = {}
  local ok, err = pcall(open, result_db, dbpath, dbname)
  if ok then
    setmetatable(result_db, db)
    return result_db
  else
    -- close the db in case of error
    -- no metatable so do it the hard way
    db.close(result_db)
    -- reraise the error as that is the documented behaviour
    --logger:debug(err)
    error(err:match("[^:]*:%d*:%s(.*)$"))
  end
end

return M
