local logger_utility = require('transformer.logger')

local M = {}

local levels = {
  critical = 1,
  error    = 2,
  warning  = 3,
  notice   = 4,
  info     = 5,
  debug    = 6,
}

function M.new(tag)
--  local level = levels[config.service.log_level] or 5
  local level =  6
  local logger = logger_utility.new('gw-diag-service', level)

  return logger
end

return M
