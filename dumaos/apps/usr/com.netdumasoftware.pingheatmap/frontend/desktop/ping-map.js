(function (context) {
  var panel = $("duma-panel", context)[0];
  var activeTest = null;
  var jmap = $("duma-map", context);
  var jsvg = $("ping-servers-svg", context);
  var plog = $("ping-log", context)[0];
  var psvg = jsvg[0];
  var map = jmap[0];
  var pingWebSocket = null;
  var counts = $("#success-info",context).find("span");
  var saveManualPings = false;

  function indexOfParent(element){
    var i = 0;
    while((element=element.previousSibling) !== null) i++;
    return i;
  }

  function updateRunning(){
    $("#reping-button",context).prop("disabled",isTestRunningFrontend());
    UpdateLog();
  }

  function alertRunning(){
    $("duma-alert",context)[0].open("<%= i18n.alertRunning %>",[
      { text: "<%= i18n.ok %>", default: true, action: "dismiss" },
      { text: "<%= i18n.forceStop %>", default: false, action: "confirm", callback: function(){
        forceStopActive();
      }}
    ]);
  }
  function isTestRunningFrontend(){
    return activeTest !== null && !activeTest.ended;
  }

  var nowData = [];
  var isNow = false;
  function historyCallback(timeData){
    if(timeData !== null){
      isNow = false;
      psvg.fromHistory(timeData);
      UpdateLogHistory(timeData);
    }else{
      isNow = true;
      psvg.fromHistory(nowData);
      UpdateLogHistory(nowData);
    }
    psvg.setD3Data();
  }

  function set_history(category){
    var ping_history = $("ping-history", context);
    Q.spread([
      long_rpc_promise(packageId, "get_servers",[category.identifier]),
      long_rpc_promise(packageId, "get_history_category",[category.identifier])
    ], function (servers,history){
      isNow = true;
      servers = JSON.parse(servers).servers;
      history = JSON.parse(history);
      forObject(servers,function(key,serv){
        serv.identifier = key;
      });
      forObject(history,function(key,hist){
        history[key] = JSON.parse(hist);
        delete history[key].references;
      });
      activeTest.servers = servers;
      activeTest.history = history;
      ping_history[0].setHistory(servers, history, historyCallback);
      updateRunning();
    });
  }
  function forceStopActive(){
    // long_rpc_promise(packageId,"cancel_active",[]).done();
    onClose();
  }

  var autoEndTimeout = null;
  /**
   * force closed the websocket after 10 seconds of no messages
   */
  function autoEnd(category){
    if(autoEndTimeout){
      clearTimeout(autoEndTimeout);
    }
    autoEndTimeout = setTimeout(onClose.bind(this,category,"AUTO-END"),20000);
  }

  function RePing(){
    if(activeTest){
      startPings(activeTest.category);
    }
  }

  function startPings(category){
    if(!isTestRunningFrontend()){
      if(!category || !category.identifier){
        console.error("Invalid category:",category)
        return;
      }
      pingWebSocket = newWebSocket(8082, "pingheatmap");
      pingWebSocket.onopen = onOpen.bind(this,category);
      pingWebSocket.onmessage = onPing.bind(this,category);
      pingWebSocket.onclose = onClose.bind(this,category);
    }else{
      alertRunning();
    }
  }

  function onOpen(category,event){
    isNow = true;
    psvg.clearServers(true);
    nowData.length = 0;
    activeTest = {
      category: category,
      ended: false
    }
    set_history(category)
    pingWebSocket.send(category.identifier);
    pingWebSocket.send(saveManualPings);
    updateRunning();
    addCount(null,true);
  }
  function onPing(category,event){
    ///TODO find the server from gotten category instead of direct conversion
    var parsed = JSON.parse(event.data);
    var ping = Math.ceil(parsed["2"] * 1000);
    var server = {
      ip: parsed["1"],
      ping: ping,
      lat: parsed.lat,
      long: parsed.long
    }
    var response_data = {server: server, ping: server.ping};
    nowData.push(response_data);
    if(ping >= 0){
      if(isNow){
        psvg.appendServer(server);
        psvg.setD3Data();
      }
    }
    addCount(response_data);
    autoEnd(category);
    updateRunning();
  }
  function onClose(category,event){
    if(activeTest){
      activeTest.ended = true;
    }
    if(pingWebSocket){
      pingWebSocket.close();
      pingWebSocket = null;
    }
    if(autoEndTimeout){
      clearTimeout(autoEndTimeout);
      autoEndTimeout = null;
    }
    updateRunning();
    psvg.setD3Data();
  }

  function addCount(data,reset=false){
    var countNumbs = reset ? [0,0] : [
      parseInt(counts[0].textContent),
      parseInt(counts[1].textContent)
    ];
    if(data){
      if(data.ping >= 0){
        countNumbs[0]++;
      }else{
        countNumbs[1]++;
      }
    }
    counts[0].textContent = countNumbs[0];
    counts[1].textContent = countNumbs[1];
  }

  function UpdateLog(){
    if(activeTest === null || !activeTest.servers) {
      plog.update([],"NULL");
      return;
    };
    var logInfo = [];
    for(var i = 0; i < nowData.length; i ++){
      var nowd = nowData[i];
      var server = null;
      forObject(activeTest.servers, function(skey,serv){
        if(nowd.server.ip === serv.ip){
          server = serv;
        }
      });
      if(!server){
        console.error("Server not found for ip: " + nowd.server.ip, nowd,activeTest.servers);
        continue;
      }else{
        logInfo.push({
          server: server,
          ping: nowd.ping
        });
      }
    }
    plog.update(logInfo, activeTest.category);
  }
  function UpdateLogHistory(data){
    plog.updateFromHistory(data);
  }
  
  function category_key( type, verdict ){
    return "host_" + type + "_" + verdict;
  }

  function class_to_key( c ){
    var t = ( c >> geoFilter.constants.TYPE_SHIFT ) & 0x1;
    var c = ( c >> geoFilter.constants.VERDICT_SHIFT ) & 0x7;
    return category_key( t, c );
  }
  function getIconPath(file) {
    return "/apps/" + packageId + "/shared/icons/" + file;
  }
  function setTrack(category_key, val=true){
    var drop = $("#ping-targets",context);
    var dropdownItems = drop.find("paper-item");
    var cat = null;
    dropdownItems.each(function(index,element){
      if(element._category.identifier === category_key){
        element._category.track = val;
        $(element).children("iron-icon").prop("icon", val ? "schedule" : "blank");
        cat = element._category;
      }
    });
    return cat;
  }
  function toggleChangeCheck(category, cronString, oldRule){
    if(cronString === null) return;
    var after = function(){
      var cat = null;
      if(cronString !== false){
        long_rpc_promise(packageId, "add_scheduling_rule", [cronString, category]).done(function(){
          updateTimeUntil(category);
        }.bind(this));
        cat = setTrack(category);
      }else{
        cat = setTrack(category,false);
        updateTimeUntil(category);
      }
      long_rpc_promise(packageId,"update_category", [category, cat.display, cronString !== false]).done();
    }
    if(oldRule !== null){
      long_rpc_promise(packageId, "delete_scheduling_rule", [oldRule.id]).done(function(){
        after();
      })
    }else{
      after();
    }
    return
    ///TODO send rpc to update track in the CATEGORY not SCHEDULES
  }
  function setTrackCheckToTarget(targetPaperItem){
    var check = $("#set-track-button",context);
    var parent = check.parent();
    parent.children("#set-track-button").prop("disabled",null);
    check.off("tap");
    // check.attr("checked", targetPaperItem._category.hasOwnProperty("track") && targetPaperItem._category.track )
    check.on("tap", function(event){
      $("set-tracking",context)[0].open(activeTest.category.identifier,toggleChangeCheck.bind(this),true);
    });
  }
  function listboxChanged(focusedItem){
    setTrackCheckToTarget(focusedItem);
    updateTimeUntil(focusedItem._category.identifier);
    startPings(focusedItem._category ? focusedItem._category : "*");
  }
  function createServerDropdown(categories,refresh_details,forcedCloudUpdate,schedules){
    var categories = categories.length ? JSON.parse(categories[0]) : {};
    var drop = $("#ping-targets",context);
    var listbox = Polymer.dom( drop.find("paper-listbox")[0] );
    while (listbox.childNodes.length > 0) {
      listbox.removeChild(listbox.childNodes[0]);
    }
    function catSort(a,b){
      if(categories[a].custom) return -1;
      if(categories[b].custom) return 1;
      return categories[a].display < categories[b].display ? -1 : 1;
    }
    var hasNonCustom = false;
    forObject(categories,function(key,cat,i){
      cat.identifier = key;
      cat.track = false;
      if(schedules){
        forObject(schedules, function(id,schedule){
          if(schedule === null || schedule.category !== key) return;
          cat.track = true;
          return false;
        }.bind(this));
      }
      var item = $(document.createElement("paper-item"));
      var polyItem = Polymer.dom(item[0]);
      var span = $(document.createElement("span"));
      polyItem.appendChild(span[0]);
      if(cat.custom === true || cat.custom === "true"){
        var edit = $(document.createElement("paper-icon-button"));
        edit.prop("icon","image:edit");
        polyItem.appendChild(edit[0]);
      }else{
        hasNonCustom = true;
      }
      var icon = $(document.createElement("iron-icon"));
      icon.prop("icon",cat.track ? "schedule" : "blank");
      polyItem.appendChild(icon[0]);
      span.text(cat.display);
      span.css("margin-right","auto");
      item.addClass("target-dropdown-item");
      item[0]._category = cat;
      item[0]._category.index = i;
      listbox.appendChild(item[0]);
    },catSort);
    listbox.node.select(null);
    if(hasNonCustom === false){
      if(forcedCloudUpdate)
        $("duma-alert",context)[0].open("<%= i18n.downloadFailed %>")
      else
        RequestCloudUpdate();
    }
  }

  var scheduleMoment = null;
  var scheduleInterval = null;
  function updateTimeUntil(category){
    long_rpc_promise(packageId,"get_scheduling_rules",[]).done(function(result){
      var schedules = result.length ? JSON.parse(result[0]) : {}
      var done = false;
      forObject(schedules,function(id,rule){
        if(rule.category === category){
          var cron = new Cron(rule.schedule);
          done = setTimeUntil(cron.next());
        }
      });
      if(!done){
        $("#time-until-span",context).parent().hide();
      }else{
        $("#time-until-span",context).parent().show();
      }
    });
  }
  function setTimeUntil(date){
    if(date !== null){
      scheduleMoment = moment(date);
      setTimeUntilInterval(true);
      return true;
    }
    return false;
  }
  function setTimeUntilInterval(reset=false){
    if(scheduleInterval !== null){
      clearInterval(scheduleInterval);
      scheduleInterval = null;
    }
    if(reset){
      scheduleInterval = setInterval(update_time_until,timespan=1000);
      update_time_until();
    }
  }
  function update_time_until(){
    var text = "";
    var within_a_second = Math.abs( (scheduleMoment.unix() * 1000) - Date.now() ) <= 1000;
    if(within_a_second){
      text = "<%= i18n.now %>";
      if(activeTest){
        setTimeout(updateTimeUntil.bind(this,activeTest.category.identifier),5000);
        setTimeUntilInterval(false);
      }else{
        setTimeUntilInterval();
      }
    }else{
      text = scheduleMoment.fromNow();
    }
    $("#time-until-span",context).text(text);
  }

  function refresh_categories(detail,forcedCloudUpdate=false){
    Q.spread([
      long_rpc_promise(packageId,"get_categories",[]),
      long_rpc_promise(packageId,"get_scheduling_rules",[])
    ], function(categories,schedules){
      schedules = schedules[0] ? JSON.parse(schedules[0]) : {};
      createServerDropdown(categories,detail,forcedCloudUpdate,schedules);
      $("duma-panel", context).prop("loaded", true);
    }).done();
  }

  function hideMapChilds(){
    jmap.find("#radial").hide();
    jmap.find("#polygons").hide();
  }

  function OnServerClick(event){
    var panels = $("duma-panels")[0];
    if(!activeTest){
      console.error("No Active test has been run");
      return;
    }
    var testIp = event.detail.server.ip;
    var data = null;
    forObject(activeTest.servers,function(key,serv){
      if(serv.ip === testIp){
        data = {
          category: activeTest.category.identifier,
          server: serv.identifier,
          serverIP: serv.ip
        }
        return false;
      }
    });
    if(!panel.desktop && data){
      var existing = panels.list();
      if(existing[1]){
        reload_panel(existing[1].element,data,{
          _file: getFilePath("ping-graph.html"),
          _package: packageId,
          _data: data
        });
      }
      else{
        panels.add(getFilePath("ping-graph.html"), packageId, data, {
          x: 0, y: 23, width: 12, height: 16
        });
      }
    }
  }

  function clusterToggleChanged(event){
    var label = $(event.target).closest("paper-toggle-button").parent().children("p");
    if(event.detail.value){
      label.text("<%= i18n.clusterExpandMode %>");
    }else{
      label.text("<%= i18n.clusterCollapseMode %>");
    }
    psvg.closedByDefault = !event.detail.value;
    duma.storage(packageId,"ping_cluster_default",event.detail.value);
  }
  function manualToggleChanged(event){
    var label = $(event.target).closest("paper-toggle-button").parent().children("p");
    if(event.detail.value){
      label.text("<%= i18n.enabled %>");
    }else{
      label.text("<%= i18n.disabled %>");
    }
    saveManualPings = event.detail.value;
    duma.storage(packageId,"save_manual_pings",event.detail.value);
  }
  function setToggles(){
    // Cluster expaned state
    var toggleButton = $(".cluster-toggle-wrapper > paper-toggle-button",context);
    var starting = duma.storage(packageId,"ping_cluster_default");
    var startingBool = starting === "true";
    var def = toggleButton[0].checked;
    if(startingBool === def || starting === null){
      toggleButton.prop("checked",!def);
    }
    toggleButton.on("checked-changed",clusterToggleChanged.bind(this));
    toggleButton.prop("checked",starting !== null ? startingBool : def);

    // Save Manual pings
    toggleButton = $(".manual-toggle-wrapper > paper-toggle-button",context);
    starting = duma.storage(packageId,"save_manual_pings");
    startingBool = starting === "true";
    def = toggleButton[0].checked;
    if(startingBool === def || starting === null){
      toggleButton.prop("checked",!def);
    }
    toggleButton.on("checked-changed",manualToggleChanged.bind(this));
    toggleButton.prop("checked",starting !== null ? startingBool : def);
  }

  function ForceCloudUpdate(){
    panel.loaded = false;
    long_rpc_promise(packageId,"force_update_cloud",[]).done(function(){
      refresh_categories(null,true);
      panel.loaded = true;
    }.bind(this));
  }

  function RequestCloudUpdate(){
    $("duma-alert",context)[0].open("<%= i18n.noNonCustom %>",[
      { text: "<%= i18n.close %>", default: false, action: "dismiss" },
      { text: "<%= i18n.forceUpdate %>", default: true, action: "confirm", callback: function(){
        ForceCloudUpdate();
      }}
    ]);
  }

  function init(){
    hideMapChilds();
    psvg.setProjection(map);
    $("#time-until-span",context).parent().hide();
    // // add categories 
    // for( var i = 0; i < host_icons.length; i++ ){
    //   var hicons = host_icons[i];
    //   for( var j = 0; j < hicons.length; j++ ){
    //     var key = category_key( i, j );
    //     var imgpath = hicons[j];

    //     // js only has function scoping 
    //     function create_closure( path ){
    //       return function( s ){
    //         s.attr("xlink:href", getIconPath( path ));
    //         s.attr("width", 20);
    //         s.attr("height", 20);
    //       }
    //     }

    //     var extra = { "width" : 20, "height" : 20 };        
    //     map.addCategory( key, 5000, "image", create_closure( imgpath ), extra );
    //   }
    // }
    // scoreUtil.generateLegend($(".map-legend",context));

    refresh_categories();
    
    var listbox = Polymer.dom( $("#ping-targets paper-listbox", context)[0] );
    listbox.node.addEventListener("click",function(e){
      var t = $(e.target);
      var paper_icon_button = t.closest("paper-icon-button");
      var paper_item = t.closest("paper-item");
      var paper_listbox = t.closest("paper-listbox")[0];
      //open edit box
      if(paper_icon_button[0]){
        var cat = paper_item[0]._category;
        if(cat.custom === true || cat.custom === "true"){
          $("ping-custom-list",context)[0].edit(cat);
        }
        e.preventDefault();
        e.stopPropagation();
        if(activeTest !== null && activeTest.category.index >= 0)
          paper_listbox.select(activeTest.category.index);
        else
          paper_listbox.select(null);
        return;
      }
      if(isTestRunningFrontend()){
        e.preventDefault();
        e.stopPropagation();
        if(activeTest !== null && activeTest.category.index >= 0)
          paper_listbox.select(activeTest.category.index);
        alertRunning();
        return;
      }
      if(paper_item[0]){
        listboxChanged(paper_item[0]);
      }else if(activeTest !== null && activeTest.category.index >= 0){
        paper_listbox.select(activeTest.category.index);
      }else{
        paper_listbox.select(null);
      }
    });

    $("#add-custom-list",context).on("click", function(){
      $("ping-custom-list",context)[0].open();
    });
    // $("#debug-color-slider",context).on("immediate-value-changed",function(event){
    //   $(event.target).closest("paper-slider").parent().css("background-color",scoreUtil.getPingColour(event.detail.value));
    // });
    $("ping-custom-list",context).on("list-updated",function(event){
      refresh_categories(event.detail);
    });
    $("ping-servers-svg, ping-log",context).on("server-click",OnServerClick.bind(this));
    
    var pingLog = $("ping-log",context);
    pingLog.on("collapsed-changed",function(e){
      setTimeout(function(){
        psvg.resize();
      },2);
      duma.storage(packageId,"table_collapsed",e.detail.value);
    });
    var startingCollapsed = duma.storage(packageId,"table_collapsed");
    if(startingCollapsed){
      pingLog[0].collapsed = startingCollapsed === "true" || startingCollapsed === true;
    }
    if(panel.desktop){
      pingLog.attr("desktop",true);
      jsvg.attr("desktop",true);
    }
    $("duma-zoom-slider",context)[0].setMap(map);
    $("#reping-button",context).on("tap",RePing.bind(this));
    $("#force-cloud-update-button",context).on("tap",ForceCloudUpdate.bind(this));
    setToggles();
    panel.refresh_categories = refresh_categories;
  }
  init();
    
})(this);

//# sourceURL=ping-map.js
