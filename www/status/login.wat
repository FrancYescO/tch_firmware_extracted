local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local srp = require("srp")
local untaint = string.untaint
local basepath = "uci.web.user.@user_default."
--Verify password
local function auth(username, passwd, salt, verify)
  local res = true
  local user, A = srp.User(username, passwd)
  local verifier, B = srp.Verifier(username, salt, verify, A)
  local M = user:get_M(salt, B)
  local M2, errmsg = verifier:verify(M)
  if errmsg then
    res = false
  end
  return res
end

--Set username and password for new user
local function set_username_password(name, pass)
  local salt, verify =  srp.new_user(name, pass)
  local paths = {}
  paths[basepath.."name"] = name
  paths[basepath.."role"] = "admin"
  paths[basepath.."srp_salt"] = salt
  paths[basepath.."srp_verifier"] = verify
  proxy.set(paths)
  proxy.apply()
end

--Reset password for exist user
local function change_password(name, pass)
  local paths={}
  local salt, verify =  srp.new_user(untaint(name), untaint(pass))
  paths[basepath.."srp_salt"] = salt
  paths[basepath.."srp_verifier"] = verify
  proxy.set(paths)
  proxy.apply()
end

--Check username and password invalid or not
local function checkUsernamePassword(service, args)
  local username = untaint(args.username)
  local passwd = untaint(args.password)
  service.islogin_name = "0"
  service.islogin_pwd = "0"
  local var = {
    srp_salt = basepath.."srp_salt",
    srp_verifier = basepath.."srp_verifier"
  }
  local res = content_helper.getExactContent(var)
  if res then
    service.islogin_name = "1"
    local auth_res = auth(username, passwd, untaint(var.srp_salt), untaint(var.srp_verifier))
    if auth_res then
      service.islogin_pwd = "1"
    end
    service.username = var.username or username
  end
  return true
end

--Check if the CPE has a registered used. If admin_user.name is empty, it is first login.
local service_login1 = {
  name = "login_confirm",
  command = "1",
}
service_login1.get = {
  first_login = function()
    local name = proxy.get(basepath.."name")[1].value
    local sta = name:len()==0 and "1" or "0"
    return sta
  end,
  login_confirm = "end",
}
register(service_login1)

--Create a new user on the CPE. If create success, return login_confirm:end, else return the setting username--actually username
local service_login2 = {
  name = "login_confirm",
  get = {},
  command = "2",
}
service_login2.set = function(args)
  --Set request data to datamodel. Set user role to admin, request parameter is username=XXXXX&password=XXXXXX
  set_username_password(untaint(args.username), untaint(args.password))
  return true
end
register(service_login2)

--Try to authenticate provided username and password on the CPE.
local service_login3 = {
  name = "login_confirm",
  command = "3",
  islogin_name = "0",
  islogin_pwd = "0",
}
service_login3.set = function(args)
  --Set request data to datamodel. Set user role to admin, request parameter is username=XXXXX&password=XXXXXXXX
  checkUsernamePassword(service_login3, args)
  return true
end
-- 1=username is correct, 0=username is not correct. 1=password is correct, 0=password is not correct.
service_login3.get = function()
  local get = {}
  get.check_user = service_login3.islogin_name
  get.check_pwd = service_login3.islogin_pwd
  get.login_confirm = "end"
  return get
end
register(service_login3)

--Check if there is a current authenticated user on the CPE. 1 is authenticated, 0 no authenticated
local service_login4 = {
  name = "login_confirm",
  command = "4",
}
service_login4.get = {
  login_status = function()
    local session = ngx.ctx.session
    return session and session:retrieve("loginflag") or "0"
  end,
  login_confirm = "end",
}
register(service_login4)

--Logout an user
local service_login5 = {
  name = "login_confirm",
  command = "5",
}
--Set flag as ""
service_login5.get={
  login_confirm = function()
    ngx.ctx.session:logout()
    return "end"
  end,
}
register(service_login5)

--This service try to change the password
local service_login6 = {
  name = "login_confirm",
  command = "6",
  islogin_name = "0",
  islogin_pwd = "0",
}
--Authenticate the user name and password, Then set the new password
service_login6.set = function(args)
  args.password = args.old_password
  checkUsernamePassword(service_login6, args)
  if service_login6.islogin_name == "1" and service_login6.islogin_pwd == "1" then
    change_password(args.username, args.new_password)
  end
  return true
end
service_login6.get = function()
  local get = {}
  get.check_user = service_login6.islogin_name
  get.check_pwd = service_login6.islogin_pwd
  get.login_confirm = "end"
  return get
end
register(service_login6)
