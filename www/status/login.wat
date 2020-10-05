local untaint = string.untaint
local content_helper = require("web.content_helper")
local dm = require("datamodel")
local srp = require("srp")
local namepath = "uci.web.user.@user_default.name"
local saltpath = "uci.web.user.@user_default.srp_salt"
local verifierpath = "uci.web.user.@user_default.srp_verifier"

-- Verify password
local function auth(name, passwd, salt, verify)
  local user, A = srp.User(name, passwd)
  local verifier, B = srp.Verifier(name, salt, verify, A)
  local M = user:get_M(salt, B)
  local M2, errmsg = verifier:verify(M)
  return M2 and true or false
end

-- Set user information for new or existed user
local function set_user_info(name, passwd, newflag)
  local paths = {}
  local name = untaint(name)
  local passwd = untaint(passwd)
  local salt, verify = srp.new_user(name, passwd)
  if newflag then
    paths[namepath] = name
  end
  paths[saltpath] = salt
  paths[verifierpath] = verify
  dm.set(paths)
  dm.apply()
end

-- Check username and password
local function check_name_passwd(name, passwd)
  local name = untaint(name)
  local passwd = untaint(passwd)
  local isuser = "0"
  local ispwd  = "0"
  local pwd = {
    srp_salt = saltpath,
    srp_verifier = verifierpath
  }
  local res = content_helper.getExactContent(pwd)
  if res then
    isuser = "1"
    if auth(name, passwd, untaint(pwd.srp_salt), untaint(pwd.srp_verifier)) then
      ispwd = "1"
    end
  end
  return isuser, ispwd
end

local service_login1 = {
  name = "login_confirm",
  command = "1",
  get = function()
    local data = {}
    local name = dm.get(namepath)[1].value
    data.first_login = name:len()==0 and "1" or "0"
    data.login_confirm = "end"
    return data
  end
}

local service_login2 = {
  name = "login_confirm",
  command = "2",
  get = {},
  set = function(args)
    -- check whether the user is existed or not
    local name = dm.get(namepath)[1].value
    if name and name ~= "" then
      return false
    end
    set_user_info(args.username, args.password, true)
    return true
  end
}

local service_login3 = {
  name = "login_confirm",
  command = "3",
  check_user = "0",
  check_pwd  = "0",
}
service_login3.get = function()
  return {
    check_user = service_login3.check_user,
    check_pwd = service_login3.check_pwd,
    login_confirm = "end",
  }
end

service_login3.set = function(args)
  local isuser, ispwd = check_name_passwd(args.username, args.password)
  if isuser == "1" and ispwd == "1" then
    local session = ngx.ctx.session
    if session then
      session:store("loginflag", "1")
    end
  end
  service_login3.check_user = isuser
  service_login3.check_pwd  = ispwd
  return true
end

local service_login4 = {
  name = "login_confirm",
  command = "4",
  get = function()
    local data = {}
    local session = ngx.ctx.session
    data.login_status = session and session:retrieve("loginflag") or "0"
    data.login_confirm = "end"
    return data
  end
}

local service_login5 = {
  name = "login_confirm",
  command = "5",
  get = function()
    local session = ngx.ctx.session
    if session then
      session:store("loginflag", "0")
    end
    return {login_confirm = "end"}
  end,
}

local service_login6 = {
  name = "login_confirm",
  command = "6",
  check_user = "0",
  check_pwd  = "0",
}

service_login6.get = function()
  return {
    check_user = service_login6.check_user,
    check_pwd = service_login6.check_pwd,
    login_confirm = "end",
  }
end
service_login6.set = function(args)
  local isuser, ispwd = check_name_passwd(args.username, args.old_password)
  if isuser == "1" and ispwd == "1" then
    set_user_info(args.username, args.new_password)
  end
  service_login6.check_user = isuser
  service_login6.check_pwd  = ispwd
  return true
end


register(service_login1)
register(service_login2)
register(service_login3)
register(service_login4)
register(service_login5)
register(service_login6)
