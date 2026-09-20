--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local taint_mt = require("web.taint").taint_mt
local type, setmetatable, random = type, setmetatable, math.random
local table, ipairs, istainted, format = table, ipairs, string.istainted, string.format
local untaint = string.untaint
local srp = require("srp")
local session = ngx.ctx.session
local printf = require("web.web").printf

-- Shortcuts to validation helpers to make lines shorter
local gVIES = post_helper.getValidateInEnumSelect
local vNES = post_helper.validateNonEmptyString
local gVSLIR = post_helper.getValidateStringLengthInRange
local gAV = post_helper.getAndValidation

-- Start for legacy migration: GUI username/password [NG-48489]
local users = content_helper.getMatchedContent("uci.web.user.")
local userNames = ""
local legacySalts = ""

for _, user in ipairs(users) do
  if user.legacy_salt ~= "" then
    userNames = userNames .. user.name ..","
    legacySalts = legacySalts .. user.legacy_salt .. ","
  end
end
-- End for legacy migration: GUI username/password [NG-48489]

local function gVEL(len)
    return function(value, object, key)
        if type(value) ~= "string" and not istainted(value) then
            return nil, "Received a non string value"
        end
        if #value ~= len then
            return nil, format("String must be exactly %d characters long", len)
        end
        return true
    end
end

if ngx.req.get_method() == "POST" then
    local post_args = ngx.req.get_post_args()
    local I, A, M = untaint(post_args.I), untaint(post_args.A), untaint(post_args.M)
    if I and A then
        local user = content_helper.getMatchedContent("uci.web.user.",{name=I})
        if user and #user > 0 then
            user = user[1]
        end
        local verifier, B = srp.Verifier(I, untaint(user.srp_salt), untaint(user.srp_verifier), A)
        session:store("verifier",verifier)
        session:store("edited_user", I)
        ngx.header.content_type = "application/json"
        printf('{ "s":"%s", "B":"%s" }', user.srp_salt, B)
        ngx.exit(ngx.HTTP_OK)
    end
    if M then
        local verifier =  session:retrieve("verifier")
        session:store("verifier",nil)
        ngx.header.content_type = "application/json"
        local M2, errmsg = verifier:verify(M)
        if M2 then
            local user = session:retrieve("edited_user")
            session:store("verified_user",user)
            printf('{ "M":"%s" }', M2)
        else
            printf('{ "error":"%s" }', errmsg or "failed")
        end
        ngx.exit(ngx.HTTP_OK)
    end
end

local roleslist = {
    { "admin", T"Admin"},
}

local password_warning = {
    alert = {
        class = "alert",
        style="margin-left:15px;display:inline;font-size:15px;",
    },
}
local warning = ui_helper.createAlertBlock(T"Provide a password to prevent unauthorized access to the gateway.", password_warning)

local umgr_columns = {
    {
        header = T"Name",
        name = "name",
        param = "name",
        type = "text",
        attr = { input = { class="span2" } },
    },
    {
        header = T"Role",
        name = "role",
        param = "role",
        default = "admin",
        type = "select",
        values = roleslist,
        attr = { select = { class="span2" } },
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
                attr = { input = { class="span2", id = "usrmodal_password" },},
            },
            {
                header = T"Repeat Password",
                name = "password2",
                param = "password2",
                type = "password",
                attr = { input = { class="span2" }},
            },
            {
                header = T"SRP salt",
                name = "srp_salt",
                param = "srp_salt",
                type = "hidden",
                attr = { },
            },
            {
                header = T"SRP verifier",
                name = "srp_verifier",
                param = "srp_verifier",
                type = "hidden",
                attr = { },
            },

        },
    }
}
if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "TABLE-EDIT" then
    local oldpassword = {
        header = T"Old Password",
        name = "oldpassword",
        type = "password",
        attr = { input = { class="span2"}}
    }
    table.insert(umgr_columns[3].subcolumns,1,oldpassword)
end
local umgr_attributes = {
}

local wu = {}
local users
local currentuser = ngx.ctx.session:getusername()

local umgr_filter = function(data)
    if not users then -- we need to initialize it after the current table operation happened so do this on the first run of umgr_filter
        -- this is because filter is called in loadTableData which happens after committing the current operation
        users = setmetatable({}, taint_mt)
        content_helper.addListContent(wu, { users = "uci.web.sessionmgr.@default.users." })
        for _,v in ipairs(wu.users) do
            users[v] = true
        end
    end
    local name = data.paramindex -- name of the entry
    local username = data.name

    -- check either it's an already existing entry
    if name and users[name] then
        if name == "usr_guest" then
            return nil
        elseif name == "usr_admin" or currentuser == username then
            return {
                canEdit = true,
                canDelete = false
            }
        else
            return true
        end
    else
        return nil
    end
