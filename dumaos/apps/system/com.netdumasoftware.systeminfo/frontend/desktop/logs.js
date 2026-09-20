/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
*/

<%
  local libos = require("libos")
  local platform_information = os.platform_information()
%>

(function (context) {

function reverseLog(log) {

    var pattern = /^[a-zA-Z]{3}\s[a-zA-Z]{3}\s{1,2}[0-9]{1,2}\s[0-9]{2}:[0-9]{2}:[0-9]{2}\s[0-9]{4}/;

  var splitLog = log.split(/\r?\n/);

  var groupedLog = [];

  for (var i = 0; i < splitLog.length - 1; i++) {
    var line = splitLog[i];

    var group = [line];

    line = splitLog[i + 1];
    while (i + 1 < splitLog.length - 1 && !line.match(pattern)) {
      i++;
      group.push(line);
      line = splitLog[i + 1];
    }

    groupedLog.push(group);
  }

  groupedLog.reverse();

  for (var i = 0; i < groupedLog.length; i++) {
    groupedLog[i] = groupedLog[i].join("\n");
  }

  return groupedLog.join("\n");

}

function updateLogs(log) {
  $("#logs", context).text(reverseLog(log));
}

function downloadLogs() {
  long_rpc_promise("com.netdumasoftware.systeminfo", "read_log", [])
    .done(function (log) {
      var element = document.createElement("a");
      element.setAttribute("href", "data:text/plain;charset=utf-8," + encodeURIComponent(log));
      element.setAttribute("download", "log-" + Date.now() + ".txt");
      element.style.display = "none";
      document.body.appendChild(element);
      element.click();
      document.body.removeChild(element);
    });
}

start_cycle(function () {
  return [long_rpc_promise("com.netdumasoftware.systeminfo", "read_log", [])];

}, function (logs) {
  updateLogs(logs[0]);
  
  $("duma-panel", context).prop("loaded", true);
}, 1000 * 30);

$("#download", context).click(downloadLogs);

})(this);

//# sourceURL=logs.js
