local ngx = ngx
local type = type

local M = {}

local messageskey = "uimessages"

---
-- Retrieves the list of pending messages
-- @return #table the session object
local function getMessageObject()
    local session = ngx.ctx.session
    local messages = session:retrieve(messageskey)
    if type(messages) ~= "table" then
        messages = {}
    end
    return messages
end

--- Updates the list of pending messages
-- @param #table messages
local function setMessageObject(messages)
    local session = ngx.ctx.session
    session:store(messageskey, messages)
end


---
-- add a new message in the stack of pending messages to display in the UI
-- @param content string or table compatible with ngx.print
-- @param level one of warning, error, info, success
--
function M.pushMessage(content, level)
    local messages = getMessageObject()
    messages[#messages+1] = {content = content, level = level}
    setMessageObject(messages)
end

---
-- Pop the last message on the "stack"
-- @return #table or #string, #string the content and the level
function M.popMessage()
    local messages = getMessageObject()
    if #messages == 0 then
        return nil
    else
        local m = messages[#messages]
        messages[#messages] = nil
        setMessageObject(messages)
        return m.content, m.level
    end
end

--- Returns all the messages and clear the stack
function M.popMessages()
    local messages = getMessageObject()
    setMessageObject({})
    return messages
end

return M