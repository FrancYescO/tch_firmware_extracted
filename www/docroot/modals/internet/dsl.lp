--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')
local ngx = ngx
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local ui_helper = require("vdf_ui_helper")
local vdf_helper = require("vodafone_helper")

local paramMap = {
  maxAGG = "uci.xdsl.xdsl.@dsl0.maxaggrdatarate",
  maxDown = "uci.xdsl.xdsl.@dsl0.maxdsdatarate",
  maxUs = "uci.xdsl.xdsl.@dsl0.maxusdatarate",
}
local validateMap = {
  maxAGG = post_helper.getValidateNumberInRange(0, 2147483647),
  maxDown = post_helper.getValidateNumberInRange(0, 2147483647),
  maxUs = post_helper.getValidateNumberInRange(0, 2147483647),
}
local content = {
  physicalStatus = "sys.class.xdsl.@line0.LinkStatus"
}
content_helper.getExactContent(content)

local dslStatus = vdf_helper.handlePOST(post_helper.handleQuery, {paramMap, validateMap})

local lp = require("web.lp")
lp.setpath("/www/docroot/")
  ngx.print('\
\
<script src="js/global-min.js"></script>\
<form id="dsl-form" class="form-horizontal" method="post" action="modals/internet/dsl.lp">\
<input type="hidden" name="CSRFtoken" id="CSRFtoken" value="');  ngx.print(CSRFtoken); ngx.print('"></input>\
<input type="hidden" name="action" id="action" value="SAVE"></input>\
<h1><span>');  ngx.print(T"DSL"); ngx.print('</span></h1>\
');  
  local row = {
    {
        label   = T"Physical Link Status",
        element = ui_helper.createOnlyText({id = "dsl-physical-status"}, content["physicalStatus"])
    },
    {
        label   = T"Maximum Aggregate Data Rate (Kbps)",
        element = ui_helper.createTextField({name= "maxAGG", id = "maxAGG", type = "text", value = dslStatus.maxAGG == "" and "0" or dslStatus.maxAGG})
    },
    {
        label   = T"Maximum Downstream Data Rate (Kbps)",
        element = ui_helper.createTextField({name = "maxDown", id = "maxDown", type = "text", value = dslStatus.maxDown == "" and "0" or dslStatus.maxDown})
    },
    {
        label   = T"Maximum Upstream Data Rate (Kbps)",
        element = ui_helper.createTextField({name = "maxUs", id = "maxUs", type = "text", value = dslStatus.maxUs == "" and "0" or dslStatus.maxUs})
    }
  }
  ngx.print(ui_helper.createTable(row, "", "h3-content vdf-table mobile-padding-bottom-lg internet-time-border"))

  lp.include("apply-cancel.lp")
  ngx.print('\
</form>\
\
<script>\
$(function() {\
  var elements = {\
    maximumAgg: "#maxAGG",\
    maximumDown: "#maxDown",\
    maximumUp: "#maxUs"\
  }\
  var validations = {\
    maximumAgg: validateNumberRange(0, 2147483647),\
    maximumDown: validateNumberRange(0, 2147483647),\
    maximumUp: validateNumberRange(0, 2147483647)\
  }\
\
  $("#global-apply").click(function() {\
    if (!validateElements(elements, validations)) return false;\
    postHandler("/modals/internet/dsl.lp", $("#dsl-form").serializeArray());\
  });\
});\
\
</script>\
\
'); 