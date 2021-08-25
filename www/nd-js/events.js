/*
 * (C) 2020 NETDUMA Software
 * Luke Meppem
*/

//Library for custom event handling
// Used for global events between windows / iframes

var duma = duma || {};
duma.events = duma.events || {
  _events:{},
  _getEvent: function(eventName){
    if(!this._events[eventName]){
      this._events[eventName] = {
        calls:[]
      };
    }
    return this._events[eventName];
  },
  // Subscribe to custom events
  on: function(eventName,callback,once){
    if(typeof eventName !== "string") throw new Error("duma events eventName must be type string");
    if(typeof callback !== "function") throw new Error("duma events callback must be type function");
    var events = this._getEvent(eventName);
    events.calls.push({func: callback, once: !!once});
  },
  // Subscribe to custom events. Will be deleted after first fire
  once: function(eventName,callback){
    this.on(eventName,callback,true);
  },
  // Call all event callbacks with data
  fire: function(eventName,data){
    if(!this._events[eventName])
      return true;
    else{
      var eventObject = {
        preventDefault: false,
        detail: data
      }
      var calls = this._events[eventName];
      //going backwards because we splice the array. Do not iterate forwards
      for(var i = calls.length - 1; i >= 0; i--){
        var call_data = calls[i];
        call_data.func.call(this,eventObject);
        if(call_data.once) calls.splice(i,1);
      }
      return eventObject;
    }
  },
  // A helpful cycle function, that takes into account the time it takes for the callback to complete
  //TODO fix setTimeout recursive stack overflow. Make it an actual proper useful scheduler
  cycle: function(callback,time){
    var func;
    time = time || 1000;
    func = function(){
      var start = Date.now();
      var repeat = function(){
        var diff = Date.now() - start;
        setTimeout(func.bind(this),Math.max(1000 - diff,0));
      }.bind(this);
      var result = callback();
      if(result && result.then){
        result.then(repeat);
      }else{
        repeat();
      }
    }
    setTimeout(func.bind(this),time);
  }
};
