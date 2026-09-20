--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')

local io = io
local ngx = ngx
local pairs = pairs
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local vdf_helper = require("vodafone_helper")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local ui_helper = require("vdf_ui_helper")
local json = require("dkjson")
local variant = vdf_helper.getVariant()
local untaint = string.untaint
local filePath, content
local downloadNat, removeTemp = {}, {}

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().natMapping == "NAT" then
  local path = proxy.get("sys.conn.")
  local activeConnections
  local connContent = {}
  for i,v in ipairs(path) do
    connContent[#connContent + 1] = {value = v.value, path = v.path, type = v.type, param = v.param}
    if v.param == "ActiveConnections" then
      activeConnections = v.value
    end
  end
  local connectedHosts = content_helper.convertResultToObject("sys.conn.host.", connContent)
  local connectionsPerHostData = {}
  local index = 0
  for i,v in pairs(connectedHosts) do
    if (v.IPAddress ~= "") then
      index = index + 1
      connectionsPerHostData[#connectionsPerHostData +1 ] = {
        index,
        v.HostName,
        v.IPAddress,
        v.NumberOfConnections
      }
    end
  end

  local neighTableData = {}
  local indexv6 = 0
  if variant ~= "VF-UK" then
    for i,v in pairs(connectedHosts) do
      if (v.IP6Address ~= "") then
        indexv6 = indexv6 + 1
        neighTableData[#neighTableData +1 ] = {
          indexv6,
          v.HostName,
          v.IP6Address,
          vdf_helper.macToLinkLocalAddress(untaint(v.MACAddress)),
          v.NeighborNumberOfConnections
        }
      end
    end
  end
  ngx.header.content_type = "application/json"
  local responseData = {
    connectionsPerHostData = connectionsPerHostData,
    neighTableData = neighTableData,
    activeConnections = activeConnections
  }
  ngx.print(json.encode(responseData))
  ngx.exit(ngx.OK)
end

if ngx.req.get_method() == "POST" then
  if ngx.req.get_post_args().action == "downloadipv4nat" then
    downloadNat = {["sys.conn.DownloadIPv4NatTable"] = "1"}
    filePath = "/tmp/ipv4Session.csv"
    content = "attachment; filename=ipv4Session.csv"
    removeTemp  = {["sys.conn.DownloadIPv4NatTable"] = "0"}
  elseif ngx.req.get_post_args().action == "downloadipv6nat" then
    downloadNat = {["sys.conn.DownloadIPv6NatTable"] = "1"}
    filePath = "/tmp/ipv6Session.csv"
    content = "attachment; filename=ipv6Session.csv"
    removeTemp = {["sys.conn.DownloadIPv6NatTable"] = "0"}
  else
    ngx.exit(ngx.HTTP_OK)
  end
  proxy.set(downloadNat)
  ngx.header.content_disposition = content
  ngx.header.content_type = "application/octet-stream"
  ngx.header.set_cookie = "fileDownload=true; Path=/"  -- the JS download code requires this cookie
  local file = io.open(filePath)
  if file then
    ngx.print(file:read("*all"))
    file:close()
  else
    ngx.print(T"Error reading the file")
  end
  proxy.set(removeTemp)
  proxy.apply()
  ngx.exit(ngx.HTTP_OK)
end

  ngx.print('\
<div id = "nat-mapping">\
  <h1>');  ngx.print(T"NAT Mapping Table"); ngx.print('</h1>\
  <h2>');  ngx.print(T"The NAT Mapping Table displays the current NAT address mappings."); ngx.print('</h2>\
  ');  
    local row = {
      {
        label = T"Active connections",
        element = ui_helper.createOnlyText({
          id = "natmapping_info_conn"}),
        rowClass = "row",
        colLeftClass = "col-xs-5 col-md-5 col-sm-5 col-lg-5 padding-top-bottom-20",
        colRightClass = "col-xs-3 col-md-2 col-sm-2 col-lg-2 text-left padding-top-bottom-20"
      }
    }
    ngx.print(ui_helper.createTable(row, "", "h3-content nat-mapping-padding-bottom-50 padding-bottom-lg"))

    ngx.print('\
  <h3>');  ngx.print(T"Connections Per Host"); ngx.print('</h3>\
  ');  
    local columns = {"", T"Host Name", T"IP Address", T"Number of Connections"}
    local classInfo = {
      outerDivClass = "h3-content content-nat-mapping nat-mapping-padding-bottom-50 nat-mapping-padding-bottom-54",
      innerDivClass = "table-responsive",
      tableClass = "table wan-table lan-table",
      tableId = "natmapping-conn-info-table"
    }
    ngx.print(ui_helper.createTrTable(classInfo, columns, {}))
    local Msg = {
      label = T"Fetching values... Please wait"
    }
    ngx.print(ui_helper.createLoadingMsg(Msg))

    row = {
      {
        label = T"Download the complete NAT address mapping table in CSV format",
        element = ui_helper.createClickButton({
          class="button button-cancel mob-button-width",
          id = "natmapping-btn-dwnloadhost",
          value=T"Download",
          type="button"
          }) or "",
        rowClass = "vdf-row padding-top-bottom-20",
        colRightClass = "right text-right mobile-margin-top",
      }
    }
    ngx.print(ui_helper.createTable(row, "", "h3-content vdf-table nat-mapping-padding-bottom-50"))
    ngx.print('\
  ');  if variant ~= "VF-UK" then  ngx.print('\
    ');  if variant == "NZ" then  ngx.print('\
      <h3>');  ngx.print(T"Neighbour Table"); ngx.print('</h3>\
    ');  else  ngx.print('\
      <h3>');  ngx.print(T"Neigh Table"); ngx.print('</h3>\
    ');  end
      columns = {T"Host Name", T"IPv6 Global Address", T"IPv6 Link Local Addr", T"# Connections"}
      classInfo = {
        outerDivClass = "h3-content content-nat-mapping nat-mapping-padding-bottom-50",
        innerDivClass = "table-responsive",
        tableClass = "table wan-table lan-table neigh-table",
        tableId = "natmapping-neigh-info-table"
      }
      ngx.print(ui_helper.createTrTable(classInfo, columns, {}))
      ngx.print(ui_helper.createLoadingMsg(Msg))
      row = {
        {
          label = T"Download the complete NAT address mapping table in CSV format",
          element = ui_helper.createClickButton({
            class="button button-cancel mob-button-width",
            id = "natmapping-btn-neigh",
            value=T"Download",
            type="button"
            }) or "",
          rowClass = "vdf-row padding-top-bottom-20",
          colRightClass = "right",
        }
      }
      ngx.print(ui_helper.createTable(row, "", "h3-content vdf-table nat-mapping-padding-bottom-50"))
      ngx.print('\
  ');  end  ngx.print('\
</div>\
<script>\
var target = "modals/status-support/natMappingTable.lp";\
var actionValue;\
function getValue(data, id) {\
  $("#" + id).html(data)\
  if (data) {\
    $("#natmapping-btn-neigh").show();\
    $("#natmapping-btn-dwnloadhost").show();\
  }\
  else {\
    $("#natmapping-btn-neigh").hide();\
    $("#natmapping-btn-dwnloadhost").hide();\
  }\
}\
$(function() {\
  $(".loading-fetching").modal("show");\
  $(".modal-backdrop").remove();\
  var target = "/modals/status-support/natMappingTable.lp";\
  $.get(target+"?natMapping=NAT", function(response) {\
    createStatusTable(response.connectionsPerHostData, "natmapping-conn-info-table")\
    createStatusTable(response.neighTableData, "natmapping-neigh-info-table")\
    if (response.activeConnections != "") {\
      getValue(response.activeConnections, "natmapping_info_conn")\
    }\
    $(".loading-fetching").modal("hide");\
  });\
  $("#natmapping-btn-neigh, #natmapping-btn-dwnloadhost").click(function() {\
    if (this.id == \'natmapping-btn-dwnloadhost\') {\
        actionValue = "downloadipv4nat"\
    }\
    else if (this.id == \'natmapping-btn-neigh\') {\
      actionValue = "downloadipv6nat"\
    }\
    $.fileDownload(target, {\
      httpMethod: "POST",\
      data: new Array({ name : "action", value : actionValue },\
                      { name : "CSRFtoken", value : "');  ngx.print(CSRFtoken); ngx.print('" }),\
      failCallback: function() {\
        window.location("/");\
      }\
    });\
  });\
});\
</script>\
\
'); 