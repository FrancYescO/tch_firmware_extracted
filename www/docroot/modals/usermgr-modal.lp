--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local string, ngx, gsub, upper = string, ngx, string.gsub, string.upper
local taint_mt = require("web.taint").taint_mt
local type, setmetatable, random = type, setmetatable, math.random
local table, ipairs, istainted, format = table, ipairs, string.istainted, string.format
local untaint = string.untaint
local srp = require("srp")
local session = ngx.ctx.session
local printf = require("web.web").printf
-- Shortcuts to validation helpers to make lines shorter
local validateEnum = post_helper.getValidateInEnumSelect
local validateNonEmptyString = post_helper.validateNonEmptyString
local getValidateStringLengthInRange = post_helper.getValidateStringLengthInRange
local getAndValidation = post_helper.getAndValidation
local currentRole = session:getrole()
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Management", "userManagertab")
local getVariantValue = post_helper.getVariantValue
local roleListValue = getVariantValue(variantHelper, "roleListValue")

-- Start for legacy migration: GUI username/password [NG-48489]
local users = content_helper.getMatchedContent("uci.web.user.")
local userNames = ""
local legacySalts = ""

local passwordlength = proxy.get("uci.env.var.passwordlength")
passwordlength = passwordlength and passwordlength[1].value ~= "" and passwordlength[1].value or "12"

for _, user in ipairs(users) do
  if user.legacy_salt ~= "" then
    userNames = userNames .. user.name ..","
    legacySalts = legacySalts .. user.legacy_salt .. ","
  end
end
-- End for legacy migration: GUI username/password [NG-48489]

if ngx.req.get_method() == "POST" then
  local post_args = ngx.req.get_post_args()
  local I, A, M = untaint(post_args.I), untaint(post_args.A), untaint(post_args.M)
  if I and A then
    session:store("editedUserName", I)
    local user = content_helper.getMatchedContent("uci.web.user.", {name=I})
    if user and #user > 0 then
      user = user[1]
    end
    local verifier, B = srp.Verifier(I, untaint(user.srp_salt), untaint(user.srp_verifier), A)
    session:store("verifier", verifier)
    session:store("edited_user", I)
    ngx.header.content_type = "application/json"
    printf('{ "s":"%s", "B":"%s" }', user.srp_salt, B)
    ngx.exit(ngx.HTTP_OK)
  end
  if M then
    local verifier = session:retrieve("verifier")
    session:store("verifier", nil)
    ngx.header.content_type = "application/json"
    local M2, errmsg = verifier:verify(M)
    if M2 then
      local user = session:retrieve("edited_user")
      session:store("verified_user", user)
      printf('{ "M":"%s" }', M2)
    else
      printf('{ "error":"%s" }', errmsg or "failed")
    end
    ngx.exit(ngx.HTTP_OK)
  end
end

local roleslist = {}
local newList = false
local defaultuser = {}
content_helper.addListContent(defaultuser, { users = "uci.web.sessionmgr.@default.users." })

