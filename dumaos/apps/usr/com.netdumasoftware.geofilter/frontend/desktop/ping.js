/*
 * (C) 2016 NETDUMA Software
 * Kian Cross
 */

<%
require "libos"
require "libtable"
local platform_information = os.platform_information()
%>

(function (context) {

var reportDialog = $("#report-dialog", context)[0];
var pingLoaderDialog = $("#ping-loader-dialog", context)[0];
var pingHandle;

var chartHistoryLength = 10;
var pingSampler = sampler_create(chartHistoryLength);
var clientTickRateSampler = sampler_create(chartHistoryLength);
var serverTickRateSampler = sampler_create(chartHistoryLength);
var sendRateSampler = sampler_create(chartHistoryLength);
var receiveRateSampler = sampler_create(chartHistoryLength);

var DATASET_INDEXES = {};

function padBeginningOfArrayWithValue(a, n, v) {
  while (a.length < n) {
    a.unshift(v);
  }
}
 
function pingHost(ip, callback) {
  var expectingIp = true;
  <% if platform_information.model == "DJA0231" or platform_information.model == "DJA0230" then %>
  var pingWebSocket = newWebSocket(8090, "ping");
  <% else %>
  var pingWebSocket = newWebSocket(8080, "ping");
  <% end %>

  var stopPing = function() {
    if(pingWebSocket.readyState < 2) {
      if(pingWebSocket.readyState === 1) {
        pingWebSocket.send("end"); 
      }
      pingWebSocket.close();
    }
  }
  
  pingWebSocket.onmessage = function (e) {

    if (pingWebSocket.readyState !== 1) {
      return;
    }

    pingWebSocket.send("again"); 

    if (expectingIp) {
      expectingIp = false;
      return;
    }

    callback(parseFloat(e.data));
  }

  pingWebSocket.onopen = function (e) {
    pingWebSocket.send(ip);
  }

  return {
    stop: stopPing
  };
}

function allowDenyHost(allowed, ip, name, isdedi) {
  var promise = long_rpc_promise(
    geoFilter.getPackageId(), "upsert_host",
    [allowed.toString(), name, ip, isdedi.toString()]
  );

  geoFilter.showLoaderDialog(pingLoaderDialog, promise);
  promise.done(function () {
    $("#allow-deny-panel").trigger("allow-deny-host", {
      allowed: allowed,
      ip: ip,
      name: name,
      isdedi: isdedi
    });
  });

  return promise;
}

function bindAllowDenyEvents(ip, isdedi) {
  $("#allow", context).click(function () {
    if ($("#host-name", context)[0].validate()) {
      allowDenyHost(true, ip, $("#host-name",context).prop("value"), isdedi);
    }
  });
  
  $("#deny", context).click(function () {
    if ($("#host-name", context)[0].validate()) {
      allowDenyHost(false, ip, $("#host-name",context).prop("value"), isdedi)
        .done(function () {
          $("duma-alert", context).show(
            "<%= i18n.deniedHostWarning %>",

            [{ text: "<%= i18n.gotIt %>", action: "confirm" }],
            {
              enabled: true,
              packageId : geoFilter.getPackageId(),
              id: "geofilter-deny-host-warning"
            } 
          );
        });
    }
  });
  
  long_rpc_promise(geoFilter.getPackageId(), "get_all_hosts", [])
    .done(function (hosts) {

      hosts = hosts[0];
      $("#host-name", context).prop("value", "");

      for (var hostIp in hosts) {
        if (hosts.hasOwnProperty(hostIp)) {

          var host = hosts[hostIp];

          if (hostIp === ip) {
            $("#host-name", context).prop("value", host.name);
            break;
          }

        }
      }

      $("#ping-panel", context).prop("loaded", true);
    });
}

function class_is_dedi( c ){
  return ( ( c >> geoFilter.constants.TYPE_SHIFT ) & 0x1 )
    == geoFilter.constants.GEO_CSTATE_HOST_DEDI;
}

function class_is_mm( c ){
  var v = ( c >> geoFilter.constants.VERDICT_SHIFT ) & 0x7;
  return v == geoFilter.constants.GEO_CSTATE_VERDICT_WHITELIST && class_is_dedi( c );
}

function pick_auto_ping_host( hosts ){
  var top_dawg = hosts[0];
  var min_rate_bytes_per_sec = 2.5;   // 20kbits/sec

  if( typeof( top_dawg ) === 'undefined' )
    return false;

  if( class_is_mm( top_dawg.class ) ) 
    return false;

  if( top_dawg.rate < min_rate_bytes_per_sec )
    return false;

  return top_dawg;
}

var auto_ping_target = {
  key : false,
  pinging : false,
  isdedi : false,
  started : 0
};

var ap_host_duration = 5 * 1000;

function stopPing() {
  if (pingHandle) {
    pingHandle.stop();
    pingHandle = null;
  }
}

function stopPingAndShowNoHost() {
  stopPing();
  $("#no-host", context).show();
  $("#ping-information", context).hide();
}

function hideNoHost() {
  $("#no-host", context).hide();
  $("#ping-information", context).show();
}

function beginAutoPing(hosts) {
  var now = timeGetTime();
  var sorted = [];
  for( var ip in hosts ) {
    var entry = hosts[ip];
    if( entry.rate )
      sorted.push( hosts[ip] );
  } 

  sorted.sort( function( a, b ){ return b.rate - a.rate } );
  var new_host = pick_auto_ping_host( sorted );

  if(!new_host) {
    stopPingAndShowNoHost();
  } else {

    if( new_host.key == auto_ping_target.key ){
      if( ( now - auto_ping_target.started ) > ap_host_duration ){
        if(auto_ping_target.pinging) {
          updateTickrateInformation(new_host);
        } else {
          stopPing();
          processHost(new_host, true);
          updateTickrateInformation(new_host);
          auto_ping_target.pinging = true;
        }
      }
    } else {
      auto_ping_target.key = new_host.key;
      auto_ping_target.started = now; 
      auto_ping_target.pinging = false; 
      auto_ping_target.isdedi = class_is_dedi( new_host.class );  
      auto_ping_target.allowblock = !class_is_mm( new_host.class );
      stopPingAndShowNoHost();
    }
  }
}

function processHost(host, autoPing) {
  var isdedi = true   /* assume it is so user cannot ever mistakenly add */
  var allowBlock = false; 
  if(host && typeof(host.class) !== "undefined") {
    isdedi = class_is_dedi(host.class);
    allowBlock = !class_is_mm(host.class);
  }

  $(".ping", context).hide();
  if (autoPing) {
    $("#host-statistics .server-tick-rate", context).show();
    $("#host-statistics .client-tick-rate", context).show();
    $("#host-statistics .send-rate", context).show();
    $("#host-statistics .receive-rate", context).show();
    $("#host-statistics .host-type", context).hide();
    $("#host-statistics .id", context).hide();
    $("#host-statistics .domain", context).hide();
    $("#overflow-table .host-type", context).show();
    $("#overflow-table .id", context).show();
    $("#overflow-table .domain", context).show();
  } else {
    $("#host-statistics .server-tick-rate", context).hide();
    $("#host-statistics .client-tick-rate", context).hide();
    $("#host-statistics .send-rate", context).hide();
    $("#host-statistics .receive-rate", context).hide();
    $("#host-statistics .host-type", context).show();
    $("#host-statistics .id", context).show();
    $("#host-statistics .domain", context).show();
    $("#overflow-table .host-type", context).hide();
    $("#overflow-table .id", context).hide();
    $("#overflow-table .domain", context).hide();
  }

  $(".host-type .value", context).text(
    isdedi ? "<%= i18n.dedicated %>" : "<%= i18n.peer %>" 
  );
  $("#report-header",context).text(isdedi ? "<%= i18n.reportServer %>" : "<%= i18n.reportPeer %>");

  $("#allow-deny", context).toggleClass( "hidden", !allowBlock );
  $("#deny", context).prop("disabled", !allowBlock );
  $(".domain .value", context).text( "<%= i18n.performingLookup %>" );
  $(".id .value", context).text(inet_atoae(host.key));

<% if platform_information.vendor ~= "TELSTRA" then %>
  long_rpc_promise(geoFilter.getPackageId(), "geoservice_reverse_lookup", [host.key])
    .done(function (domain) {
      if(domain && domain != "") {
        $(".domain .value",context).text( domain );
      } else {
        $(".domain .value",context).text( "<%= i18n.unnamed %>" );
      }
    });
<% end %>

  initialiseGraphData(autoPing);
  pingHandle = pingHost(host.key, onPingUpdate);
  hideNoHost();

  $("#allow", context).off("click");
  $("#deny", context).off("click");
  
  bindAllowDenyEvents(host.key, isdedi);
}

function initialiseGraphData(autoPing) {

  var cgen = getColourGenerator();

  var datasets = [
    {
      label: "<%= i18n.ping %>",
      data: new Array(chartHistoryLength).fill(undefined),
      borderColor: cgen(),
      pointRadius: 0,
      pointBorderWidth: "3",
      lineTension: 0.1,
    }
  ];

  DATASET_INDEXES.ping = 0;

  if (autoPing) {
    <% if not table.find({"XR300", "R7000"}, platform_information.model) then %>
      DATASET_INDEXES.clientTickRate = datasets.push({
        label: "<%= i18n.clientTickRate %>",
        data: new Array(chartHistoryLength).fill(undefined),
        pointBorderWidth: "3",
        borderColor: cgen(),
        pointRadius: 0,
        lineTension: 0.1
      }) - 1;
      
      DATASET_INDEXES.serverTickRate = datasets.push({
        label: "<%= i18n.hostTickRate %>",
        data: new Array(chartHistoryLength).fill(undefined),
        pointBorderWidth: "3",
        borderColor: cgen(),
        pointRadius: 0,
        lineTension: 0.1
      }) - 1;
    <% end %>
    
    DATASET_INDEXES.sendRate = datasets.push({
      label: "<%= i18n.sendRate %>",
      data: new Array(chartHistoryLength).fill(undefined),
      pointBorderWidth: "3",
      borderColor: cgen(),
      pointRadius: 0,
      lineTension: 0.1
    }) - 1;
    
    DATASET_INDEXES.receiveRate = datasets.push({
      label: "<%= i18n.receiveRate %>",
      data: new Array(chartHistoryLength).fill(undefined),
      pointBorderWidth: "3",
      borderColor: cgen(),
      pointRadius: 0,
      lineTension: 0.1
    }) - 1;
  }

  $("#ping-graph", context)[0].data = {
    labels: new Array(chartHistoryLength).fill(""),
    datasets: datasets
  };
}

function onPingUpdate(ping) {
  var graph = $("#ping-graph", context)[0];
  var pingDataSet = graph.data.datasets[DATASET_INDEXES.ping];

  sampler_add(pingSampler, ping);

  var pingArray = sampler_get(pingSampler);

  padBeginningOfArrayWithValue(pingArray, chartHistoryLength, undefined);

  pingDataSet.data = pingArray;

  graph.update();

  $(".ping", context).show();
  $(".ping .value", context).text(Math.round(ping));

  $("#ping-panel", context).prop("loaded", true);
}


function updateTickrateInformation(host) {

  if (host.associatedConnections.length !== 1) {
    return;
  }

  var connections = host.associatedConnections[0];

  var graph = $("#ping-graph", context)[0];

  <% if not table.find({"XR300", "R7000"}, platform_information.model) then %>

    var serverTickRateDataSet = graph.data.datasets[DATASET_INDEXES.serverTickRate];
    var clientTickRateDataSet = graph.data.datasets[DATASET_INDEXES.clientTickRate];
    
    var serverTickRate = connections.new.dpackets - connections.old.dpackets;
    var clientTickRate = connections.new.spackets - connections.old.spackets;
    
    sampler_add(serverTickRateSampler, serverTickRate);
    sampler_add(clientTickRateSampler, clientTickRate);
    
    var serverTickRateArray = sampler_get(serverTickRateSampler);
    var clientTickRateArray = sampler_get(clientTickRateSampler);
    
    padBeginningOfArrayWithValue(serverTickRateArray, chartHistoryLength, undefined);
    padBeginningOfArrayWithValue(clientTickRateArray, chartHistoryLength, undefined);
    
    $(".server-tick-rate .value", context).text(Math.round(serverTickRate));
    $(".client-tick-rate .value", context).text(Math.round(clientTickRate));

  <% end %>
  
  var sendRateDataSet = graph.data.datasets[DATASET_INDEXES.sendRate];
  var receiveRateDataSet = graph.data.datasets[DATASET_INDEXES.receiveRate];

  var receiveRate = (connections.new.dbytes - connections.old.dbytes) * 8 / 1024;
  var sendRate = (connections.new.sbytes - connections.old.sbytes) * 8 / 1024;

  sampler_add(sendRateSampler, sendRate);
  sampler_add(receiveRateSampler, receiveRate);

  var receiveRateArray = sampler_get(receiveRateSampler);
  var sendRateArray = sampler_get(sendRateSampler);

  padBeginningOfArrayWithValue(sendRateArray, chartHistoryLength, undefined);
  padBeginningOfArrayWithValue(receiveRateArray, chartHistoryLength, undefined);

  sendRateDataSet.data = sendRateArray;
  receiveRateDataSet.data = receiveRateArray;
  
  $(".send-rate .value", context).text(Math.round(sendRate));
  $(".receive-rate .value", context).text(Math.round(receiveRate));

  graph.update();

  $("#ping-panel", context).prop("loaded", true);
}

function setGraphOptions() {
  $("#ping-graph", context).prop("options", {
    animation: {
      duration: 0,
    },
    scales: {
      yAxes: [{
        ticks: {
          beginAtZero: true
        }
      }],
      xAxes: [{
        display: false
      }]   
    }
  });
}

setGraphOptions();

var host = $("#ping-panel", context)[0].data.host;

$("#ping-panel", context).on("closeClick", function () {
  stopPing();
});

if (host) {

  $("duma-panel", context).prop("header", "<%= i18n.ping %>");
  processHost(host, false);

} else {

  $("duma-panel", context).prop("header", "<%= i18n.autoPing %>");
  geoFilter.startConnectionProcessor(beginAutoPing);

  stopPingAndShowNoHost();
  $("#ping-panel", context).prop("loaded", true);
}


(function bindReportButton(host){
  var reportSend = $("#report-send",context);
  
  var abnormal = $("#report-abnormal", context);
  var wrongServer = $("#report-wrong-server-class", context);
  var masterServer = $("#report-is-master-server", context);
  var other = $("#report-other", context);
  var otherTextArea = $("#report-other-text",context);

  other.on("checked-changed",function(e) {
    otherTextArea.attr("disabled",!e.detail.value);
  });

  var countryDropdown = $("#country_dropdown",context);
  var countryListbox = $("#country_listbox",context);
  var countryItems = $("#country_items",context);
  var stateDropdown = $("#state_dropdown",context);
  var stateListbox = $("#state_listbox",context);
  var stateItems = $("#state_items",context);

  $("#report", context).on("click",function(){
    reportDialog.open();
  });

  function loadStateList(list){
    stateListbox[0].selected = "none";
    if(list){
      stateItems[0].items = list;
      stateDropdown[0].disabled = false;
    }else{
      stateDropdown[0].disabled = true;
    }
  }
  var checkBoxesSet = $("#report-abnormal, #report-wrong-server-class, #report-is-master-server, #report-other", context);
  $("#report-abnormal, #report-wrong-server-class, #report-is-master-server, #report-other, #country_listbox, #report-other-text", context).on("checked-changed selected-changed change keyup",function(){
    var checkboxesValid = (
      abnormal[0].checked ||
      wrongServer[0].checked ||
      masterServer[0].checked ||
      ( other[0].checked && otherTextArea[0].value )
    );
    var countryBoxValid = countryListbox[0].selected !== "none";
    checkBoxesSet.prop("invalid",!checkboxesValid);
    reportSend[0].disabled = !(checkboxesValid && countryBoxValid);
  });

  loadCountriesList().then(function(data){
    countryItems[0].items = data.countries;

    countryListbox.on("selected-item-changed",function(e){
      if(!e.detail.value) return;
      var index = e.detail.value.index;
      var country = data.countries[parseInt(index)];
      
      var states = null;
      if(country && country.stateList){
        states = data.states[country.stateList];
      }
      loadStateList(states);

      countryDropdown.prop("invalid",!country);

      if(country){
        duma.storage(geoFilter.getPackageId(),"selected-country-drop",country.name);
      }

    });

    var startSelected = duma.storage(geoFilter.getPackageId(),"selected-country-drop");
    if(startSelected){
      countryListbox.prop("selected",startSelected);
    }
  });

  
  function showError(e){
    reportDialog.close();
    console.error(e);
    $("#ping-duma-alert",context)[0].show(
      "<%= i18n.errorContent %>",
      [
        { text: "<%= i18n.tryAgain %>", action: "dismiss", callback: function(){
          reportSend.attr("disabled",false);
          reportDialog.open();
        }},
        { text: "<%= i18n.goToSupport %>", action: "dismiss", callback: function(){
          <% if platform_information.vendor == "TELSTRA" then %>
          window.open("https://www.telstra.com.au/support/category/entertainment/gaming/game-optimiser",'_blank');
          <% elseif platform_information.vendor == "NETGEAR" then %>
          window.open("http://support.netgear.com",'_blank');
          <% else %>
          window.open("http://forum.netduma.com",'_blank');
          <% end %>
        }},
        { text: "<%= i18n.ok %>", action: "confirm" },
    ],
    );
  }

  reportSend.on("click",function(){
    var countryName = countryListbox.prop("selected");
    if(!countryName || countryName === "none") {
      countryDropdown.prop("invalid",true);
      showError("No Country Selected");
      return;
    };
    var stateName = stateListbox.prop("selected");
    stateName = stateName === "none" ? null : stateName;
    var payload = {
      ip: host.key,
      abnormalPing: abnormal.prop("checked"),
      wrongServerClass: wrongServer.prop("checked"),
      isMasterServer: masterServer.prop("checked"),
      other: other.prop("checked") ? otherTextArea.prop("value") : null,
      country: countryName,
      state: stateName,
    }
    reportSend.attr("disabled",true);
    
    //TODO use geo-filter.html location caching. Can't do this until webgl map is merged in... which requires everything here to be re-written anyways
    //TODO use geostats's map.json to automatically select the current country based off of home pos
    long_rpc_promise(geoFilter.getPackageId(), "geomap_ip", [ [host.key] ] ).then(function(result){
      if(result && result[0] && result[0][0]){
        payload.lng = result[0][0].lng;
        payload.lat = result[0][0].lat;
        long_rpc_promise(geoFilter.getPackageId(),"report_server",[payload]).then(function(){
          reportDialog.close();
          abnormal.prop("checked",false);
          wrongServer.prop("checked",false);
          masterServer.prop("checked",false);
          other.prop("checked",false);
          otherTextArea.prop("value","");
          reportSend.attr("disabled",false);
        }).catch(showError);
      }else{
        showError("Failed to geomap ip address");
      }
    }).catch(showError);
  });
})(host);

})(this);

//# sourceURL=ping.js
