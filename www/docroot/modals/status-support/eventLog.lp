--pretranslated: do not change this file
 
  -- Enable localization
  gettext.textdomain('webui-core')

  local ngx = ngx
  local proxy = require("datamodel")
  local json = require("dkjson")
  local string = string
  local format = string.format
  local ipairs = ipairs
  local ui_helper = require("vdf_ui_helper")
  local post_helper = require("web.post_helper")
  local content_helper = require("web.content_helper")

  local network_details = {
    gateway_ip = "uci.network.interface.@lan.ipaddr",
    netmask    = "uci.network.interface.@lan.netmask",
    public_IP  = "rpc.network.interface.@wan.ipaddr",
  }
  content_helper.getExactContent(network_details)
  local validateDeviceIP  = post_helper.getValidateStringIsDeviceIPv4(network_details.gateway_ip, network_details.netmask)

  -- syslog generated log patterns for login/logout scenarios
  local invalidLoginPattern = "handleAuth.*Invalid login credentials, client: ([^,]+)"
  local validLoginPattern =  "changeUser.*changing user to (%a+).*, client: ([^,]+)"

  -- Map containing the list of user authentication scenarios and their corresponding customer logs format
  local authLogMap =
  {
    ["invalid_lan"] = "User tries to connect to Web-GUI from LAN with wrong password",
    ["invalid_wan"] = "User tries to connect to Web-GUI from WAN with wrong password",
    ["login_lan"] = "User sucessfully logged in to UI from LAN",
    ["logout_lan"] ="User connected via LAN logged out from UI",
    ["login_wan"] = "User sucessfully logged in to UI from WAN",
    ["logout_wan"] ="User connected via WAN logged out from UI"
  }

  local function reformat(message)
    local user, client
    client = message:match(invalidLoginPattern)
    if client then
      if validateDeviceIP(client) then
        return authLogMap.invalid_lan
      else
        return authLogMap.invalid_wan
      end
    end
    user, client = message:match(validLoginPattern)
    if user and client then
      if validateDeviceIP(client) then -- LAN login/logout
        return user == "default" and authLogMap.logout_lan or authLogMap.login_lan
      else
        return user == "default" and authLogMap.logout_wan or authLogMap.login_wan
      end
    end
    return message
  end

  if ngx.req.get_method() == "POST" then
    ngx.header.content_type = "application/json"
    local postArgs = ngx.req.get_post_args()
    local success
    if postArgs.action == "deleteLog" then
      success = proxy.del("sys.log.")
      if not success then
        ngx.print('{ "status":false }')
        ngx.exit(ngx.HTTP_OK)
      end
      ngx.print('{ "success":true }')
    elseif postArgs.action == "selectedCategories" then
      success = proxy.set("uci.system.system.@system[0].selected_logs", postArgs.selectedCategories)
      if success then
        ngx.print('{ "success":true }')
      else
        ngx.print('{ "status":false }')
      end
    end
    ngx.exit(ngx.HTTP_OK)
  end

  local categoryNames = {
    { "system"   , T"System"   },
    { "wan"      , T"WAN"      },
    { "voice"    , T"Voice"    },
    { "data"     , T"Data"     },
    { "lan"      , T"LAN"      },
    { "usb"      , T"USB"      },
    { "firewall" , T"Firewall" }
  }

  local logdata = proxy.get("sys.log.") or {}
  local log_array = {}
  local pattern = "^%d+|<(%d+)>(%S+%s+%S+%s+%d+) (%d+:%d+:%d+) (%d+) %S* (%S*): (.+)$"

  for index, log in ipairs(logdata) do
    log.value:gsub(pattern, function(severity, date, time, year, category, message)
      log_array[#log_array+1] = {
        index = log.path:match("%d+"),
        severity = tonumber(severity)%8,
        date = date .. " " .. year,
        time = time,
        category = category, -- This is not the actual category. Assigning category to each log is done in javascript
        message = reformat(message)
      }
    end)
  end

  local selectedLogs = proxy.get("uci.system.system.@system[0].selected_logs") or {}

  local lp = require("web.lp")
  lp.setpath("/www/docroot/")
  lp.include("reset-wrap.lp")
  selectedLogs = selectedLogs[1] and selectedLogs[1].value or ""

  ngx.print('\
<h1>');  ngx.print(T"Event Log"); ngx.print('</h1>\
<!-- Modal -->\
<div class="modal fade" id="elog-div-notSupported" data-backdrop="static">\
  <div class="modal-dialog">\
    <div class="modal-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
         <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <div class="form-group">\
          <div class="col-sm-12">\
            <p><span>');  ngx.print(T"Your browser doesn't support this feature."); ngx.print('</span></p>\
          </div>\
        </div>\
        <div class="form-group">\
          <div class="col-sm-12">\
            <div class="modal-footer">\
              <input value="');  ngx.print(T"OK"); ngx.print('" class="button button-apply mob-button-width" id="elog-btn-OK" type="button">\
            </div>\
          </div>\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
<div id="elog-content" class="hide">\
  <h2>');  ngx.print(T"Select the categories for which you would like to view the event log."); ngx.print('</h2>\
  <div class="h3-content mobile-no-float vdf-table">\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(T"Categories to Show"); ngx.print('</span>\
      </div>\
      <div class="left" id="elog-div-checkboxes">\
        <div class="inner-row">\
          ');  for _, v in ipairs(categoryNames) do          
          if _ == 6 then   ngx.print('\
            <div class="event-log-button-width">  \
            &nbsp;            \
           </div>\
          ');  end  ngx.print('\
            <div class="event-log-button-width">\
              <input id="elog-chk-');  ngx.print(v[1]); ngx.print('" class="checkbox checked show-hide-guest-pw" data-id="1" data-category="');  ngx.print(v[1]); ngx.print('" type="checkbox" checked="checked">\
                <label for="elog-chk-');  ngx.print(v[1]); ngx.print('"></label>\
              <span>');  ngx.print(v[2]); ngx.print('</span>\
           </div>\
          ');  end  ngx.print('\
        </div>\
      </div>\
    </div>\
  </div>\
\
  <div class="h3-table-content hidden-xs desktop event-log-h3-table-content vdf-table" id="event-log-tbl">\
    <div class="vdf-row">\
      <div class="left">\
        <div class="tabs tabs-bg-4-1 clearfix no-margin-left-right">\
          <div class="tabs-all-events tab tabs-active" id="elog-lnk-dskAll">');  ngx.print(T"All Events"); ngx.print('</div>\
          <div class="tabs-errors tab" id="elog-lnk-dskErr1">\
            <div class="cont1" id="elog-lnk-dskErr">');  ngx.print(T"Only Errors and Warnings"); ngx.print('</div>\
          </div>\
        </div>\
        <div class="grey-table-content">\
          <div class="table event-log" id="elog-tbl-dskAll">\
            <div class="table-row table-row-head">\
              <div class="table-col table-col1">');  ngx.print(T"Date"); ngx.print('</div>\
              <div class="table-col table-col2">');  ngx.print(T"Time"); ngx.print('</div>\
              <div class="table-col table-col3">');  ngx.print(T"Log Details"); ngx.print('</div>\
              <div class="table-col table-col4">');  ngx.print(T"Category"); ngx.print('</div>\
            </div>\
          </div>\
          <div class="grey-table-content" id="elog-tbl-dskErr"></div>\
        </div>\
      </div>\
    </div>\
  </div>\
\
  <!-- Mobile view for Event log -->\
\
  <div id="event-log" class="h3-table-content mobile">\
      <div class="tabs tabs-bg-4-1 clearfix" id="eventlog-data">\
          <div class="tabs-arrow prev">\
              <img src="/img/look_4/icons/arrows/responsive_down_arrow.png" alt="">\
      </div>\
          <div id="elog-btn-allLogs" class="tabs-all-events tabs-current mobile-tab tabs-active" data-id="numAll">\
              <span>');  ngx.print(T"All Events"); ngx.print('</span>\
      </div>\
          <div id="elog-btn-onlyErrors" class="tabs-errors tabs-next mobile-tab" data-id="dialled">\
              <div class="cont1">\
                  <span>');  ngx.print(T"Only Errors and Warnings"); ngx.print('</span>\
        </div>\
          </div>\
\
          <div class="tabs-arrow next">\
              <img src="/img/look_4/icons/arrows/responsive_down_arrow.png" alt="">\
      </div>\
      </div>\
    <!--- Contents comes here -->\
  </div>\
\
  <div class="row padding-top-bottom-20 text-right no-margin-left-right right fR fr-mobile" id="event-log">\
    <input id="elog-btn-showMore" class="button button-cancel showMore mob-button-width show-more hidden-lg hidden-md hidden-sm" value="');  ngx.print(T"Show More"); ngx.print('" type="button">\
    <input id="elog-btn-download" value="');  ngx.print(T"Download"); ngx.print('" class="button button-cancel showHideDivAbove downloadStuff mob-button-width mob-apply-cancel" type="button">\
    <input id="elog-btn-triggerDelete" value="');  ngx.print(T"Delete"); ngx.print('" class="button button-cancel showHideDivAbove deleteStuff mob-button-width mob-apply-cancel" type="button">\
  </div>\
\
  <div class="modal fade" id="elog-div-delete" role="dialog" data-backdrop="static">\
    <div class="modal-dialog">\
      <div class="modal-content">\
        <div class="modal-header hidden-md hidden-sm hidden-lg">\
          <button type="button" class="close" data-dismiss="modal">&times;</button>\
        </div>\
        <div class="modal-body">\
          <form class="form-horizontal">\
            <div class="form-group no-margin-bottom">\
              <div class="col-md-12 col-sm-12 col-lg-12">\
                <p>');  ngx.print(T"Are you sure you want to delete this log?"); ngx.print('</p>\
              </div>\
            </div>\
            ');  
              local row = {
                label = format('%s %s',ui_helper.createClickButton({
                  value=T"Delete",
                  class="button button-apply mob-button-width",
                  id="elog-btn-delete",
                  type="button"
                  }),ui_helper.createClickButton({
                  id="elog-btn-cancel",
                  class="button button-cancel mob-button-width mob-apply-cancel",
                  value=T"Cancel",
                  type="button",
                  ["data-dismiss"]="modal"
                  })),
                rowClass = "row no-margin-left-right",
                colClass = "col-xs-12 col-sm-12 col-md-12 text-right padding-top-bottom-20 no-padding-left-right mobile-padding-top-none mobile-padding-bottom-20"
              }
              ngx.print(ui_helper.createSingleRow(row))
              ngx.print('\
          </form>\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
');  
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
<script>\
  var logs = ');  ngx.print(json.encode(log_array) or "[]"); ngx.print('.reverse();\
  var selectedLogs = "');  ngx.print(selectedLogs); ngx.print('"\
  var refresh = false;\
  var categoryMap = {};\
  ');  
    for _, v in ipairs(categoryNames) do
      ngx.print(format("categoryMap['%s'] = '%s';", v[1], v[2]))
    end
    ngx.print('\
\
  var categoryPatterns = {\
    system   : /(^|[^a-z])(kernel|upnp|samba|tod|led|dlna|dropbear|cwmpd|nginx)/gi,\
    wan      : /(^|[^a-z])(wan|netifd)/gi,\
    lan      : /(^|[^a-z])(lan)/gi,\
    voice    : /(^|[^a-z])(mmpbx)/gi,\
    data     : /(^|[^a-z])(wps|mobiled|dnsmasq|hotspot|ddns|hostapd|dsl|xtm)/gi,\
    usb      : /(^|[^a-z])(usb)/gi,\
    firewall : /(^|[^a-z])(firewall)/gi\
  }\
\
  // Lets assign category to each log\
  $.each(logs, function() {\
    // Category filtering is based on both log category and log message coming from datamodel\
    var log = this.category + " " + this.message;\
\
    // take a copy of `this` because it will be rewritten inside next `$.each()`\
    var self = this;\
\
    //  Iterate through each category and check for a matching pattern\
    var matchFound = false;\
    $.each(categoryPatterns, function(thisCategory, pattern) {\
      if (log.match(pattern)) {\
        matchFound = true;\
        // assign the matched category to logs\
        self.category = thisCategory;\
        return false;\
      }\
    });\
    if (!matchFound) self.category = "system"\
  });\
\
\
  var months = [ "');  ngx.print(T"JANUARY"); ngx.print('", "');  ngx.print(T"FEBRUARY"); ngx.print('", "');  ngx.print(T"MARCH"); ngx.print('", "');  ngx.print(T"APRIL"); ngx.print('", "');  ngx.print(T"MAY"); ngx.print('", "');  ngx.print(T"JUNE"); ngx.print('", "');  ngx.print(T"JULY"); ngx.print('", "');  ngx.print(T"AUGUST"); ngx.print('", "');  ngx.print(T"SEPTEMBER"); ngx.print('", "');  ngx.print(T"OCTOBER"); ngx.print('", "');  ngx.print(T"NOVEMBER"); ngx.print('", "');  ngx.print(T"DECEMBER"); ngx.print('" ];\
  var MAX_MOBILE_WIDTH = 767;\
  var visibleIndex = 10;\
  var visibleErrorIndex = 10;\
  var rowCount = 0;\
  var errorRowCount = 0;\
\
  $(function() {\
    $("#elog-tbl-dskErr").hide();\
    $("#elog-div-checkboxes .checkbox").click(function() {\
      var self = this;\
      var selectedCategories = [];\
      if (!refresh) {\
        $("#elog-div-checkboxes .checkbox:checked").each(function() {\
          selectedCategories.push($(this).data("category"));\
        });\
        selectedCategories = selectedCategories.join(",");\
      }\
      else {\
        selectedCategories = selectedLogs;\
        refresh = false;\
      }\
        $.post("/modals/status-support/eventLog.lp", {\
          action: "selectedCategories",\
          CSRFtoken: $("meta[name=CSRFtoken]").attr("content"),\
          selectedCategories: selectedCategories\
        }, function(data) {\
          if (data.success) {\
            toggleCategories.call(self);\
          }\
        });\
        expertModePostHandle();\
    });\
\
    $("#elog-lnk-dskAll").click(function(){\
      $("#elog-tbl-dskAll").show();\
      $("#elog-tbl-dskErr").hide();\
      $(\'.tab\').removeClass(\'tabs-active\');\
      $(this).addClass(\'tabs-active\');\
    })\
\
    $("#elog-lnk-dskErr").click(function(){\
      $("#elog-tbl-dskErr").show();\
      $("#elog-tbl-dskAll").hide();\
      $(\'.tab\').removeClass(\'tabs-active\');\
      $("#elog-lnk-dskErr1").addClass(\'tabs-active\');\
    })\
\
    $("#elog-btn-showMore").click(function() {\
      var categories = [];\
      $(".checkbox:checked").each(function(){\
        categories.push("." + $(this).data("category"))\
      });\
      var hideCount = 0;\
      $(".event-category:hidden").each(function(index) {\
        if ($(this).is(categories.join(","))) {\
          if (hideCount < 10) {\
            $(this).show();\
            ++hideCount;\
          }\
        }\
      });\
      visibleIndex += hideCount;\
    });\
\
    $("#elog-btn-OK").click(function() {\
      $("#elog-div-notSupported").modal("hide");\
    });\
\
    $("#elog-btn-download").click(function() {\
\
      var severity = [];\
      severity[0] = "');  ngx.print(T"Panic"); ngx.print('";\
      severity[1] = "');  ngx.print(T"Alert"); ngx.print('";\
      severity[2] = "');  ngx.print(T"Critical"); ngx.print('";\
      severity[3] = "');  ngx.print(T"Error"); ngx.print('";\
      severity[4] = "');  ngx.print(T"Warning"); ngx.print('";\
      severity[5] = "');  ngx.print(T"Notice"); ngx.print('";\
      severity[6] = "');  ngx.print(T"Info"); ngx.print('";\
      severity[7] = "');  ngx.print(T"Debug"); ngx.print('";\
      severity[8] = "');  ngx.print(T"None"); ngx.print('";\
\
      var logLevel = $("table:visible").data("level");\
      var logCategory = [];\
      var logMsg = "";\
      $(".checkbox:checked").each(function() {\
        logCategory.push($(this).data("category"));\
      });\
      $.each(logs, function() {\
        var thisLogLevel = (this.severity < 5) ? "error" : "all";\
        if (logCategory.indexOf(this.category) != -1) {\
          if (logLevel == "error" && thisLogLevel != "error")\
            return true;\
          else\
            logMsg += this.date.replace(/^(\\d{1,2})\\/(\\d{1,2})\\/(\\d{4})$/,"$2.$1.$3") + "\\t" + this.time + "\\t" + this.category + "\\t\\t" + (severity[this.severity] || this.severity) + "\\t\\t" + this.message + "\\n";\
        };\
      });\
      logMsg = (logMsg.length == 0) ? "');  ngx.print(T"No logs to display"); ngx.print('" : "');  ngx.print(T"Date"); ngx.print('\\t\\t');  ngx.print(T"Time"); ngx.print('\\t\\t');  ngx.print(T"Category"); ngx.print('\\t');  ngx.print(T"Severity"); ngx.print('\\t');  ngx.print(T"Log Details"); ngx.print('\\n" + logMsg;\
      try {\
        var blob = new Blob([logMsg], {type: "text/plain;charset=utf-8"});\
        saveAs(blob, "syslog.log");\
      } catch (e) {\
        $("#elog-div-notSupported").modal(\'show\');\
      }\
    });\
\
    $("#elog-btn-triggerDelete").click(function() {\
      $("#elog-div-delete").modal("show").find(":button").prop("disabled", false);\
    });\
\
    $("#elog-btn-delete").click(function() {\
      $(this).closest("div").find(":button").prop("disabled", true);\
      var deleteCategory = [];\
      $("#elog-div-checkboxes .checkbox.checked").each(function() {\
        var selectedCategory = $(this).data("category");\
        $.each(logs, function(index) {\
          if (selectedCategory == this.category) {\
            deleteCategory.push(this.index);\
            delete logs[index];\
          }\
        });\
      });\
      $.post("/modals/status-support/eventLog.lp", {\
        action: "deleteLog",\
        CSRFtoken: $("meta[name=CSRFtoken]").attr("content"),\
        deleteLog: deleteCategory.sort(function(a, b) {\
          return +b - +a;\
        }).join(",")\
      }, function(data) {\
        if (data.success) {\
          var deletedCategory = [];\
          $(".checkbox:checked").each(function() {\
            deletedCategory.push("." + $(this).data("category"));\
          });\
          deletedCategory = deletedCategory.join(",")\
          $(".table-row, .event-category").each(function(){\
            if ($(this).is(deletedCategory)) {\
              $(this).remove();\
            }\
          });\
        }\
        $("#elog-div-delete").modal("hide");\
      });\
      expertModePostHandle();\
   });\
\
    // Populate table rows for Desktop view\
    if ($(window).width() > MAX_MOBILE_WIDTH) {\
      var desktopLogs = logs.slice(0);\
      $.each(desktopLogs, function() {\
        var date = new Date(this.date);\
        this.date = (("0" + (date.getMonth() + 1)).slice(-2)) + "/" + (("0" + date.getDate()).slice(-2)) + "/" + date.getFullYear();\
        var row = $(\'<div class="table-row security all" style="display: table-row;"></div>\');\
        if (this.severity < 5) {\
          row.addClass("eventLogErrorSecurity");\
        } else {\
          row.addClass("eventLogInfo");\
        }\
        row.append($(\'<div class="table-col table-col1"></div>\').text(this.date))\
           .append($(\'<div class="table-col table-col2"></div>\').text(this.time))\
           .append($(\'<div class="table-col table-col3"></div>\').text(this.message))\
           .append($(\'<div class="table-col table-col4"></div>\').text(categoryMap[this.category]))\
           .addClass(categoryMap[this.category] ? this.category : "system");\
        $("#elog-tbl-dskAll").append(row);\
      });\
\
      var errTable = $("#elog-tbl-dskAll").clone();\
      errTable.find(".eventLogInfo").remove();\
      $("#elog-tbl-dskErr").append(errTable).hide();\
\
    } else {\
      // Populate table rows for Mobile view\
      var previousDate = "";\
      var tbody  = $("<div></div>");\
      var errRows = 0;\
      var mobileLogs = logs.slice(0);\
      $.each(mobileLogs, function() {\
        var isErr = (this.severity < 5);\
        var date = new Date(this.date);\
        this.date = ("0" + date.getDate()).slice(-2) + " " + months[date.getMonth()] + ", " + (date.getFullYear() + "").slice(2);\
        var dateRow = $(\'<div class="table-row all security clearfix"><div class="table-col time-period data-mobile-padding-30px">\' + this.date + \'</div></div>\');\
        var timeRow = $(\'<div class="table-row all security clearfix"><div class="clearfix">\\\
                           <div class="table-col time">\' + this.time +\'</div>\\\
                           <div class="table-col category">Category: <span>\' + (categoryMap[this.category]) + \'</span></div>\\\
                         </div></div>\');\
        var msgRow = $(\'<div class="table-row all security table-col call-elem from"><span>\' + this.message + \'</span></div>\');\
        var thisRow = $(\'<div class="event-category"></div>\').addClass(categoryMap[this.category] ? this.category : "system");\
        rowCount++;\
        if (isErr) {\
          msgRow.addClass("eventLogErrorSecurity");\
          timeRow.addClass("eventLogErrorSecurity");\
        } else {\
          msgRow.addClass("eventLogInfo");\
          timeRow.addClass("eventLogInfo");\
        }\
        if (this.date == previousDate) dateRow.hide();\
        tbody.append(thisRow.append($("<div></div>").append(dateRow).append(timeRow).append(msgRow)));\
        if (rowCount >= 10) thisRow.hide();\
        previousDate = this.date;\
      });\
      tbody.insertAfter("#eventlog-data");\
      var errTable = tbody.clone();\
      errTable.find(".eventLogInfo").closest("tr").remove();\
      $("#elog-tbl-mobErr").append(errTable);\
\
      $("#elog-tbl-mobErr tr").each(function(index) {\
        errorRowCount++;\
        if (errorRowCount >= 10) $(this).hide();\
      });\
    }\
    $("#elog-tbl-mobAll tr:visible:first p.date").show();\
    $("#elog-tbl-mobErr tr:visible:first p.date").show();\
\
    $.each(categoryPatterns, function(category) {\
      if (selectedLogs.indexOf(category) == -1) {\
        refresh = true;\
        $("#elog-chk-"+category).click();\
      }\
    });\
\
    $("#elog-content").removeClass("hide");\
\
  });\
\
  $("#elog-btn-allLogs").click(function(){\
    $("#event-log .eventLogInfo").show();\
    $("#event-log .eventLogErrorSecurity").show();\
    $(".tabs-errors").removeClass("tabs-active")\
    $(this).addClass("tabs-active");\
  });\
\
  $("#elog-btn-onlyErrors").click(function(){\
    $("#event-log .eventLogInfo").hide();\
    $("#event-log .eventLogErrorSecurity").show();\
    $(".tabs-all-events").removeClass("tabs-active");\
    $(this).addClass("tabs-active");\
  });\
\
  $("#resetR, #resetrmobile").click(function(){\
    $("#elog-div-checkboxes .checkbox.unchecked").click();\
  });\
\
  function hideDuplicateDates(table) {\
    var prevDate = "";\
    $("#" + table + " .date").each(function() {\
      if ($(this).is(":visible")) {\
        var thisDate = $(this).text();\
        if (prevDate == thisDate) {\
          $(this).next().addClass("eventlog-mobile-padding");\
          $(this).hide();\
        } else {\
          $(this).next().removeClass("eventlog-mobile-padding");\
          $(this).show();\
        }\
        prevDate = thisDate;\
      }\
    });\
    $("#" + table + " tr:visible:first p.date").show();\
  }\
\
  function toggleCategories() {\
    $(this).toggleClass("checked unchecked");\
    if ($(window).width() > MAX_MOBILE_WIDTH) {\
      if ($(this).prop("checked")) {\
        $("." + $(this).data("category")).show();\
      } else {\
        $("." + $(this).data("category")).hide();\
      }\
    } else {\
      if ($(this).prop("checked")) {\
        $(".event-category." + $(this).data("category") + ":lt(" + visibleIndex + ")").show();\
      } else {\
        $(".event-category." + $(this).data("category") + ":lt(" + visibleIndex + ")").hide();\
      }\
      $("#event-log .event-category .time-period").eq(0).show();\
    }\
  }\
</script>\
'); 