end

local umgr_defaultObject = nil

-- when creating a new user, name the entry with a random name otherwise won't be able to retrieve the name of the entry
-- after calling proxy.add
local function generateNewObjectname()
    return "usr_default_" .. tostring(random()):sub(3)
end

local umgr_options = {
    tableid = "usermgr",
    basepath = "uci.web.user.@.",
    createMsg = T"Add new user",
    addNamedObject = true,
    sorted = "name",
    objectName = generateNewObjectname(),
}

local function userStateModified(object)
    local post_args = ngx.req.get_post_args()
    local action = string.format("%s", post_args.action)
    if action == "TABLE-MODIFY" then
        local basepath = "uci.web.user.@" .. umgr_options.changesessionindex .. "."
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

local function validateName(value, object, key)
    local state, msg = vNES(value)
    if not state then
        return nil, msg
    end
    if ngx.req.get_post_args().action == "TABLE-MODIFY" then
        local user = session:retrieve("verified_user")
        session:store("verified_user",nil)
        local usrname_fromuci = proxy.get("uci.web.user.@" .. umgr_options.changesessionindex .. ".name")
        if usrname_fromuci then
            if user ~= usrname_fromuci[1].value then
                return nil, T"Old password must be validated"
            end
        end
        local defaultusers = {}
        content_helper.addListContent(defaultusers, { users = "uci.web.sessionmgr.@default.users." })
        for _,usrrolename in ipairs(defaultusers.users) do
            local path = format("uci.web.user.@%s.name", usrrolename)
            local usrname = proxy.get(path)
            if usrname ~= nil then
                if value == usrname[1].value and usrrolename ~= umgr_options.changesessionindex then
                    return nil, T"A user with this username already exists"
                end
            end
        end
        return true
    end
    return state, msg
end

local umgr_valid = {
    name = gAV(validateName,gVSLIR(1,63)),
    role = gVIES(roleslist),
    srp_salt = gVEL(8),
    srp_verifier = gVEL(512),
    password = clearPassword,
    password2 = clearPassword,
}

local function onAdd(index, content)
    local result, msg = ngx.ctx.session:addUserToManager(index)
    umgr_options.errmsg = msg
end

local function onDelete(index)
    local result, msg = ngx.ctx.session:delUserFromManager(index)
    umgr_options.errmsg = msg
end

local function onModify(index, content)
    local result, msg = ngx.ctx.session:reloadAllUsers()
    umgr_options.errmsg = msg
end

umgr_options.onAdd = onAdd
umgr_options.onModify = onModify
umgr_options.onDelete = onDelete

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

