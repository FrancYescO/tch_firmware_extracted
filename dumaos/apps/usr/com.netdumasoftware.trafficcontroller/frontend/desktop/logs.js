/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
*/

(function (context) {
  var packageId = "com.netdumasoftware.trafficcontroller";
  var first = true;

  function add_log(time, ruleName, device, event) {
    var deviceFill = $('<span class="device-name"></span>').text(device);
    var row = $("<tr></tr>")
      .append($('<td></td>').append($('<span class="rule-name"></span>').text(ruleName)))
      .append($("<td></td>")
        .text(new Date(time * 1000).toLocaleString()))
      .append($("<td></td>")
        .html(event.replace("{0}",deviceFill.prop('outerHTML'))));

    $("#firewall-logs", context).append(row);
  }

  function clear_logs(log) {
    $("#firewall-logs", context).empty();
  }

  /*
  function downloadLogs() {
    long_rpc_promise("com.netdumasoftware.trafficcontroller", "get_logs", [])
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
  */
  function get_device_names(id_list) {
    var names = [];
    var callback = function (calledNames){
      //for(var i = 0; i< calledNames.length; ++i){
      //  names.push(calledNames[0][i]);
      //}
      names = calledNames[0];
    };
    var promises = [];

    for (var i = 0; i < id_list.length; ++i) {
      promises.push(long_rpc_promise(
        "com.netdumasoftware.devicemanager",
        "get_device",
        [id_list[i]]
      ));
    }
    q.spread(promises,callback);

    return names;
  }

  function getScrollArea(){
    return $("#logs-panel #main #mainContainer",context)[0];
  }
 
  start_cycle(function () {
    return [long_rpc_promise(packageId, "get_log", [])];
  }, function (logs) {
    var scrollArea = getScrollArea();
    var scroll = first && scrollArea.scrollTop == 0 ||
                  scrollArea.scrollTop == (scrollArea.scrollHeight - scrollArea.clientHeight) ||
                  scrollArea.scrollTop == scrollArea.scrollHeight;
    clear_logs();
    logs = logs[0];
    for(var i = 0;i<logs.length; i++){
      add_log(logs[i].timestamp,logs[i].rule_name,logs[i].device_name,logs[i].log);
    }
    if(scroll){
      scrollArea.scrollTop = scrollArea.scrollHeight;
    }
    first = false;
    $("duma-panel", context).prop("loaded", true);
  }, 4000);

  //$("#download", context).click(downloadLogs);

})(this);

//# sourceURL=logs.js
