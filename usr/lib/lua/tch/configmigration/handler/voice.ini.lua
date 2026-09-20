local append_commit_list = require("tch.configmigration.core").append_commit_list
local touci = require("tch.configmigration.touci")
local find = string.find

local sqlite = require("lsqlite3")
local match = string.match
local format = string.format
local gmatch = string.gmatch
local gsub = string.gsub
local random = math.random
local db_homeware

local function delete_default_sip_config()
   local ucicmd = {}

   --Delete sip profiles config
   local sip_prof = touci.get_config_type("mmpbxrvsipnet", "profile")
   for _,prof in pairs(sip_prof) do
      --Delete profile in mmpbxrvsipnet
      ucicmd.uci_config = "mmpbxrvsipnet"
      ucicmd.uci_secname = prof[".name"]
      ucicmd.action = "delete"
      touci.touci(ucicmd)
      append_commit_list(ucicmd.uci_config)

      --Delete profile in mmpbx
      ucicmd.uci_config = "mmpbx"
      ucicmd.uci_secname = prof[".name"]
      ucicmd.action = "delete"
      touci.touci(ucicmd)
      append_commit_list(ucicmd.uci_config)
   end

   --Delete incoming map config
   local incoming_map = touci.get_config_type("mmpbx", "incoming_map")
   for _,incmap in pairs(incoming_map) do
      local index = find(incmap["profile"], "sip_profile_")
      if index then
         ucicmd.uci_config = "mmpbx"
	 ucicmd.uci_secname = incmap[".name"]
	 ucicmd.action = "delete"
	 touci.touci(ucicmd)
	 append_commit_list(ucicmd.uci_config)
      end
   end

   --Delete outgoing map config
   local outgoing_map = touci.get_config_type("mmpbx", "outgoing_map")
   for _,outmap in pairs(outgoing_map) do
      ucicmd.uci_config = "mmpbx"
      ucicmd.uci_secname = outmap[".name"]
      ucicmd.action = "delete"
      touci.touci(ucicmd)
      append_commit_list(ucicmd.uci_config)
   end
end

local function open_hw_db()
   db_homeware = sqlite.open("/etc/lasdb.db")
end

local function close_hw_db()
   db_homeware:close()
end

local function get_entry_id()
   local ID
   db_homeware:exec( 'SELECT MAX (Id) FROM contacts',
                      function (ud, ncols, values, names)
	                 ID = values[1]
                      end
		   )
   if not ID then
      ID = 0
   end
   -- ID contains the current max ID value, For next insert we need to increase it by 1
   return ID + 1
end

local function add_contact_number(ContactId, Number, TypeId)
   db_homeware:exec('INSERT INTO ContactNumbers(ContactId,Number,TypeId) VALUES("'.. ContactId ..'", "'.. Number ..'", "'.. TypeId ..'");')
end

local function get_uuid()
   local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
   return gsub(template, '[xy]', function (c)
                      local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
                      return format('%x', v)
                     end)
end

local function add_pb_entry_in_hw_db(Lastname, Firstname, BNumber, HNumber, MNumber)
   local ContactId = ""
   local entryId = get_entry_id()
   local TypeId = 0
   local last_contactId = 0

   if HNumber and HNumber ~= "\"\"" then
      TypeId = 0	--Home
      add_contact_number(entryId, HNumber, TypeId)
      last_contactId = db_homeware:last_insert_rowid()
      ContactId = ContactId.."#"..last_contactId
   end

   if MNumber and MNumber ~= "\"\"" then
      TypeId = 1	-- Mobile
      add_contact_number(entryId, MNumber, TypeId)
      last_contactId = db_homeware:last_insert_rowid()
      ContactId = ContactId.."#"..last_contactId
   end

   if BNumber and BNumber ~= "\"\"" then
      TypeId = 2	-- Business/Work
      add_contact_number(entryId, BNumber, TypeId)
      last_contactId = db_homeware:last_insert_rowid()
      ContactId = ContactId.."#"..last_contactId
   end

   local uuid = get_uuid()

   if Firstname ~="\"\"" then
      db_homeware:exec('INSERT INTO Contacts(Name, FirstName, Number, NumberReferenceList, UUID) VALUES("'.. Lastname ..'", "'.. Firstname ..'", 0, "'.. ContactId ..'", "'.. uuid ..'");')
   else
      db_homeware:exec('INSERT INTO Contacts(Name, Number, NumberReferenceList, UUID) VALUES("'.. Lastname ..'", 0, "'.. ContactId ..'", "'.. uuid ..'");')
   end