local umgr_data, umgr_helpmsg = post_helper.handleTableQuery(umgr_columns, umgr_options, umgr_filter, umgr_defaultObject, umgr_valid)

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Management", false, false))   ngx.print('\
\
<div class="modal-body update">\
');  
local tabs = {
    {
        desc = T"User Manager",
        active = "active",
        target = "modals/usermgr-modal.lp",
    },
    {
        desc = T"Log viewer",
        target = "modals/logviewer-modal.lp",
    },
}
ngx.print(ui_helper.createModalTabs(tabs))
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
    ngx.print(ui_helper.createTable(umgr_columns, umgr_data, umgr_options, umgr_attributes, umgr_helpmsg))
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
    function clear_error_password()\
    {\
        var upass = $(\'.modal input[name="password"],.modal input[name="password2"],.modal input[name="oldpassword"]\');\
        upass.removeClass("tooltip-on error");\
        upass.closest(".control-group").removeClass("error");\
        upass.next().remove();\
    }\
\
    function display_error_password(msg)\
    {\
        var upass = $(\'.modal input[name="password"],.modal input[name="password2"]\');\
        upass.addClass("error");\
        upass.closest(".control-group").addClass("error");\
        upass.first().after(\'<span class="help-inline">\' + msg + \'</span>\');\
    }\
\
    function clear_error_user()\
    {\
        var uinput = $(\'.modal input[name="name"]\');\
        uinput.removeClass("tooltip-on").removeClass("error");\
        uinput.closest(".control-group").removeClass("error");\
    }\
\
    function display_error_user()\
    {\
        var uinput = $(\'.modal input[name="name"]\');\
        uinput.addClass("tooltip-on error");\
        uinput.attr("placement", "top");\
        uinput.attr("data-original-title", "');  ngx.print( T"User name cannot be empty" ); ngx.print('");\
        uinput.closest(".control-group").addClass("error");\
        $(\'.tooltip-on\').tooltip();\
    }\
\
    // "Disable" the existing handler by removing the class it matches on (tried to use the off() method of jquery to no avail)\
    $(".modal .btn-table-modify").removeClass("btn-table-modify").addClass("btn-table-modify-custom");\
    $(".modal .btn-table-add").removeClass("btn-table-add").addClass("btn-table-add-custom");\
    $(".modal .btn-table-modify-custom,.modal .btn-table-add-custom").on("click", function () {\
        clear_error_user();\
        clear_error_password();\
\
        var self = this;\
        var user = $(\'input[name="name"]\').val();\
        var password = $(\'input[name="password"]\').val();\
        var password2 = $(\'input[name="password2"]\').val();\
        var salt = $(\'input[name="srp_salt"]\').val();\
        var verifier = $(\'input[name="srp_verifier"]\').val();\
\
        if(password !== password2) {\
            display_error_password("');  ngx.print( T"Passwords do not match" ); ngx.print('");\
            return;\
        }\
\
        if(user == "") {\
            display_error_user();\
            return;\
        }\
\
        function sendData()\
        {\
            var target = $(".modal form").attr("action");\
            var table = $(self).closest("table");\
            var id = table.attr("id");\
            var line = $(self).closest("tr");\
            var index = line.index();\
            var action;\
            var params = table.find(".line-edit :input").serializeArray();\
            \
            if($(self).hasClass("btn-table-add-custom")) {\
                action = "TABLE-ADD";\
            } else {\
                action = "TABLE-MODIFY";\
                index  = index - 2;\
            }\
\
            var add_params = table.find(".additional-edit :input").serializeArray();\
            params = params.concat(add_params);\
            params.push({\
                name : "tableid",\
                value : id\
            });\
            params.push({\
                name : "stateid",\
                value : table.attr("data-stateid")\
            });\
            params.push({\
                name : "action",\
                value : action\
            });\
            params.push({\
                name : "index",\
                value : index + 1\
            });\
            params.push(tch.elementCSRFtoken());\
            tch.loadModal(target, params, function() {\
                tch.scrollRowIntoView(id, index);\
            });\
        }\
\
        var srp = new SRP();\
        function generateSaltAndVerifier() {\
            srp.generateSaltAndVerifierTheCallback(user, password, function(salt, verifier) {\
                $(\'input[name="srp_salt"]\').val(salt);\
                $(\'input[name="srp_verifier"]\').val(verifier);\
                $(\'input[name="password"]\').val(""); // clean that up no need to send it over the air\
                $(\'input[name="password2"]\').val("");\
                $(\'input[name="oldpassword"]\').val("");\
                sendData();\
            });\
        }\
        srp.success = generateSaltAndVerifier;\
        srp.error_message = function() {\
            var upass = $(\'.modal input[name="oldpassword"]\');\
            upass.addClass("error");\
            upass.closest(".control-group").addClass("error");\
            upass.first().after(\'<span class="help-inline">');  ngx.print(T"Old password is incorrect"); ngx.print('</span>\');\
        }\
        var oldpassword = $(\'input[name="oldpassword"]\').val();\
        if(oldpassword != undefined) {\
            //Start for legacy migration: GUI username/password [NG-48489]\
            var legacySalts = "');  ngx.print( legacySalts ); ngx.print('";\
            var userNames = "');  ngx.print( userNames ); ngx.print('";\
            var index = -1;\
            var userNameArray = userNames.split(",")\
            var legacySaltArray = legacySalts.split(",")\
\
            for (var i = 0; i < userNameArray.length - 1; i ++)\
            {\
              if (oldusername == userNameArray[i])\
              {\
                index = i;\
              }\
            }\
\
            if (index >= 0)\
            {\
              var hashObj = new jsSHA((legacySaltArray[index]+tch.stringToHex(oldpassword)), "HEX");\
              oldpassword = hashObj.getHash("SHA-1", "HEX");\
            }\
            //End for legacy migration: GUI username/password [NG-48489]\
\
            srp.identify("/modals/usermgr-modal.lp", oldusername, oldpassword);\
        }\
        else {\
            generateSaltAndVerifier();\
        }\
    });\
</script>\
'); 