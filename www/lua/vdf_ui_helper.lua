--- Vodafone UI helper module
--  @module vdf_ui_helper
--  @usage local ui_helper = require('vdf_ui_helper')
--  @usage require('vdf_ui_helper')

local format = string.format
-- local intl = require("web.intl")
-- local function log_gettext_error(msg)
--  ngx.log(ngx.NOTICE, msg)
-- end
-- local gettext = intl.load_gettext(log_gettext_error)
-- local T = gettext.gettext
-- local N = gettext.ngettext

local M = {}

function tableToAttr(tbl)
  local attributes = {}
  for k, v in pairs(tbl) do
    if k ~= "checked" then
      attributes[#attributes+1] = format("%s='%s'", k, v)
    end
  end
  return table.concat(attributes, " ")
end

function M.createDropDown(attr, options, selectedOption, additionalOptions)
  local dropDownoptions  = {}
  options = options and next(options) and options or {}
  additionalOptions = type(additionalOptions) == "table" and additionalOptions or {}
  selectedOption = selectedOption or ""
  for i, v in ipairs(additionalOptions) do
    local selected = v[1] == selectedOption and 'selected="selected"' or ''
    dropDownoptions[#dropDownoptions +1 ] = format('<option %s value="%s">%s</option>', selected, v[1], v[2])
  end
  for i, v in ipairs(options) do
    local selected = v[1] == selectedOption and 'selected="selected"' or ''
    dropDownoptions[#dropDownoptions +1 ] = format('<option %s value="%s">%s</option>', selected, v[1], v[2] or v[1])
  end
  dropDownoptions = table.concat(dropDownoptions, "\n")
  return format('<select %s>%s</select>', tableToAttr(attr), dropDownoptions)
end

function M.createDaysCheckbox(outerRowClass, checkboxRowClass, inputId )
  local days = { T"Monday", T"Tuesday", T"Wednesday", T"Thursday", T"Friday", T"Saturday", T"Sunday" }
  local rows = {}
  for i, v in ipairs(days) do
    rows[i] = format([[
      <div class="%s">
        <div class="%s">
          <input id="%s" class="checkbox checkbox-unchecked show-hide-pw" data-id="1" type="checkbox">
          <label for="%s"></label>
        </div>
        <div class="individual-days-day-wrap">
          <span>%s</span>
        </div>
      </div>
    ]], outerRowClass, checkboxRowClass, inputId .. i, inputId .. i, v)
    if i == 1 or i == 6 then
      rows[i] = format([[<div class="col-md-6 col-sm-6 modal-padding-lrt-none btn-wrap-mobile no-padding"> %s]], rows[i])
    end
    if i == 5 or i == 7 then
      rows[i] = format([[%s </div>]], rows[i])
    end
  end
  return table.concat(rows, "\n")
end

function M.createButton(attr)
  return format('<div %s></div>', tableToAttr(attr))
end

function M.createInputButton(attr)
  return format('<input %s>', tableToAttr(attr))
end

function M.createTextField(attr)
  return format('<input %s>', tableToAttr(attr))
end

function M.createTimeField(startTimeDivId, startTimeTextId, stopTimeDivId, stopTimeTextId)
        local from  = T"From"
        local to = T"To"
        return format([[
          <div class="halfWidth no-important no-padding-left-right from-to-textbox" id="%s">
            <span>%s</span> <input maxlength="5" id="%s" class="max5 max5-range parent-max5 time" placeholder="HH:MM" type="text" />
          </div>
          <div class="halfWidth no-important no-padding-left-right from-to-textbox" id="%s">
            <span>%s</span> <input maxlength="5" id="%s" class="max5 max5-range parent-max5 time" placeholder="HH:MM" type="text" />
          </div>
        ]], startTimeDivId, from, startTimeTextId, stopTimeDivId, to, stopTimeTextId)
end

function M.createMACAddressFields(id, class, mac)
  class = class or ""
  mac = mac or ""
  local html = {}
  local macOctets = {}
  for octet in mac:gmatch("%x+") do
    macOctets[#macOctets+1] = octet
  end
  for i = 1, 6 do
    html[#html+1] = format('<input id="%s%s" maxlength="2" class="max2 alphanum %s" type="text" value="%s"/>', id, i, class, macOctets[i] or "")
    if i < 6 then
      html[#html+1] = '<span>:</span>'
    end
  end
  return table.concat(html, "\n")
end

function M.createPortRadioButton(portDetails)
  return format([[
    <span class="fL">
      <input name="%s" value="1" class="radio radio-checked" checked="checked" id="%s" type="radio" />
      <label for="%s" style="margin-right: 10px;"></label>
      <span>%s</span>
    </span>
    <span>
      <input name="%s" value="2" class="radio radio-checked" id="%s" type="radio" />
      <label for="%s" style="margin-right: 10px;"></label>
      <span>%s</span>
    </span>
  ]], portDetails.radioName, portDetails.radioId1, portDetails.radioId1, T"Port",
      portDetails.radioName, portDetails.radioId2, portDetails.radioId2, T"Port range")
end

function M.createIPAddressFields(id, class, IPAddress, newLine, placeholder)
  id = id or ""
  IPAddress = IPAddress or ""
  local html = {}
  local IPOctets = {}
  for octet in IPAddress:gmatch("%d+") do
    IPOctets[#IPOctets+1] = octet
  end
  if type(class) == "string" then
    class = {class, class, class, class}
  elseif not class then
    class = {}
  end
  for i = 1, 4 do
    html[#html+1] = format('<input type="number" id="%s%s" maxlength="3" min="0" max="255" step="1" class="max3 ip %s" value="%s" placeholder="%s"/>', id, i, class[i] or "", IPOctets[i] or "", placeholder or "")
    if i < 4 then
      html[#html+1] = '<span>.</span>'
    end
  end
  if newLine then
    return table.concat(html, "\n")
  else
    return table.concat(html, "")
  end
end

function M.createRow(row)
  row.rowClass = row.rowClass or "vdf-row"
  row.rowId = row.rowId or ""
  row.colLeftClass = row.colLeftClass or "left"
  row.colLeftId = row.colLeftId or ""
  row.colRightClass = row.colRightClass or "right"
  row.colRightId = row.colRightId or ""
  row.labelClass = row.labelClass or ""
  row.labelId = row.labelId or ""
  local html = format([[
      <div class="%s" id="%s">
          <div class="%s" id="%s">
              <span class="%s" id="%s">%s</span>
          </div>
          <div class="%s" id="%s">
              %s
          </div>
      </div>
    ]], row.rowClass, row.rowId, row.colLeftClass, row.colLeftId, row.labelClass, row.labelId, row.label, row.colRightClass, row.colRightId, row.element)
  return html
end

function M.createSingleRow(row)
  row.rowClass = row.rowClass or "row"
  row.rowId = row.rowId or ""
  row.colClass = row.colClass or ""
  row.colId = row.colId or ""
  local html = format([[
      <div class="%s" id="%s">
          <div class="%s" id="%s">
              %s
          </div>
      </div>
    ]], row.rowClass, row.rowId, row.colClass, row.colId, row.label)
  return html
end
function M.createTable(rows, id, class)
  local row = {}
  for _, v in ipairs(rows) do
    row[#row+1] = M.createRow(v)
  end
  rows = table.concat(row, "\n")
  local html = format([[
    <div id="%s" class="%s">
      %s
    </div>
  ]], id, class, rows)
  return html
end

function M.createLoadingMsg(row)
  return format([[
    <div class="loading-fetching h3-content">
      <div class="col-sm-12 col-md-12 col-lg-12 text-center">
         <img src="/img/look_4/icons/icon-thinking.gif" alt="Loading..."/>
         %s
      </div>
    </div>
  ]], row.label)
end

function M.createOnlyText(attr, value)
  value = value or ""
  return format('<span %s>%s</span>', tableToAttr(attr), value)
end

function M.createHiddenField(id, name, value, class)
  id = id or ""
  name = name or ""
  value = value or ""
  class = class or ""
  return format('<input name="%s" id="%s" class="%s" type="hidden" value="%s">', name, id, class, value)
end

function M.createTrTable(tableInfo, columns, data)
  tableInfo.outerDivClass = tableInfo.outerDivClass or ""
  tableInfo.outerId = tableInfo.outerId or ""
  tableInfo.innerDivClass = tableInfo.innerDivClass or ""
  tableInfo.innerId = tableInfo.innerId or ""
  tableInfo.tableClass = tableInfo.tableClass or ""
  tableInfo.tableId = tableInfo.tableId or ""
  tableInfo.tbodyClass = tableInfo.tbodyClass or ""
  local tableHeader = {}
  tableHeader[#tableHeader +1]  = '<tr>'
  for _, v in ipairs(columns) do
    tableHeader[#tableHeader +1] = format('<th><span>%s</span></th>', v)
  end
  tableHeader[#tableHeader + 1] = '</tr>'
  tableHeader = table.concat(tableHeader, "\n")
  local tableData = {}
  for _, v in ipairs(data) do
    tableData[#tableData + 1] = '<tr>'
    for _, j in pairs(v) do
      tableData[#tableData + 1] = format('<td>%s</td>', j)
    end
    tableData[#tableData + 1] = '</tr>'
  end
  tableData = table.concat(tableData, "\n")
  local html = format([[
   <div class="%s" id="%s">
     <div class="%s" id="%s">
       <table class="%s" id="%s">
         <tbody class="%s">%s%s</tbody>
       </table>
     </div>
   </div>
  ]],tableInfo.outerDivClass, tableInfo.outerId, tableInfo.innerDivClass, tableInfo.innerId, tableInfo.tableClass, tableInfo.tableId, tableInfo.tbodyClass, tableHeader, tableData )
  return html
end

M.createMultipleRows = function(rows)
    if type(rows) == "table" then
      for i=1,#rows do
        rows[i] = M.createRow(rows[i])
      end
      return unpack(rows)
    end
    return ""
end

function M.createRadioButton(inputattr, labelfor, labelattr, spanattr)
  local check = ""
    if inputattr.checked == "true" then
    check = 'checked = "checked"'
  end
  local html = format([[<input %s %s>
  <label for = "%s" %s></label>
  <span>%s</span>]], tableToAttr(inputattr), check, labelfor, tableToAttr(labelattr), spanattr)
  return html
end

function M.createClickButton(attr)
  return format('<input %s>', tableToAttr(attr))
end

function M.createWifiSection(tableid,tableClass,row1,row2,row3,row4,row5,row6,row7)
  local html = format([[
  <div id="%s" class="%s">
    <div class="row padding-left padding-left-mobile status-border-top left">
        <div class="col-xs-12 col-md-12 col-sm-12 padding-top-bottom-20">
            <div class="inner-row"> <span class="light-font">%s</span> </div>
            <div class="inner-row"> %s </div>
        </div>
    </div>
    %s
    <div class="%s row padding-left padding-left-mobile left-select status-border-top">
        <div class="col-xs-12 col-md-12 col-sm-12 padding-top-bottom-20 full-width-mobile left">
            <div class="inner-row"><span class="light-font">%s</span></div>
            <div class="inner-row">
                <div id="top-info-mode" class="%s rel col-xs-12 col-md-12 col-sm-12 padding-left-right-mobile"> %s </div>
                <div class="two hide" id = "wifi2_readonly_24" style="font-weight: bold;padding-top: 22px">2.4 GHz</div>
                <div class="five hide" id ="wifi2_readonly_5" style="font-weight: bold;padding-top: 22px">5 GHz</div>
            </div>
        </div>
    </div>
    <div class="row padding-left padding-left-mobile left-select status-border-top">
        <div class="col-xs-12 col-md-12 col-sm-12 padding-top-bottom-20 full-width-mobile left">
            <div class="inner-row"> <span class="light-font">%s</span> </div>
            <div class="inner-row">
                <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-left-right-mobile"> %s </div>
            </div>
        </div>
    </div>
    <div class="row padding-left padding-left-mobile padding-top-bottom-20 status-border-top" id = "%s">
        <div class="left child-of-bullet" >
            <div class="inner-row light-font"> <span class="light-font">%s</span> </div>
            <div class="inner-row"> <input id="%s" class="wifiGen-textLabel wifiGen-textBullet"  readonly = "readonly" type = "password" value= "%s"></input>%s</div>
            <div class="inner-row mobile-wifi-fix-width">
                <div class="inner-cell-left mobile-no-padding" style="padding-left: 105px;"> <span>%s</span> </div>
                <div class="inner-cell-right" style="line-height:24px;"> <input id="%s" class="checkbox checkbox-unchecked show-hide-pw" data-id="1" type="checkbox" /> <label for=%s></label> </div>
            </div>
            <div class="inner-row mobile-clear-both" style="float:right;"> <input class="button button-blank change-pw mob-button-width mob-apply-cancel" id="%s" data-id="1" value="%s" type="button" data-toggle="modal" data-target="#passwordModal" /> </div>
        </div>
    </div>
  </div>

  ]],tableid, tableClass ,row1.label, row1.field,row2.field,row3.id,row3.label,row3.class,row3.field,row4.label,row4.field,row5.id,row5.label,row5.labelid,row5.contentvalue,row5.field,
  row6.label, row6.id, row6.labelfor,row7.id, row7.value )

  return html
end
return M