end

local function create_contact_tables()
   --Create Contacts table if not exist
   db_homeware:exec('CREATE TABLE IF NOT EXISTS Contacts(Id integer NOT NULL PRIMARY KEY, Name text, MiddleName text, FirstName text, Number text, NumberAtt_Default integer, AssociatedMelody integer, LineId integer, LineIdSub integer, NumberReferenceList text, UUID text NOT NULL UNIQUE);')
   --Create ContactNumbers table if not exist
   db_homeware:exec('CREATE TABLE IF NOT EXISTS ContactNumbers(Id integer NOT NULL PRIMARY KEY, ContactId integer NOT NULL, Number text, TypeId integer NOT NULL, FOREIGN KEY (ContactId) REFERENCES Contacts (Id), FOREIGN KEY (TypeId) REFERENCES ContactTypes (Id));')

   --Create ContactsVersion table if not exist
   db_homeware:exec('CREATE TABLE IF NOT EXISTS ContactsVersion(Id integer NOT NULL PRIMARY KEY, Version integer );')

   --Insert initial value in ContactsVersion table
   db_homeware:exec('INSERT OR IGNORE INTO ContactsVersion (Id, Version) VALUES (1, 0)')

   --Drop insert triggers on ContactsVersion if exist
   db_homeware:exec('DROP TRIGGER IF EXISTS trigger_increment_after_insert')
   db_homeware:exec('DROP TRIGGER IF EXISTS trigger_increment_after_insert_number')

   --Create insert trigger on ContactsVersion
   db_homeware:exec('CREATE TRIGGER trigger_increment_after_insert INSERT ON Contacts BEGIN REPLACE INTO ContactsVersion (Id, Version) VALUES (1,(SELECT SUM (CASE WHEN Version > 2147483500  THEN 0 ELSE Version + 1 END) AS \'version id\' FROM ContactsVersion)); END;')
   db_homeware:exec('CREATE TRIGGER trigger_increment_after_insert_number INSERT ON ContactNumbers BEGIN REPLACE INTO ContactsVersion (Id, Version) VALUES (1,(SELECT SUM (CASE WHEN Version > 2147483500  THEN 0 ELSE Version + 1 END) AS \'version id\' FROM ContactsVersion)); END;')

   db_homeware:exec('PRAGMA user_version=1;')
end

local function migrate_phone_book(section_string)
  if not match(section_string, "pb add %C+") then  --if no "pb add" in user.ini return
      return
   end

   open_hw_db()

   create_contact_tables()

   for phone_book_entry in gmatch(section_string, "pb add %C+") do
      --Phone book entry format: Lastname="LName" Firstname="FName" Business="BNumber" Home="HNumber" Mobile="MNumber" Other="ONumber" E-mail="EMail"
      local Lastname, Firstname, BNumber, HNumber, MNumber = match(phone_book_entry, "Lastname=(%S+) Firstname=(%S+) Business=(%S+) Home=(%S+) Mobile=(%S+)")
      --print("Lastname="..Lastname.."Firstname="..Firstname.."BNumber="..BNumber.."HNumber="..HNumber.."MNumber="..MNumber)

      add_pb_entry_in_hw_db(Lastname, Firstname, BNumber, HNumber, MNumber)
   end
   close_hw_db()
end

local M = {}

function M.convert(g_user_ini)
   local section_string = g_user_ini["voice.ini"]
   if not section_string then return end

   delete_default_sip_config()
   migrate_phone_book(section_string)
end

return M
