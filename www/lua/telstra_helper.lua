--  telstra_helper module
--  @module telstra_helper
--  @usage local tel_helper = require('telstra_helper')
--  @usage require('telstra_helper')

local M = {}
local proxy =  require("datamodel")
local landing_page = proxy.get("uci.env.var.landing_page")[1].value
if landing_page == "1" then
    M.symbolnamev1 = "Modem"
    M.symbolnamev2 = "modem"
    M.login_file = "landingpage.lp"
else
    M.symbolnamev1 = "Gateway"
    M.symbolnamev2 = "gateway"
    M.login_file = "loginbasic.lp"
end

return M
