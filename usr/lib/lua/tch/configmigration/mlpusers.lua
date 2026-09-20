local M = {}

-- This serves as an example.
-- It is best practice to create a custo file that is valid for one specific
-- customer only (see e.g. mlpusers.lua-proximus)
M.roleMappingList ={
  Administrator  = "admin", -- Administrator: the role in legacy; admin: the role in homeware GUI
  TechnicalSupport = "admin",
  root      = "admin",
  WebsevUser= "admin",
  SuperUser = "admin",
  PowerUser = "guest",
  WLAN_User = "guest",
  User      = "guest",
  LAN_Admin = "guest",
  WAN_Admin = "guest",
}

return M
