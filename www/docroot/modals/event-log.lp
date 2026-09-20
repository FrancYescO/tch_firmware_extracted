--pretranslated: do not change this file
 
  -- Enable localization
  gettext.textdomain('webui-core')

  local ngx = ngx
  local content_helper = require("web.content_helper")
  local post_helper = require("web.post_helper")
  local proxy = require("datamodel")
  local json = require("dkjson")

  local string, table = string, table
  local format, match, untaint = string.format, string.match, string.untaint
  local concat = table.concat
  local CSRFtoken = ngx.ctx.session:getCSRFtoken()

  local logdata = proxy.get("sys.log.devicelog")
  logdata = next(logdata) and logdata[1].value or ""

  local log_array = {}
  local pattern = "([%S]+%s+%d+) (%d+:%d+:%d+) (%d+) [%S]+%.([%S]+) ([%S]+): ([^\n]+)"

  logdata:gsub(pattern, function(date, time, year, type, category, message)
    log_array[#log_array+1] = {
      date = date .. " " .. year,
      time = time,
      type = type,
      category = category,
      message = message
    }
  end)

  local lp = require("web.lp")
  lp.setpath("/www/docroot/")
  lp.include("reset-wrap.lp")

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
<!-- End -->\
<div id="elog-content">\
  <h2>');  ngx.print(T"Select the categories for which you would like to view the event log."); ngx.print('</h2>\
  <div class="h3-content mobile-no-float vdf-table">\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(T"Categories to Show"); ngx.print('</span>\
      </div>\
      <div class="left">\
        <div class="inner-row" id="elog-div-checkboxes">\
          <div class="event-log-button-width">\
            <input id="elog-chk-system" class="checkbox checked show-hide-guest-pw" data-id="1" data-category="system" type="checkbox" checked="checked">\
              <label for="elog-chk-system"></label>\
            <span>');  ngx.print(T"System"); ngx.print('</span>\
         </div>\
          <div class="event-log-button-width">\
            <input id="elog-chk-voice" class="checkbox checked show-hide-guest-pw" data-id="1" type="checkbox" data-category="mmpbx"  checked="checked">\
              <label for="elog-chk-voice"></label>\
            <span>');  ngx.print(T"Voice"); ngx.print('</span>\
      </div>\
          <div class="event-log-button-width">\
            <input id="elog-chk-usb" class="checkbox checked show-hide-guest-pw" data-id="1"  data-category="usb" type="checkbox" checked="checked">\
              <label for="elog-chk-usb"></label>\
            <span>');  ngx.print(T"USB"); ngx.print('</span>\
      </div>\
        </div>\
      </div>\
    </div>\
  </div>\
\
  <div class="h3-table-content hidden-xs desktop event-log-h3-table-content" id="event-log-tbl">\
    <div class="tabs tabs-bg-4-1 clearfix">\
      <div class="tabs-all-events tab tabs-active" id="elog-lnk-dskAll">');  ngx.print(T"All Events"); ngx.print('</div>\
      <div class="tabs-errors tab" id="elog-lnk-dskErr1">\
        <div class="cont1" id="elog-lnk-dskErr">');  ngx.print(T"Only Errors and Warnings"); ngx.print('</div>\
      </div>\
    </div>\
\
\
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
  </div>\
</div>\
');  
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
<script>\
  var logs = ');  ngx.print(json.encode(log_array) or "[]"); ngx.print('.reverse();\
\
  var categoryMap = {\
    usb    : "');  ngx.print(T"USB"); ngx.print('",\
    mmpbx  : "');  ngx.print(T"Voice"); ngx.print('"\
  }\
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
    $(".checkbox").click(function() {\
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
      var logTypes = {\
        "info"   : "');  ngx.print(T"Information"); ngx.print('",\
        "notice" : "');  ngx.print(T"Notice"); ngx.print('",\
        "debug"  : "');  ngx.print(T"Debug"); ngx.print('",\
        "warn"   : "');  ngx.print(T"Warning"); ngx.print('",\
        "err"    : "');  ngx.print(T"Error"); ngx.print('"\
      };\
      var logLevel = $("table:visible").data("level");\
      var logCategory = [];\
      var logMsg = "";\
      $(".checkbox:checked").each(function() {\
        logCategory.push($(this).data("category"));\
      });\
      $.each(logs, function() {\
        var thisLogLevel = (this.type == "warn" || this.type == "err") ? "error" : "all";\
        if (logCategory.indexOf(this.category) != -1) {\
          if (logLevel == "error" && thisLogLevel != "error")\
            return true;\
          else\
            logMsg += this.date.replace(/^(\\d{1,2})\\/(\\d{1,2})\\/(\\d{4})$/,"$2.$1.$3") + "\\t" + this.time + "\\t" + this.category + "\\t\\t" + (logTypes[this.type] || this.type) + "\\t\\t" + this.message + "\\n";\
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
    // Populate table rows for Desktop view\
    if ($(window).width() > MAX_MOBILE_WIDTH) {\
      var desktopLogs = logs.slice(0);\
      $.each(desktopLogs, function() {\
        this.category = (this.message.match(/usb/i) || this.category.match(/mmpbx/i) || ["system"])[0].toLowerCase();\
        var date = new Date(this.date);\
        this.date = (("0" + (date.getMonth() + 1)).slice(-2)) + "/" + (("0" + date.getDate()).slice(-2)) + "/" + date.getFullYear();\
        var row = $(\'<div class="table-row security all" style="display: table-row;"></div>\');\
        if (this.type == "warn" || this.type == "err") {\
          row.addClass("eventLogErrorSecurity");\
        } else {\
          row.addClass("eventLogInfo");\
        }\
        row.append($(\'<div class="table-col table-col1"></div>\').text(this.date))\
           .append($(\'<div class="table-col table-col2"></div>\').text(this.time))\
           .append($(\'<div class="table-col table-col3"></div>\').text(this.message))\
           .append($(\'<div class="table-col table-col4"></div>\').text(categoryMap[this.category] || "');  ngx.print(T"System"); ngx.print('"))\
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
        this.category = (this.message.match(/usb/i) || this.category.match(/mmpbx/) || ["system"])[0].toLowerCase();\
        var isErr = (this.type == "warn" || this.type == "err");\
        var date = new Date(this.date);\
        this.date = ("0" + date.getDate()).slice(-2) + " " + months[date.getMonth()] + ", " + (date.getFullYear() + "").slice(2);\
        var dateRow = $(\'<div class="table-row all security clearfix"><div class="table-col time-period data-mobile-padding-30px">\' + this.date + \'</div></div>\');\
        var timeRow = $(\'<div class="table-row all security clearfix"><div class="clearfix">\\\
                           <div class="table-col time">\' + this.time +\'</div>\\\
                           <div class="table-col category">Category: <span>\' + (categoryMap[this.category] || \'');  ngx.print(T"System"); ngx.print('\') + \'</span></div>\\\
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
  });\
\
  $("#resetR, #resetrmobile").click(function(){\
    $("#elog-div-checkboxes .checkbox.unchecked").click();\
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
</script>\
'); 