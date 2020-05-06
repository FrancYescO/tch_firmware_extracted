local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local srp = require("srp")
local untaint = string.untaint
local change_result = "0"
local basepath = "uci.web.user.@user_default."

--Set new username and password
local function set_username_password(name, pass)
  local paths = {}
  local salt, verify =  srp.new_user(name, pass)
  paths[basepath.."name"] = name
  paths[basepath.."srp_salt"] = salt
  paths[basepath.."srp_verifier"] = verify
  proxy.set(paths)
  proxy.apply()
end

--Auth and set new user name and password
local function auth_set(args)
  local oldname = untaint(args.old_username)
  local oldpwd = untaint(args.old_pass)
  local var = {
    srp_salt = basepath.."srp_salt",
    srp_verifier = basepath.."srp_verifier"
  }
  local res = content_helper.getExactContent(var)
  if res then
    local salt = untaint(var.srp_salt)
    local srp_verifier = untaint(var.srp_verifier)
    local user, A = srp.User(oldname, oldpwd)
    local verifier, B = srp.Verifier(oldname, salt, srp_verifier, A)
    local M = user:get_M(salt, B)
    local M2, errmsg = verifier:verify(M)
    if errmsg then
      change_result = errmsg
    else
      set_username_password(untaint(args.new_username), untaint(args.new_pass))
      change_result = "1"
    end
  end
  return true
end

--Change the username/password used for the CPE.
local cpe_auth = {
  name = "cpe_auth",
}

cpe_auth.set = function(args)
  if args.cpe_auth_enable == "1" then
     --Get the auth result by old value, and set to local var
    auth_set(args)
  end
  return true
end

cpe_auth.get = {
  cpe_auth = function()
    return change_result
  end,
}

register(cpe_auth)
