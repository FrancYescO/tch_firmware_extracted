
(function (context) {
var packageId = "com.netdumasoftware.trafficcontroller";

var rulesTable = $("rules-table",context)[0];

function on_start_add_rule() {
  duma.devices.get_devices().done(function (d) {
    $("rule-add-dialog", context)[0].open((newRule) => {
      on_end_add_rule(newRule,d);
    });
  });
}
function on_end_add_rule(newRule,d){
  //End of wizard
  // wait for response so we can get the id
  // we could push the rule to the table here, then subtly update the id of the rule afterwards
  // however, that provides a brief period where doing anything has funky behaviour (such as clicking delete will attempt to delete the rule with `null` id)
  // so it's better to just wait for the id to exist
  long_rpc_promise(packageId,"add_rule",[newRule]).then((id) => {
    newRule.id = id[0];
    rulesTable.push('rules',newRule);
  });
}

function disable_all_rpc(state){
  long_rpc_promise(packageId,"disable_rules",[state]);
}

function refresh_main_disabled(){
  $("#disable-all-rules", context).off('checked-changed');
  long_rpc_promise(packageId,"disable_rules",[]).done(function(value){
    var initState = value[0];
    rulesTable.allDisabled = initState;
    $("#disable-all-rules", context).attr("checked",initState).on('checked-changed',function (e) {
      var newState = e.detail.value;
      rulesTable.allDisabled = newState;
      disable_all_rpc(newState);
    });
  });
}

function init(){
  refresh_main_disabled();
  $("#add-rule", context).on("tap",function () {
    on_start_add_rule();
  });
}

init();


// this code is to refresh the rules table automatically when something changes. However, due to recent changes, this actually breaks some stuff.
// It was fine when traffic controller was slower, but now that the loading time's improved and stuff, it breaks it (such as rules appearing just after deleting them)
// Code left here commented out so future devs aware of the functionality of the "get_refesh", but for now, it's unneeded
// var last_refresh = -1;
// start_cycle(function () {
//   return [long_rpc_promise(packageId, "get_refresh", [])];
// }, function (latest) {
//   if(latest[0] !== last_refresh){
//     last_refresh = latest[0];
//     rulesTable.refresh();
//   }
// }, 1000);

})(this);
