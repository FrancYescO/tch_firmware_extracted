--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-parental')

local format = string.format
local table = table
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
-- local tprint = require("tch.tableprint")

local content_parental = {
  state = "uci.parental.general.enable",
  exclude = "uci.parental.general.exclude",
}
content_helper.getExactContent(content_parental)

local uci_parental_path = "uci.parental.URLfilter."
local parental_columns = {
    {
        header = T"Site",
        name = "site",
        param = "site",
        type = "text",
        attr = { input = { class="span2" } },
    },
    {
        header = T"Device",
        name = "device",
        param = "device",
        type = "text",
        attr = { input = { class="span2"} },
    },
}

local parental_options = {
    tableid         = "urlfilter",
    basepath        = uci_parental_path,
}

-- get an initial read from UCI
local parental_data = post_helper.handleTableQuery(parental_columns, parental_options)
local rulecount = 0

-- Parental Control data
function updataParentalTableData ()
    local data = parental_data
    local urlCount = 0
    local id = 0

    -- just looking for a count of entries to return for now
    for id, val in ipairs (data) do
	    urlCount = id
    end
    return data, urlCount
end

parental_data, rulecount = updataParentalTableData()

local blockenabled = true
local switchtext
local n_block_rules

if (content_parental["state"] == '1') then
    switchtext = T"Site blocking enabled"
    blockenabled = "1"
else
    switchtext = T"Site blocking disabled"
    blockenabled = "0"
end

n_block_rules = tonumber(rulecount)
local proxy = require("datamodel")
local tod_count = proxy.getPN("uci.tod.host.", true)
tod_count = tod_count and #tod_count or 0




local modalPath = nil
local switchName = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/parental-modal.lp") then
    modalPath = "/modals/parental-modal.lp"
    modal_link = 'class="modal-link" id = "Site_Blocking_Count" data-toggle="modal" data-remote="modals/parental-modal.lp" data-id="parental-modal"'
ngx.print('\
<div class="span3">\
  <div class="smallcard">', 
  ui_helper.createCardHeader(T"Parental Controls", modalPath, switchName, nil), '\
    <div class="content card_bg" data-bg-text="&#xf023;">\
        <div class="divtable">',
            ui_helper.createSimpleLight(blockenabled, switchtext, { light = { id =  "Site_BlockingStatus_Led" }, span = { id =  "Site_Blocking_Status" } }),
            '<p></p>',
            '<p class="subinfos">',
            format( N("<strong %s>%d Site Blocking</strong> rule defined",
                      "<strong %s>%d Site Blocking</strong> rules defined", n_block_rules),
                      modal_link, n_block_rules),
            '</p>');
            if session:hasAccess("/modals/tod-modal.lp") then
            modal_link = 'class="modal-link" id = "Site_Blocking_Count" data-toggle="modal" data-remote="modals/tod-modal.lp" data-id="tod-modal"'

	    ngx.print('\
            <p class="subinfos">',
            format( N('<strong %1$s>%2$d ToD</strong> rule defined',
                      '<strong id="ToD Rules" %1$s>%2$d ToD</strong> rules defined', tod_count),
                      modal_link, tod_count), '\
            </p>');
            end
            ngx.print('\
      </div>\
    </div>\
  </div>\
</div>');
end 