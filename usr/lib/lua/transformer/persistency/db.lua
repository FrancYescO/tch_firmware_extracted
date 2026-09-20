--- The access to the transformer database
--[[
The transformer database consists of two tables: objects and counters. Transformer
does not access the database directly, it goes through some access functions. These
functions are listed below.

Table: Objects
--------------

This table stores all persistent information about object instances in the tree.

It has the following fields:
  * id : an auto generated integer (this is the primary key)
  * typepath : the type path of the object
  * ireferences : a string representing the instance references (these can be numbers or strings)
  * key : a string representing the key of the object
  * parent : the id of the parent object

The format and content of typepath, ireferences and key is of no concern to the
db, they are always strings.

The combination (typepath, ireferences) must be unique and also the combination
(typepath, key) must be unique.

Access functions for the Objects table:
  * insertObject
  * deleteObject
  * getObject
  * getChildren

Table: Counters
---------------

This is a support table that persists the Transformer internal counters that
generate instance numbers.

It has the following fields:

  * parentid : The ID of the parent object in the Objects table. (This is an integer)
  * child : The child portion of the typepath (for example: List.{i}. is the child portion of Multi.{i}.List.{i})
  * value : The last used instance number for the <parentid, child> tuple.

The primary key is (parentid, child).

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

local M = {}

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
-- All parameters are passed in through the 'args' parameter.
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
      --logger:debug("e=%s, msg=%s", results.e, results.msg)
      break
    end
  end
  reset(stmt)
  --logger:debug("DONE %s", ok and "true" or "false")
  return ok, results
end

--- Utility wrapper to execute an SQL statement.
-- @param db The database to run the SQL statement against.
-- @param sql The SQL statement to execute.
local function execSql(db, sql)
  return check(query(db, sql, true))
end

--- Opens an internal database object and populates the required fields.
-- @param db The table in which to create the internal object.
-- @param dbpath The path of the database name. If nil open a memory database.
-- @param dbname The name of the database file. If nil use transformer.db
-- NOTE: This function raises an error if opening the database fails for some reason.
local function open(db, dbpath, dbname)
  local h, _, errmsg
  if dbpath~=nil then
    h, _, errmsg = sqlite.open(get_fulldbpath(dbpath, dbname))
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

  execSql(db, [[
    CREATE TABLE IF NOT EXISTS objects (
      id INTEGER PRIMARY KEY,
      typepath TEXT NOT NULL,
      ireferences TEXT NOT NULL,
      key TEXT NOT NULL,
      parent INTEGER REFERENCES objects(id)
        ON DELETE CASCADE
        ON UPDATE RESTRICT,

      UNIQUE (typepath, ireferences),
      UNIQUE (typepath, key)
    );
  ]])

  execSql(db, [[
    CREATE TABLE IF NOT EXISTS counters (
      parentid INTEGER NOT NULL,
      child TEXT NOT NULL,
      value INTEGER NOT NULL,

      PRIMARY KEY(parentid, child),
      FOREIGN KEY(parentid) REFERENCES objects(id)
        ON DELETE CASCADE
        ON UPDATE RESTRICT
    )
  ]])

  -- We keep track of the row_id internally to avoid the overhead of an extra
  -- query to the database after an INSERT statement.
  db._lastid = execSql(db,
    "SELECT MAX(id) as m FROM objects"
  ).m or 0
end

local db = {}

--- Close the DB connection
-- After this the object can no longer be used.
function db:close()
  if self._handle then
    for _, stmt in pairs(self._stats) do
      stmt:finalize()
    end
    self._stats = nil
    self._handle:close()
    self._handle = nil
  end
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

--- Fetch the row in the Objects table with the given typepath and ireferences
-- @param #string typepath A type path in the tree.
-- @param #string ireferences A representation of the instance references.
-- @return #table A table representation of an object or nil if not found.
-- There is at most one such row due to the database constraints.
--
-- The table representation has the following layout:
-- {
--   id=...
--   typepath=...
--   ireferences=...
--   key=...
--   parent=...
-- }
-- The values are the corresponding values retrieved from the DB
function db:getObject(typepath, ireferences)
  local row = check(query(
    self,
    [[
      SELECT id, typepath, ireferences, key, parent
      FROM objects
      WHERE typepath=:typepath AND ireferences=:ireferences
    ]],
    false,
    {typepath=typepath, ireferences=ireferences}
  ))
  return row
end

--- Fetch the row in from the Objects table with the given typepath and key
-- @param #string typepath A type path in the tree.
-- @param #string key The key associated with a certain object instance.
-- @return #table A table representation of an object or nil if not found
-- There will be at most one such row due to database constraints.
--
-- For the table representation, see db:getObject
function db:getObjectByKey(typepath, key)
    local row = check(query(
        self,
        [[
            SELECT id, typepath, ireferences, key, parent
            FROM objects
            WHERE typepath=:typepath AND key=:key
        ]],
        false,
        {typepath=typepath, key=key}
    ))
    return row
end

--- Get the children of a given parent, limited by the given type path.
-- @param #number parentID The datebase ID of the parent object.
-- @param #string typepath The requested typepath of the children.
-- @return #table A list of objects and additionally (in the same table)
-- a mapping between key and table index. The objects in the list have the
-- same layout as the objects returned from getObject.
-- The additional mapping between key and table index is essential for the
-- correct operation of Transformer. (This needs to match the table returned
-- by the entries function from the mappings.)
function db:getChildren(parentID, typepath)
  local children = check(query(
    self,
    [[
      SELECT id, typepath, ireferences, key, parent
      FROM objects
      WHERE typepath=:typepath AND parent=:parent
    ]],
    false,
    {typepath=typepath, parent=parentID},
    {}
  ))
  for i, row in ipairs(children) do
    -- row.key is a string, so this will never override an existing table entry.
    children[row.key] = i
  end
  return children
end

--- Get all possible instances of the given type path.
-- @param #string typepath The requested typepath of the instances.
-- @return #table A list of objects.
-- The table representation has the following layout:
-- {
--   key=...
--   parent=...
-- }
-- The values are the corresponding values retrieved from the DB
function db:getSiblings(typepath)
  local siblings = check(query(
    self,
    [[
      SELECT key, parent
      FROM objects
      WHERE typepath=:typepath
    ]],
    false,
    {typepath=typepath},
    {}
  ))
  return siblings
end

-- Get all possible parents of a typepath
function db:getParents(typepath)
  local parents = check(query(
    self,
    [[
      SELECT id, typepath, key, parent
      FROM objects
      WHERE id IN
        (SELECT DISTINCT parent
         FROM objects
         WHERE typepath=:typepath)
    ]],
    false,
    {typepath=typepath},
    {}
  ))
  return parents
end

--- Insert a new object in the Objects table.
-- @param #string typepath The type path of the new object.
-- @param #string ireferences The instance reference string.
-- @param #string key The key of the source object.
-- @param #number parent The database id of the parent object.
-- @return #table The inserted row or nil and and error message in
-- case there was a constraint violation.
-- Layout of the result is the same as in getObject.
function db:insertObject(typepath, ireferences, key, parent)
  local nextID = self._lastid + 1
  local obj = {
    id=nextID,
    typepath=typepath,
    ireferences=ireferences,
    key=key,
    parent=parent
  }
  local ok, e = query(
    self,
    [[
      INSERT
      INTO objects(
        id, typepath, ireferences, key, parent)
      VALUES(
        :id, :typepath, :ireferences, :key, :parent
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

--- Remove a row from the Objects table.
-- @param #string typepath The type path of the object that needs to be deleted.
-- @param #string ireferences The instance reference string.
-- @return nil
-- Removes the row with the given typepath and ireferences. There will be at most
-- one such row due to database constraints.
-- Additionally, all rows that have this row as parent will be deleted
-- recursively. (Triggered by the cascading delete)
function db:deleteObject(typepath, ireferences)
  check(query(
    self,
    [[
      DELETE
      FROM objects
      WHERE typepath=:typepath AND ireferences=:ireferences
    ]],
    false,
    {typepath=typepath, ireferences=ireferences}
  ))
end

--- Get the value of a counter from the Counters table.
-- @param #number parentid The id of the parent object in the Objects table.
-- @param #string child The child portion of the type path.
-- @return #number The current value of the counter or 0 if not present
function db:getCount(parentid, child)
  local row = check(query(
    self,
    [[
      SELECT value
      FROM counters
      WHERE parentid=:parentid
        AND child=:child
    ]],
    false,
    {
      parentid=parentid,
      child=child
    }
  ))
  return row and row.value or 0
end

--- Set the value of a counter in the Counters table.
-- @param #number parentid The id of the parent object in the Objects table.
-- @param #string child The child portion of the type path.
-- @param #string value The new value for the counter.
-- @return nil
function db:setCount(parentid, child, value)
  value = tonumber(value)
  check(query(
    self,
    [[
      INSERT OR REPLACE
      INTO counters(parentid, child, value)
      VALUES (:parentid, :child, :value)
    ]],
    false,
    {
      parentid=parentid,
      child=child,
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
