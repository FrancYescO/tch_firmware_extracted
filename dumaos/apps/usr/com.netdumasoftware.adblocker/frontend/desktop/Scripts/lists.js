(function (context)
{
  var flushCloudButton = $("#flush-cloud",context);
  flushCloudButton.on("click",function(){
    flushCloudButton.prop("disabled",true);
    long_rpc_promise("com.netdumasoftware.adblocker","flush_cloud",[]).done(function(){
      flushCloudButton.prop("disabled",false);
    });
  });
})(this);
