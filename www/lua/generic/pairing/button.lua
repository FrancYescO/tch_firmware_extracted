
local setmetatable = setmetatable

local Button = {}
Button.__index = Button

local function ignoreButtonPress()
  return false
end

local function newButton()
  return setmetatable({
    _onPressed = ignoreButtonPress,
  }, Button)
end

function Button:listenForPress(onPressed)
  self._onPressed = onPressed or ignoreButtonPress
end

function Button:pressed()
  return self._onPressed()
end

return {
  new = newButton,
}
