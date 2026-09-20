local sqlite3 = require ("lsqlite3")

local M = {}
local runtime
local sms_store = {}

local function toarray(...)
	local arr = {}
	for v in ... do
		table.insert(arr, v)
	end
	return arr
end

function sms_store:send_events()
	if self:has_unread_messages() then
		runtime.events.send_event("mobiled.sms", { event = "unread_messages" })
	else
		runtime.events.send_event("mobiled.sms", { event = "all_messages_read" })
	end
end

function sms_store:init()
	local errMsg
	if not self.db then
		local _, db
		db, _, errMsg = sqlite3.open(self.db_path)
		if not db then
			return nil, errMsg
		end
		self.db = db
	end

	local ret = self.db:exec('CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY, text TEXT, number TEXT, date TEXT, status TEXT);')
	if ret ~= sqlite3.OK then
		return nil, string.format("Failed to create messages table (%s)", ret)
	end

	self:send_events()
	return true
end

function sms_store:get_message_count()
	local data = toarray(self.db:nrows(string.format('SELECT count(*) AS message_count FROM messages;')))
	if data and data[1] then
		return data[1].message_count
	end
	return 0
end

function sms_store:store_message(message)
	if self:get_message_count() >= self.max_messages then
		return nil, "Maximum message count reached"
	end
	local query = string.format('INSERT INTO messages (text, number, date, status) VALUES ("%s", "%s", "%s", "%s");', message.text, message.number, message.date, message.status)
	local ret = self.db:exec(query)
	if ret ~= sqlite3.OK then
		return nil, string.format("Failed to store message (%s)", ret)
	end
	self:send_events()
	return true
end

function M.store_message(message)
	return sms_store:store_message(message)
end

function sms_store:get_message(message_id)
	local query = string.format('SELECT id, text, number, date, status FROM messages WHERE id = %d;', message_id)
	local data = toarray(self.db:nrows(query))
	if data and data[1] then
		return data[1]
	end
	return nil, "No such message"
end

function M.get_message(message_id)
	return sms_store:get_message(message_id)
end

function sms_store:get_messages()
	return toarray(self.db:nrows(string.format('SELECT id, text, number, date, status FROM messages;')))
end

function M.get_messages()
	return sms_store:get_messages()
end

function sms_store:has_unread_messages()
	local info = self:get_info()
	if info and info.unread_messages ~= 0 then
		return true
	end
end

function sms_store:set_message_status(message_id, status)
	local query = string.format('UPDATE messages SET status = "%s" WHERE id = %d;', status, message_id)
	local ret = self.db:exec(query)
	if ret ~= sqlite3.OK then
		return nil, string.format("Failed to set message status (%s)", ret)
	end
	self:send_events()
	return true
end

function M.set_message_status(message_id, status)
	return sms_store:set_message_status(message_id, status)
end

function sms_store:get_info()
	local query = string.format('SELECT id, status FROM messages;')
	local info = {
		read_messages = 0,
		unread_messages = 0,
		max_messages = self.max_messages
	}
	for line in self.db:nrows(query) do
		if line.status == "read" then
			info.read_messages = info.read_messages + 1
		elseif line.status == "unread" then
			info.unread_messages = info.unread_messages + 1
		end
	end
	return info
end

function M.get_info()
	return sms_store:get_info()
end

function sms_store:delete_message(message_id)
	local query = string.format('DELETE FROM messages WHERE id = %d;', message_id)
	local ret = self.db:exec(query)
	if ret ~= sqlite3.OK then
		return nil, string.format("Failed to delete message (%s)", ret)
	end
	self:send_events()
	return true
end

function M.delete_message(message_id)
	return sms_store:delete_message(message_id)
end

function M.sync(device)
	if not device then
		return true
	end
	local messages = device:get_sms_messages()
	if messages and messages.messages then
		for _, message in ipairs(messages.messages) do
			local ret, errMsg = sms_store:store_message(message)
			if not ret then
				return nil, errMsg
			end
			ret, errMsg = device:delete_sms(message.id)
			if not ret then
				return nil, errMsg
			end
		end
	end
	return true
end

function M.init(rt, config)
	runtime = rt
	sms_store.db_path = config.db_path
	sms_store.max_messages = config.max_messages
	return sms_store:init()
end
return M