local function roleUpdate(check)
  for _, usrrolename in ipairs(defaultuser.users) do
    local userList = format("uci.web.user.@%s.role", usrrolename)
    userList = proxy.get(userList)[1].value
    local userRole = userList:gsub( "^%l", upper)
    if newList then
      roleslist[#roleslist + 1] = {userList, userRole}
      break
    end
    if check == "1" and userList == "ispuser" then
       userRole = "Admin"
    end
    roleslist[#roleslist + 1] = {userList, userRole}
    if currentRole == userList and currentRole == "admin" and check then
       newList = true
    elseif currentRole == userList then
       break
    end
   end
end

if roleListValue then
  roleUpdate()
else
  local unlocked = proxy.get("rpc.env.var.unlockedstatus")[1].value
  roleUpdate(unlocked)
end

local passwordWarning = {
  alert = {
    class = "alert",
    style="margin-left:15px;display:inline;font-size:15px;"
  }
}
local warning = ui_helper.createAlertBlock(T"Provide a password to prevent unauthorized access to the gateway.", passwordWarning)

local defaultValue
if roleListValue then
  defaultValue = post_helper.isFeatureEnabled("defaultUser", currentRole) and "admin" or "guest"
else
  defaultValue = "guest"
end

local umgrColumns = {
  {
    header = T"Name",
    name = "name",
    param = "name",
    type = "text",
    attr = { input = { class="span2" } }
  },
  {
    header = T"Role",
    name = "role",
    param = "role",
    default = defaultValue,
    type = "select",
    values = roleslist,
    attr = { select = { class="span2" } }
  },
  {
    header = "",
    legend = T"Change password" .. warning[1],
    name = "passwordmgt",
    param = "passwordmgt",
    type = "aggregate",
    synthesis = nil,
    subcolumns = {
      {
        header = T"Password",
        name = "password",
        param = "password",
        type = "password",
        attr = { input = { class="span2", onkeyup="passwordCheck(this.value)", id = "usrmodal_password" },}
      },
      {
        header = T"Repeat Password",
        name = "password2",
        param = "password2",
        type = "password",
        attr = { input = { class="span2", id = "repeat_pass" }}
      }
    }
  }
}

local umgrAttributes = {
}

local wu = {}
local users
local currentuser = ngx.ctx.session:getusername()

local umgrFilter = function(data)
  if not users then -- we need to initialize it after the current table operation happened so do this on the first run of umgrFilter
    -- this is because filter is called in loadTableData which happens after committing the current operation
    users = setmetatable({}, taint_mt)
    content_helper.addListContent(wu, { users = "uci.web.sessionmgr.@default.users." })
    for _,user in ipairs(wu.users) do
      users[user] = true
    end
  end
  local name = data.paramindex -- name of the entry
  local username = data.name
  local availableRole = data.role

  -- check either it's an already existing entry
  if name and users[name] then
    if ((currentRole == "admin" and (availableRole == "recovery" or availableRole == "engineer")) or (currentRole == "engineer" and availableRole == "recovery") and roleListValue) then
      return nil
    end
    if name == "usr_guest" then
      return nil
    elseif ((currentuser == username) or (not roleListValue and (name == "usr_admin"))) then
      return {
        canEdit = true,
        canDelete = false
      }
    else
      return true
    end
  elseif ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "TABLE-ADD" and ngx.req.get_post_args().name == username then
    return true
  else
    return nil
  end
end

local umgrDefaultObject

-- when creating a new user, name the entry with a random name otherwise won't be able to retrieve the name of the entry
-- after calling proxy.add
local function generateNewObjectname()
  return "usr_default_" .. tostring(random()):sub(3)
end

local function setCryptedPassword()
  local post_args = ngx.req.get_post_args()
  if (post_args.action == "TABLE-MODIFY") then
    local username = untaint(post_args.name)
    local cryptpw  = post_args.cryptpw
    local r, err = proxy.set("rpc.user.@" .. username .. ".pwcrypt", cryptpw)
    if not r then
      -- error 9005 is returned if rpc not installed, or user `username` is not a CLI user;
      -- this is not considered an error at this point, so don't report.
      if err[1].errcode ~= 9005 then
        return nil, err[1].errmsg
      end
    else
      proxy.apply()
    end
  end
  return true
end

local umgrOptions = {
  tableid = "usermgr",
  basepath = "uci.web.user.@.",
  createMsg = T"Add new user",
  addNamedObject = true,
  sorted = "name",
  objectName = generateNewObjectname(),
  valid = setCryptedPassword
}

if not roleListValue then
  if currentRole ~= "engineer" then
     umgrOptions.canAdd = false
  end
end

local function userStateModified(object)
  local post_args = ngx.req.get_post_args()
  if (post_args.action == "TABLE-MODIFY") then
    local basepath = "uci.web.user.@" .. umgrOptions.changesessionindex .. "."
    local userData = {
      name = basepath .. "name",
      srp_salt = basepath .. "srp_salt",
    }
  content_helper.getExactContent(userData)
    return true, userData.name ~= object.name, userData.srp_salt ~= object.srp_salt
  end
  return false
end

local function clearPassword(value, object, key)
  local state, bname, bsalt = userStateModified(object)
  if state and bname then
    if not bsalt then
      return nil, T"Please set the new password for new user."
    end
  end

  object[key] = nil
  return true
end

local function rvalidation(rl)
  if ngx.var.request_method == "POST" then
    local post_args = ngx.req.get_post_args()
    if post_args.action == "TABLE-MODIFY" and post_args.name == currentuser and post_args.role ~= nil then
      return nil, T"Current user can not edit their role"
    end
  end
  return validateEnum(rl)
end

local function checkDuplicatedUser(value)
  for _,usrrolename in ipairs(defaultuser.users) do
    local path = format("uci.web.user.@%s.name", usrrolename)
    local usrname = proxy.get(path)
    if usrname then
      if value == usrname[1].value and (not umgrOptions.changesessionindex or usrrolename ~= umgrOptions.changesessionindex) then
        return true
      end
    end
  end
  return false
end

local function validateName(value, object, key)
  local state, msg = validateNonEmptyString(value)
  if not state then
    return nil, msg
  end
  if ngx.req.get_post_args().action == "TABLE-MODIFY" then
    local user = session:retrieve("verified_user")
    session:store("verified_user",nil)
    local usrname_fromuci = proxy.get("uci.web.user.@" .. umgrOptions.changesessionindex .. ".name")
    if usrname_fromuci then
      if user ~= usrname_fromuci[1].value then
        return nil, T"Old password must be validated"
      end
    end
    if checkDuplicatedUser(value) then
      return nil, T"A user with this username already exists"
    end
    return true
  end
  if ngx.req.get_post_args().action == "TABLE-ADD" then
    if checkDuplicatedUser(value) then
      return nil, T"A user with this username already exists"
    end
    return true
  end
  return state, msg
end

local umgrValid = {
  name = getAndValidation(validateName, getValidateStringLengthInRange(1,63)),
  role = rvalidation(roleslist),
  srp_salt = post_helper.validateExactLength(8),
  srp_verifier = post_helper.validateExactLength(512),
  password = clearPassword,
  password2 = clearPassword
}

local function onAdd(index, content)
  local _, msg = ngx.ctx.session:addUserToManager(index)
  umgrOptions.errmsg = msg
end

local function onDelete(index)
  local _, msg = ngx.ctx.session:delUserFromManager(index)
  umgrOptions.errmsg = msg
end

local function onModify(index, content)
  local _, msg = ngx.ctx.session:reloadAllUsers()
  umgrOptions.errmsg = msg
end

umgrOptions.onAdd = onAdd
umgrOptions.onModify = onModify
umgrOptions.onDelete = onDelete

-- Start for legacy migration: GUI username/password [NG-48489]
if ngx.req.get_method() == "POST" then
  --If modified the password, and set the user's option legacy_salt to empty.
  local post_args = ngx.req.get_post_args()
  if (post_args.action == "TABLE-MODIFY") then
    local username = untaint(post_args.name)
    local user = content_helper.getMatchedContent("uci.web.user.", {name = username})
    local proxyapply = false
    if user and #user > 0 then
      user = user[1]
      if (user.legacy_salt ~= "") then
        proxy.set(user.path .. "legacy_salt", "")
        proxyapply = true
      end
      if proxy.set(user.path .. "password_reminder", "0") then
        proxyapply = true
      end
      if proxyapply then
        proxy.apply()
      end
    end
  end
end
-- End for legacy migration: GUI username/password [NG-48489]

if ngx.req.get_method() == "POST" and (ngx.req.get_post_args().action == "TABLE-EDIT" or (ngx.req.get_post_args().action == "TABLE-MODIFY" and umgrHelpmsg and next(umgrHelpmsg))) then
  local oldpassword = {
    header = T"Old Password",
    name = "oldpassword",
    type = "password",
    attr = { input = { class="span2"}}
  }
  table.insert(umgrColumns[3].subcolumns,1,oldpassword)
else
  session:store("editedUserName", nil)
end

local umgrData, umgrHelpmsg = post_helper.handleTableQuery(umgrColumns, umgrOptions, umgrFilter, umgrDefaultObject, umgrValid)

if ngx.req.get_method() == "POST" and (ngx.req.get_post_args().action == "TABLE-MODIFY" or ngx.req.get_post_args().action == "TABLE-ADD") and not (umgrHelpmsg and next(umgrHelpmsg)) then
  local users = content_helper.getMatchedContent("uci.web.user.")
  for _, users in ipairs(users) do
     if users.name == ngx.req.get_post_args().name then
       uciPath = users.path
     end
  end
  proxy.set(uciPath.."srp_verifier", ngx.req.get_post_args().srp_verifier)
  proxy.set(uciPath.."srp_salt", ngx.req.get_post_args().srp_salt)
  proxy.apply()
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "TABLE-MODIFY" and ngx.req.get_post_args().name == session:getusername() and not (umgrHelpmsg and next(umgrHelpmsg)) then
  -- When password changed successfully for the current user with no error message
  -- then logout the user and redirect to login screen
  ngx.print('\
  <script type="text/javascript">\
    window.location="login.lp";\
  </script>\
');  
  session:logout()
  ngx.exit(ngx.HTTP_OK)
end
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Management", false, false))   ngx.print('\
\
<div class="modal-body update">\
\
');  
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-management.lp")
  ngx.print('\
\
<form class="form-horizontal" method="post" action="modals/usermgr-modal.lp">\
');  
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
\
<fieldset>\
<legend>');  ngx.print( T"Users list" ); ngx.print('</legend>\
');  
  if ngx.var.request_method == "POST" then
    local post_args = ngx.req.get_post_args()
    local action = post_args.action
    if action == "TABLE-EDIT" then
      local index = post_args.index
      if umgrData[tonumber(index)][1] == currentuser then
        umgrColumns[2].readonly = true
      end
    end
  end
  ngx.print(ui_helper.createTable(umgrColumns, umgrData, umgrOptions, umgrAttributes, umgrHelpmsg))
  ngx.print('\
</fieldset>\
</form>\
</div>\
\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
\
<script src="/js/srp-min.js" ></script>\
<script type="text/javascript" >\
  var oldusername = $(\'input[name="name"]\').val();\
\
  ');  -- In case user name modifed, the old user name has to be fetched from session during error case.
  if session:retrieve("editedUserName") then  ngx.print('\
    oldusername = "');  ngx.print(session:retrieve("editedUserName")); ngx.print('"\
  ');  end  ngx.print('\
\
  var userNameCheckMessage = "');  ngx.print( T"User name cannot be empty" ); ngx.print('";\
  var passCheckErrMessage = "');  ngx.print( T"Provide a password to prevent unauthorized access to the gateway." ); ngx.print('";\
  var passValidationErrMessage = "');  ngx.print( string.format(T"Password must contain at least %d alphanumeric characters including both upper and lower case letters,",passwordlength) .. "<br/>" .. T"at least one number and at least one special character" ); ngx.print('";\
  var passMatchErrMessage = "');  ngx.print( T"Passwords do not match" ); ngx.print('";\
  var oldPassIncorrectErrMessage ="');  ngx.print( T"Old password is incorrect" ); ngx.print('";\
  var legacySaltsValue = "');  ngx.print( legacySalts ); ngx.print('";\
  var userNamesValue = "');  ngx.print( userNames ); ngx.print('";\
  var passwordlength = "');  ngx.print( passwordlength ); ngx.print('";\
</script>\
<script src="js/usermgr.js"></script>\
'); 