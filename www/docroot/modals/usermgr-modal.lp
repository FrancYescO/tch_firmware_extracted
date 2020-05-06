<%
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


local wu = {}
local users
local currentuser = ngx.ctx.session:getusername()



-- Shortcuts to validation helpers to make lines shorter
local gVIES = post_helper.getValidateInEnumSelect
local vNES = post_helper.validateNonEmptyString
local gVSLIR = post_helper.getValidateStringLengthInRange
local gAV = post_helper.getAndValidation

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

local roleslist = {
    { "guest", T"Guest"},
    { "admin", T"Admin"},
}
if currentuser == "engineer" then
   roleslist[#roleslist+1] = { "engineer", T"Engineer" }
end

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
        default = "guest",
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
                attr = { input = { class="span2", onkeyup="passwordCheck(this.value)", id = "usrmodal_password" },},
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

local umgr_attributes = {
}


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

local function rvalidation(rl)
    if ngx.var.request_method == "POST" then
        local post_args = ngx.req.get_post_args()
        if post_args.action == "TABLE-MODIFY" and post_args.name == currentuser and post_args.role ~= nil then
             return nil, T"Current user can not edit thier role"
        end
    end
    return gVIES(rl)
end

local function validateName(value)
    local state, msg = vNES(value)
    local defaultusers, temp = {}, {}
    local existeduser, path
    if state then
        content_helper.addListContent(defaultusers, { users = "uci.web.sessionmgr.@default.users." })
        for _,v in ipairs(defaultusers.users) do
            path = format("uci.web.user.@%s.name", v)
            temp = proxy.get(path)
            if temp ~= nil then
                existeduser = format("%s", temp[1].value)
                if  value == existeduser and v ~= umgr_options.changesessionindex then
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
    role = rvalidation(roleslist),
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

local umgr_data, umgr_helpmsg = post_helper.handleTableQuery(umgr_columns, umgr_options, umgr_filter, umgr_defaultObject, umgr_valid)


for i,v in ipairs( umgr_data ) do
    if umgr_data[i][1] == "engineer" and umgr_data[i][1] ~= currentuser then
      table.remove(umgr_data,i)
    end
end
%>

<% ngx.print(ui_helper.createHeader(T"Management", false, false)) %>

<div class="modal-body update">
<%
--[[
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
]]
%>

<form class="form-horizontal" method="post" action="modals/usermgr-modal.lp">
<%
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>

<fieldset>
<legend><%= T"Users list" %></legend>
<%
    if ngx.var.request_method == "POST" then
        local post_args = ngx.req.get_post_args()
        local action = post_args.action
        if action == "TABLE-EDIT" then
            local index = post_args.index
            if umgr_data[tonumber(index)][1] == currentuser then
                umgr_columns[2].readonly = true
            end
        end
    end
    ngx.print(ui_helper.createTable(umgr_columns, umgr_data, umgr_options, umgr_attributes, umgr_helpmsg))
%>
</fieldset>
</form>
</div>

<%= ui_helper.createFooter() %>

<script src="/js/srp-min.js" ></script>
<script type="text/javascript" >

    function clear_error_password()
    {
        var upass = $('.modal input[name="password"],.modal input[name="password2"]');
        upass.removeClass("tooltip-on error");
        upass.closest(".control-group").removeClass("error");
        upass.first().next().remove();
    }

    function display_error_password(msg)
    {
        var upass = $('.modal input[name="password"],.modal input[name="password2"]');
        upass.addClass("error");
        upass.closest(".control-group").addClass("error");
        upass.first().after('<span class="help-inline">' + msg + '</span>');
    }

    function clear_error_user()
    {
        var uinput = $('.modal input[name="name"]');
        uinput.removeClass("tooltip-on").removeClass("error");
        uinput.closest(".control-group").removeClass("error");
    }

    function display_error_user()
    {
        var uinput = $('.modal input[name="name"]');
        uinput.addClass("tooltip-on error");
        uinput.attr("placement", "top");
        uinput.attr("data-original-title", "<%= T"User name cannot be empty" %>");
        uinput.closest(".control-group").addClass("error");
        $('.tooltip-on').tooltip();
    }

    // "Disable" the existing handler by removing the class it matches on (tried to use the off() method of jquery to no avail)
    $(".modal .btn-table-modify").removeClass("btn-table-modify").addClass("btn-table-modify-custom");
    $(".modal .btn-table-add").removeClass("btn-table-add").addClass("btn-table-add-custom");
    $(".modal .btn-table-modify-custom,.modal .btn-table-add-custom").on("click", function () {
        clear_error_user();
        clear_error_password();

        var self = this;
        var user = $('input[name="name"]').val();
        var password = $('input[name="password"]').val();
        var password2 = $('input[name="password2"]').val();
        var salt = $('input[name="srp_salt"]').val();
        var verifier = $('input[name="srp_verifier"]').val();

        if(password !== password2) {
            display_error_password("<%= T"Passwords do not match" %>");
            return;
        }

        if(user == "") {
            display_error_user();
            return;
        }

        function sendData()
        {
            var target = $(".modal form").attr("action");
            var table = $(self).closest("table");
            var id = table.attr("id");
            var line = $(self).closest("tr");
            var index = line.index();
            var params = line.find(":input").serializeArray();
            var add_params = table.find(".additional-edit :input").serializeArray();
            var action;

            if($(self).hasClass("btn-table-add-custom")) {
                action = "TABLE-ADD";
            } else {
                action = "TABLE-MODIFY"
            }

            params = params.concat(add_params);
            params.push({
                name : "tableid",
                value : id
            });
            params.push({
                name : "stateid",
                value : table.attr("data-stateid")
            });
            params.push({
                name : "action",
                value : action
            });
            params.push({
                name : "index",
                value : index + 1
            });
            params.push(tch.elementCSRFtoken());
            tch.loadModal(target, params, function() {
                tch.scrollRowIntoView(id, index);
            });
        }

        var srp = new SRP();
        srp.generateSaltAndVerifierTheCallback(user, password, function(salt, verifier) {
            $('input[name="srp_salt"]').val(salt);
            $('input[name="srp_verifier"]').val(verifier);
            $('input[name="password"]').val(""); // clean that up no need to send it over the air
            $('input[name="password2"]').val("");
            sendData();
        });

        srp.error_message = function() {
            display_error();
        }
    });

    $('#usrmodal_password').parent().after('<div class = "controls"><div id="Strength"></div></div>')
    $('#repeat_pass').parent().css("padding-top" , "5px")

    function passwordCheck(password)
    {
        var level = 0;

        //if password bigger than 6 give 1 point
        if (password.length >= 6) level++;

        //if password has both lower and uppercase characters give 1 point
        if ( ( password.match(/[a-z]/) ) && ( password.match(/[A-Z]/) ) ) level++;

        //if password has at least one number give 1 point
        if (password.match(/\d+/)) level++;

        //if password has at least one special caracther give 1 point
        if ( password.match(/.[!,@,#,$,%,^,&,*,?,_,~,-,(,)]/) )  level++;

        //if password bigger than 8 give another 1 point
        if (password.length >= 8) level++;

        $('#Strength').removeClass().addClass("strength" + level);
    }

</script>
