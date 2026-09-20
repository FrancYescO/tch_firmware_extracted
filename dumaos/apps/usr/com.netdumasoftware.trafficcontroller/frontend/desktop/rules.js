
(function (context) {
var packageId = "com.netdumasoftware.trafficcontroller";

function getRndCharacter() {
  //Gets unicode character between 48 - 122 (0 -> lower(z))
  var code = Math.floor(Math.random() * (122 - 48 + 1) ) + 48;
  return String.fromCharCode(code);
}

var allowTypes_reject = ["Allow","Block","Reject"];
var allowTypes = ["Allow","Block"];

function format_rule(index,rule_id, enabled, name, deviceNames, targets, schedule, allow, notifications,canReject = true) {
  var row = [
    r(format_priority(index + 1,rule_id)),
    r(format_toggle(enabled,rule_id,'rule-enable',function(e){ on_enabled_change(get_button_parent(e.target)); })),
    r(name,true),
    r(format_name_list(deviceNames)),
    r(format_name_list(targets)),
    r(format_schedule(schedule).addClass('non-overflow')),
    r(format_drop_down(allow,canReject ? allowTypes_reject : allowTypes,rule_id,'rule-block')),
    r(format_check_box(notifications,rule_id,'rule-notification',function (e) { on_notifications_change(e.target); })),
    r($(document.createElement('div')).append(format_edit(rule_id)).append(format_delete(rule_id,name)))
  ];

  return row;
}
function gap(width=10,right=false){
  return $(
    '<span style="width:'
    + width + 'px;'
    + (right ? 'float:right;' : '')
    + '"></span'
  );
}
function r(content,asText=false,classes=undefined){
  if(asText){
    return $("<span></span>").text(content);
  }
  else{
    return $(content);
  }
}
function format_priority(priority,rule_id){
  var div = $("<div></div>");
  div.append(gap(5).text(priority))
    .append('<iron-icon icon="duma-icons:drag-indicator"></iron-icon>');
  return div;
}
function format_name_list(names){
  var div = $("<div class=\"overflow\"></div>");
  var inner = $("<ul></ul>");
  for(var i = 0;i < names.length;++i){
    inner.append($("<li></li>").text(names[i]));
  }
  div.html(inner);
  return div;
}
function format_check_box(bool, rule_id=undefined,id=undefined,callback){
  var div = $('<div></div>');
  div.append($(
    '<paper-checkbox '
    + (bool ? 'checked' : '')
    + (rule_id !== undefined ? ' rule=' + rule_id : '')
    + (id !== undefined ? ' id="' + id + '"': '')
    + '></paper-checkbox>'
  ).on('change',callback));
  div.addClass('drag-table-checkbox-container');
  div.addClass('row-layout');
  div.addClass('center');
  return div;
}
function format_drop_down(action, allowed_values, rule_id=undefined,id=undefined){
  var options = [];
  for(var i = 0; i < allowed_values.length; i ++){
    options.push('<paper-item value="' + allowed_values[i].toLowerCase() + '">' + allowed_values[i] + '</paper-item>');
  }
  var drop = ['<div class="row-layout top"><paper-dropdown-menu allow-outside-scroll="true" class="dropdown-small"']
  if(id !== undefined) drop.push(' id="' + id + '"');
  if(rule_id !== undefined) drop.push(' rule="' + rule_id + '"');
  drop.push('>');
  
  drop.push('<paper-listbox class="dropdown-content" attr-for-selected="value" selected="' + action.toLowerCase() + '"');
  drop.push('>');

  drop = drop.concat(options);

  drop.push('</paper-listbox></paper-dropdown-menu></div>');
  return drop.join('');
}
function format_delete(rule_id,name){
  return $(
    '<paper-icon-button icon="delete-forever" id="delete-rule" rule='+rule_id+' name=\"'+name+'\"></paper-icon-button>'
  ).click(function (e) {
    on_start_delete_rule(get_button_parent(e.target));
  });
}
function format_edit(rule_id){
  return $(
    '<paper-icon-button icon="image:edit" id="edit-rule" rule='+rule_id+'></paper-icon-button>'
  ).click(function (e) {
    on_start_edit_rule(get_button_parent(e.target));
  });
}
function format_toggle(bool,rule_id=undefined,id=undefined,callback){
  return $(
    '<paper-toggle-button '
    + (bool ? 'checked' : '')
    + (rule_id !== undefined ? ' rule=' + rule_id : '')
    + (id !== undefined ? ' id=' + id : '')
    + '></paper-toggle-button>'
    ).on('change',callback);
}
function format_schedule(schedule){
  var cron = new Cron(schedule);
  var am = format_timewheel(cron.am());
  var pm = format_timewheel(cron.pm(),true);
  var main = $('<div></div>').addClass("timewheels");
  var timewheels = $('<div></div>')
    .append(am)
    .append(gap())
    .append(pm);
  var days = $('<div></div>')
    .append(format_day('S',cron.weekdays[0]))
    .append(format_day('M',cron.weekdays[1]))
    .append(format_day('T',cron.weekdays[2]))
    .append(format_day('W',cron.weekdays[3]))
    .append(format_day('T',cron.weekdays[4]))
    .append(format_day('F',cron.weekdays[5]))
    .append(format_day('S',cron.weekdays[6]));
  main.append(timewheels);
  main.append(days);
  return main;
}
function format_day(day,is){
  return $('<span></span>').text(day).attr('active',is?true:null);
}
function format_timewheel(boolArr,pm=false){
  var timewheel = $("<duma-timewheel small " + (pm ? "pm" : "") +"></duma-timewheel>");
  timewheel.attr("starting",JSON.stringify(boolArr));
  return timewheel;
}

function on_start_delete_rule(target){
  var rule = target.getAttribute("rule");
  var name = target.getAttribute("name");
  
  function rule_delete_callback(value) {
    delete_rule(parseInt(rule));
  }
  $("duma-alert", context)[0].open("Are you sure you want to delete " + name + "?",[
    {text:"Yes",default:true,action:"confirm",callback:rule_delete_callback},
    {text:"No",default:false,action:"dismiss"}
  ],false);
}
function delete_rule(rule_id){
  //Add 1 for lua rule_id
  long_rpc_promise(packageId,"delete_rule",[rule_id]).done(function(){
    refreshRules();
  });
}


function on_start_edit_rule(target){
  var rule_id = parseInt(target.getAttribute("rule"));
  //Get rule, then open wizard with set variables

  long_rpc_promise(packageId,"get_rule",[rule_id]).done(function(rule){
    rule = rule[0];
    function rule_edit_callback(updated_rule) {
      on_end_edit_rule(updated_rule);
    }
    $("rule-add-dialog", context)[0].openEdit(rule_edit_callback,rule);
  });
  
}
function on_end_edit_rule(rule){
  //Update rule
  long_rpc_promise(packageId,"update_rule",[rule]).done(function () {
    refreshRules();
  });
}

function on_start_add_rule() {
  get_devices().done(function (d) {
    function rule_add_callback(newRule) {
      on_end_add_rule(newRule, d);
    }
    $("rule-add-dialog", context)[0].open(rule_add_callback);
  });
}
function on_end_add_rule(newRule,d){
  //End of wizard
  long_rpc_promise(packageId,"add_rule",[newRule]).done(function () {
    refreshRules();
  });
}

function on_enabled_change(target){
  var rule_id = parseInt(target.getAttribute("rule"));
  long_rpc_promise(packageId,"get_rule",[rule_id]).done(function(rule){
    rule = rule[0];
    rule.enabled = target.checked;
    long_rpc_promise(packageId,"update_rule",[rule]);
  });
}
function on_block_change(target){
  if(target.selectedItem === null) return;
  if(target.selectedItem.tagName === "PAPER-ITEM"){
    var rule_id = parseInt(target.getAttribute("rule"));
    var newType = target.selectedItem.getAttribute("value");
    long_rpc_promise(packageId,"get_rule",[rule_id]).done(function(rule){
      rule = rule[0];
      rule.allow = newType;
      long_rpc_promise(packageId,"update_rule",[rule]);
    });
  }
}
function on_notifications_change(target){
  var rule_id = parseInt(target.getAttribute("rule"));
  long_rpc_promise(packageId,"get_rule",[rule_id]).done(function(rule){
    rule = rule[0];
    rule.notifications = target.checked;
    long_rpc_promise(packageId,"update_rule",[rule]);
  });
}

function createRule(enabled, name, deviceIds, targets, intervals, action, notifications){
  return {
    enabled: enabled,
    name: name,
    device: deviceIds,
    services: targets,
    schedule: intervals,
    allow: action,
    notifications: notifications
  }
}

function JSONPromise(path){
  return new Promise(function(resolve,reject){
    $.getJSON(path,resolve);
  });
}

var devicesList = null;

function refreshRules(){
  //toggleSpinner(true);
  $("#refresh-rules", context).off('click');
  Q.spread([
    long_rpc_promise(packageId, "get_rules", []),
    JSONPromise("/json/_services_.json?cache=0"),
    JSONPromise("/json/categories.json?cache=0")
  ], function(rules,services,categories){
    rules = rules[0];
    var ids = []
    for (var i = 0; i < rules.length; i++) {
      var r = rules[i];
      for(var a =0;a<r.device.length;a++){
        if(!ids.includes(r.device[a])){
          ids.push(r.device[a]);
        }
      }
      for(var b=0;b<r.services.lenth;++b){
        if(is_all_traffic(r.services)){
          r.services = [{}];
        }
      }
    }
    load_devices(ids).then(function(devices) {
      var rows = [];
      for (var i = 0; i < rules.length; i++) {
        var r = rules[i];
        var devs = filter_devices(devices,r.device);
        var servs = format_services(services,r.services);
        var targets = servs.targets;
        targets = targets.concat(format_categories(categories,r.categories));
        rows.push({
          id: r.id,
          data: format_rule(i,r.id,r.enabled,r.name,devs,targets,r.schedule,r.allow,r.notifications,servs.reject)
        });
      }
      $("#firewall-rules", context)[0].setRows(rows,on_refresh.bind(this));
      $("#refresh-rules", context).click(function () {
        refreshRules();
      });
      refresh_main_disabled();
    });

    $("duma-panel", context).prop("loaded", true);
  });
}
/*
function toggleSpinner(boolVar=undefined){
  spinner = $("#rules-switch-spinner");
  if(boolVar === undefined){
    boolVar = !spinner[0].opened;
  }
  if(boolVar){
    spinner[0].open();
    spinner.find("paper-spinner-lite").prop("active", true);
  }else{
    spinner[0].close();
    spinner.find("paper-spinner-lite").prop("active", false);
  }
}
*/
function on_refresh(event){
  /*
  I REALLY DONT WANT TO USE TIMEOUT HERE
  but there are no events to attach refresh to
  and set_disabled() needs to happen after the polymer reconstructs the drag table,
  which this function is called before that happens
  */
  setTimeout(finish_refresh,50);
}
function finish_refresh(){
  set_disabled();
  //If after rules, called at creation. Needs delay before adding listeners
  $("[id=rule-block]", context).on('selected-item-changed',function (e) {
    on_block_change(e.target);
  }.bind(this));
  //toggleSpinner(false);
}

function switchRules(rule_id,to){
  rule_id = parseInt(rule_id);
  to = parseInt(to);
  let drag_rows = $("#firewall-rules #drag_container > tr.drag-table:not(.gu-mirror) > td:first-child span");
  drag_rows.each(function(index,element){
    element.textContent = index + 1;
  });
  long_rpc_promise(packageId,"reorder_rule",[rule_id,to]).done(function(){
    refreshRules();
  });
}

function disable_all(target){
  var boolVal = target.checked;
  long_rpc_promise(packageId,"disable_rules",[boolVal]).done(function(){
    set_disabled(boolVal);
  });
}
function set_disabled(boolVal=undefined,main=false){
  disabled = $("#disable-all-rules");
  if(boolVal === undefined){
    boolVal = disabled.attr('checked') == 'checked';
  }
  if(main){
    disabled.attr('checked',boolVal ? true : null);
  }
  $("[id=rule-enable]").each(function(){
    $(this).attr('disabled',boolVal ? true : null);
  });
}

function get_button_parent(element){
  var ret = null;
  var buttons = ["paper-button","paper-icon-button","paper-toggle-button"];
  for(var i = 0; i < buttons.length; i ++ ){
    ret = $(element).closest(buttons[i],context);
    if(ret.prop("tagName") === buttons[i].toUpperCase()) { return ret[0]; }
  }
  return null;
}

function filter_devices(deviceList,idList){
  if(idList.length == 0) { return ["All Devices"]; }
  var ret = [];
  for(var i =0;i<deviceList.length;i++){
    var d = deviceList[i][0];
    if(idList.includes(d.devid)){
      str = d.uhost;
      if(!str || str.length === 0){
        str = d.interfaces[0].dhost;
        if(!str || str.length === 0){
          str = d.interfaces[0].ghost;
        }
      }
      ret.push(str);
    }
  }
  return ret;
}

function is_all_traffic(serviceList) {
  return serviceList.length === 1 && Object.keys(serviceList[0]).length === 0;
}

function format_categories(categories,categoryList){
  var ret = [];
  var keys = Object.keys(categories);
  for(var c = 0; c < categoryList.length; c++){
    for(var i = 0; i < keys.length; i++){
      var key = keys[i];
      var id = categories[key];
      if(categoryList[c] === id){
        ret.push(key);
        break;
      }
    }
  }
  return ret;
}

function format_services(_services,serviceList){
  if (is_all_traffic(serviceList)) { return {targets: ["All Traffic"], reject: true}; }

  var ret = [];
  var reject = false;
  for(var i = 0;i<serviceList.length;++i){
    var s = serviceList[i];
    var proto = s.hasOwnProperty('proto') ? (s.proto == 6 ? "TCP" : "UDP") : "Port";
    if(s.proto === 6) reject = true;
    var sport = s.hasOwnProperty('sport');
    var dport = s.hasOwnProperty('dport');
    if(s.hasOwnProperty('appid') || (sport && dport)){
      var s_name = get_service(_services,JSON.stringify(s));
      if(s_name != null && !ret.includes(s_name)){
        ret.push(s_name);
      }
    }else{
      if(sport){
        ret.push("Source " + proto + " " + s.sport[0] + "-" + s.sport[1]);
      }else if(dport){
        ret.push("Destination " + proto + " " + s.dport[0] + "-" + s.dport[1]);
      }else{
        ret.push("Unknown Service")
      }
    }
  }
  return {targets: ret, reject: reject};
}
function get_service(_services,compare){
  for(var i =0;i<_services.length;i++){
    var s = _services[i];
    if(s.hasOwnProperty('services')){
      for(var a=0;a<s.services.length;a++){
        var s_service = s.services[a];
        if(JSON.stringify(s_service) == compare){
          return s.application;
        }
      }
    }
  }
  return null;
}

function load_devices(id_list) {
  var promises = [];

  for (var i = 0; i < id_list.length; ++i) {
    promises.push(long_rpc_promise(
      "com.netdumasoftware.devicemanager",
      "get_device",
      [id_list[i]]
    ));
  }
  return Q.all(promises);
}

function refresh_main_disabled(){
  long_rpc_promise(packageId,"disable_rules",[]).done(function(value){
    set_disabled(value[0],true);
  });
}

function init(){
  $("#firewall-rules", context)[0].setSwitchCallback(switchRules);
  refresh_main_disabled();
  $("#disable-all-rules", context).click(function (e) {
    disable_all(get_button_parent(e.target));
  });
  $("#add-rule", context).click(function () {
    on_start_add_rule();
  });
  $("#add-preset", context).click(function () {
    //tier_box_open();
  });
  refreshRules();
}

init();

var last_refresh = -1;
start_cycle(function () {
  return [long_rpc_promise(packageId, "get_refresh", [])];
}, function (latest) {
  if(latest[0] !== last_refresh){
    last_refresh = latest[0];
    refreshRules();
  }
}, 1000);

})(this);
