local sqlite3 = require ("lsqlite3")

local M = {}
local runtime
local sms_store = {}

local function execute_query(query, arguments)
	query:reset()

	local ret = query:bind_names(arguments)
	if ret ~= sqlite3.OK then
		return nil, string.format("Failed to bind arguments (%d)", ret)
	end

	ret = query:step()
	if ret ~= sqlite3.DONE then
		return nil, string.format("Failed to execute query (%d)", ret)
	end

	return true
end

local function get_only_result(query, arguments)
	query:reset()

	local ret = query:bind_names(arguments)
	if ret ~= sqlite3.OK then
		return nil, string.format("Failed to bind arguments (%d)", ret)
	end

	for row in query:nrows() do
		return row
	end

	return nil, "No results available"
end

local function get_all_results(query, arguments)
	query:reset()

	local ret = query:bind_names(arguments)
	if ret ~= sqlite3.OK then
		return nil, string.format("Failed to bind arguments (%d)", ret)
	end

	local result = {}
	for row in query:nrows() do
		table.insert(result, row)
	end
	return result
end

function sms_store:send_events()
	if self:has_unread_messages() then
		runtime.events.send_event("mobiled.sms", { event = "unread_messages" })
	else
		runtime.events.send_event("mobiled.sms", { event = "all_messages_read" })
	end
end

function sms_store:init()
	if self.initialized then
		return true
	end

	local err_msg

	self.db, err_msg = sqlite3.open(self.db_path)
	if not self.db then
		return nil, err_msg
	end

	local ret = self.db:exec('CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY, text TEXT, number TEXT, date TEXT, status TEXT);')
	if ret ~= sqlite3.OK then
		return nil, string.format("Failed to create messages table (%d)", ret)
	end

	self.get_message_count_query, err_msg = self.db:prepare('SELECT count(*) AS message_count FROM messages;')
	if not self.get_message_count_query then
		return nil, err_msg
	end

	self.store_message_query, err_msg = self.db:prepare('INSERT INTO messages (text, number, date, status) VALUES (:text, :number, :date, :status);')
	if not self.store_message_query then
		return nil, err_msg
	end

	self.get_message_query, err_msg = self.db:prepare('SELECT id, text, number, date, status FROM messages WHERE id = :message_id;')
	if not self.get_message_query then
		return nil, err_msg
	end

	self.get_messages_query, err_msg = self.db:prepare('SELECT id, text, number, date, status FROM messages;')
	if not self.get_messages_query then
		return nil, err_msg
	end

	self.set_message_status_query, err_msg = self.db:prepare('UPDATE messages SET status = :status WHERE id = :message_id;')
	if not self.set_message_status_query then
		return nil, err_msg
	end

	self.get_info_query, err_msg = self.db:prepare('SELECT id, status FROM messages;')
	if not self.get_info_query then
		return nil, err_msg
	end

	self.delete_message_query = self.db:prepare('DELETE FROM messages WHERE id = :message_id;')
	if not self.delete_message_query then
		return nil, err_msg
	end

	self:send_events()
	self.initialized = true

	return true
end

function sms_store:get_message_count()
	local result, err_msg = get_only_result(self.get_message_count_query, {})
	if not result then
		return nil, err_msg
	end
	return result.message_count
end

function sms_store:store_message(message)
	if self:get_message_count() >= self.max_messages then
		return nil, "Maximum message count reached"
	end
	local success, err_msg = execute_query(self.store_message_query, {
		text = message.text,
		number = message.number,
		date = message.date,
		status = message.status
	})
	if not success then
		return nil, string.format("Failed to store message: %s", err_msg)
	end
	self:send_events()
	return true
end

function M.store_message(message)
	return sms_store:store_message(message)
end

function sms_store:get_message(message_id)
	local result, err_msg = get_only_result(self.get_message_query, {
		message_id = message_id
	})
	if not result then
		return nil, "No such message"
	end
	return result
end

function M.get_message(message_id)
	return sms_store:get_message(message_id)
end

function sms_store:get_messages()
	return get_all_results(self.get_messages_query, {})
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
	local success, err_msg = execute_query(self.set_message_status_query, {
		status = status,
		message_id = message_id
	})
	if not success then
		return nil, string.format("Failed to set message status: %s", err_msg)
	end
	self:send_events()
	return true
end

function M.set_message_status(message_id, status)
	return sms_store:set_message_status(message_id, status)
end

function sms_store:get_info()
	local info = {
		read_messages = 0,
		unread_messages = 0,
		max_messages = self.max_messages
	}
	local result, err_msg = get_all_results(self.get_info_query, {})
	if not result then
		return nil, err_msg
	end
	for _, row in ipairs(result) do
		if row.status == "read" then
			info.read_messages = info.read_messages + 1
		elseif row.status == "unread" then
			info.unread_messages = info.unread_messages + 1
		end
	end
	return info
end

function M.get_info()
	return sms_store:get_info()
end

function sms_store:delete_message(message_id)
	local success, err_msg = execute_query(self.delete_message_query, {
		message_id = message_id
	})
	if not success then
		return nil, string.format("Failed to delete message: %s", err_msg)
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
